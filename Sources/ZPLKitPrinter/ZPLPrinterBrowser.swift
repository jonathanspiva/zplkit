import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Discovers Zebra printers on the local network using Zebra's proprietary
/// UDP discovery protocol (the same mechanism Zebra's Link-OS `NetworkDiscoverer`
/// uses), **not** Bonjour/mDNS.
///
/// Zebra network print servers do not advertise themselves over Bonjour by
/// default — browsing `_pdl-datastream._tcp` finds generic IPP/socket printers
/// (e.g. an office inkjet) but not Zebra units. Instead, a client broadcasts a
/// small request to UDP port 4201 and each Zebra printer replies (unicast) with
/// its identity: system name, product number, firmware, and network config.
///
/// ## Protocol
///
/// - Request: broadcast `2E 2C 3A 01 00 00` (`,.:` + flags) to `255.255.255.255:4201`.
/// - Reply: unicast packet beginning `3A 2C 2E` (`:,.`) containing the print
///   server name, product number, firmware version, IP/netmask/gateway, and the
///   configured system (friendly) name.
///
/// ## Usage
///
/// ```swift
/// let browser = ZPLPrinterBrowser()
/// for await printer in browser.printers {
///     print("Found: \(printer.name) at \(printer.host)")
/// }
/// ```
///
/// The browser starts automatically when you access `printers` or call `start()`,
/// re-broadcasting periodically so printers that power on later are found. Call
/// `stop()` when done to release the socket and finish the streams.
///
/// - Note: On iOS (and macOS apps under the App Sandbox), UDP broadcast triggers
///   the local-network privacy permission — the app needs the entitlement and
///   the user's approval, or no replies are received.
public final class ZPLPrinterBrowser: @unchecked Sendable {
    /// Zebra's proprietary discovery UDP port.
    public static let discoveryPort: UInt16 = 4201

    /// Discovery request payload (`,.:` + version/flags).
    private static let probe: [UInt8] = [0x2E, 0x2C, 0x3A, 0x01, 0x00, 0x00]
    /// Reply packets begin with `:,.`.
    private static let replyMagic: [UInt8] = [0x3A, 0x2C, 0x2E]

    private let lock = NSLock()
    private var discovered: [String: DiscoveredPrinter] = [:]   // keyed by host IP
    private var continuations: [UUID: AsyncStream<DiscoveredPrinter>.Continuation] = [:]
    private var isRunning = false
    private var thread: Thread?
    private var sock: Int32 = -1

    /// Creates a new printer browser.
    public init() {}

    deinit { stop() }

    /// The printers discovered so far.
    public var discoveredPrinters: [DiscoveredPrinter] {
        lock.lock(); defer { lock.unlock() }
        return Array(discovered.values)
    }

    /// An async sequence of discovered printers. Each printer is emitted as it's
    /// first discovered; the sequence continues until the browser is stopped.
    public var printers: AsyncStream<DiscoveredPrinter> {
        start()
        return AsyncStream { continuation in
            let id = UUID()

            lock.lock()
            // stop() may have run between start() above and this registration;
            // registering on a stopped browser would strand the iterator on a
            // stream that never yields and never finishes.
            let active = isRunning
            if active {
                continuations[id] = continuation
                for printer in discovered.values { continuation.yield(printer) }
            }
            lock.unlock()

            if active {
                continuation.onTermination = { [weak self] _ in
                    self?.lock.lock()
                    self?.continuations.removeValue(forKey: id)
                    self?.lock.unlock()
                }
            } else {
                continuation.finish()
            }
        }
    }

    /// Starts broadcasting for printers. Called automatically by `printers`.
    public func start() {
        lock.lock()
        guard !isRunning else { lock.unlock(); return }
        isRunning = true
        lock.unlock()

        let t = Thread { [weak self] in self?.discoveryLoop() }
        t.name = "ZPLPrinterBrowser.udp4201"
        t.stackSize = 512 * 1024
        lock.lock(); thread = t; lock.unlock()
        t.start()
    }

    /// Stops broadcasting and releases resources. Safe to call multiple times.
    public func stop() {
        lock.lock()
        guard isRunning else { lock.unlock(); return }
        isRunning = false
        let s = sock
        sock = -1
        let toFinish = Array(continuations.values)
        continuations.removeAll()
        discovered.removeAll()
        lock.unlock()

        // Closing the socket unblocks the discovery thread's recvfrom.
        if s >= 0 { Darwin.close(s) }

        // finish() synchronously invokes each stream's onTermination handler,
        // which re-acquires `lock`; call it *outside* the lock to avoid a
        // re-entrant deadlock.
        for continuation in toFinish { continuation.finish() }
    }

    // MARK: - Discovery thread

    private func discoveryLoop() {
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return }

        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &on, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size))
        // Wake up periodically so the loop can re-broadcast and observe stop().
        var tv = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        // Bind an ephemeral port; replies arrive unicast to this socket.
        var bindAddr = sockaddr_in()
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = 0
        bindAddr.sin_addr.s_addr = in_addr_t(0)  // INADDR_ANY
        let bindResult = withUnsafePointer(to: &bindAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { Darwin.close(fd); return }

        lock.lock()
        guard isRunning else { lock.unlock(); Darwin.close(fd); return }
        sock = fd
        lock.unlock()

        var buffer = [UInt8](repeating: 0, count: 4096)
        var lastBroadcast = Date.distantPast

        while true {
            lock.lock(); let running = isRunning; lock.unlock()
            if !running { break }

            if Date().timeIntervalSince(lastBroadcast) > 3 {
                broadcastProbe(fd)
                lastBroadcast = Date()
            }

            var from = sockaddr_in()
            var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let n = withUnsafeMutablePointer(to: &from) { fromPtr in
                fromPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    buffer.withUnsafeMutableBytes { raw in
                        recvfrom(fd, raw.baseAddress, raw.count, 0, sa, &fromLen)
                    }
                }
            }

            if n > 0 {
                let data = Array(buffer[0..<n])
                let host = Self.ipString(from.sin_addr)
                if let printer = Self.parseReply(data, host: host) {
                    addPrinter(printer)
                }
            } else if n < 0 {
                // EAGAIN/EWOULDBLOCK: the recv timeout expired — loop and
                // re-broadcast. EBADF: stop() closed the socket — exit.
                if errno == EBADF { break }
            }
        }

        lock.lock(); let s = sock; sock = -1; lock.unlock()
        if s >= 0 { Darwin.close(s) }
    }

    private func broadcastProbe(_ fd: Int32) {
        var dest = sockaddr_in()
        dest.sin_family = sa_family_t(AF_INET)
        dest.sin_port = UInt16(Self.discoveryPort).bigEndian
        dest.sin_addr.s_addr = in_addr_t(0xFFFF_FFFF)  // 255.255.255.255
        Self.probe.withUnsafeBytes { raw in
            _ = withUnsafePointer(to: &dest) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, raw.baseAddress, raw.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    private func addPrinter(_ printer: DiscoveredPrinter) {
        lock.lock()
        let isNew = discovered[printer.host] == nil
        discovered[printer.host] = printer
        let toYield = isNew ? Array(continuations.values) : []
        lock.unlock()
        for continuation in toYield { continuation.yield(printer) }
    }

    private static func ipString(_ addr: in_addr) -> String {
        var a = addr
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard let result = inet_ntop(AF_INET, &a, &buf, socklen_t(INET_ADDRSTRLEN)) else {
            return ""
        }
        return String(cString: result)  // pointer overload (the [CChar] overload is deprecated)
    }

    // MARK: - Reply parsing

    /// Parses a Zebra UDP/4201 discovery reply into a `DiscoveredPrinter`.
    /// Returns `nil` if the packet isn't a recognizable Zebra reply.
    ///
    /// Layout (observed on ZebraNet wired print servers, FW V53/V56):
    /// `3A 2C 2E` magic; product number at offset 4; print-server name at 12;
    /// firmware `V##.##.##<letter>` near offset 39; IP at 72; and the configured
    /// system (friendly) name, null-terminated, at offset 84.
    static func parseReply(_ data: [UInt8], host: String) -> DiscoveredPrinter? {
        guard data.count >= 88, Array(data[0..<3]) == replyMagic else { return nil }

        func cString(at offset: Int, max: Int) -> String {
            guard offset < data.count else { return "" }
            let end = min(offset + max, data.count)
            var bytes: [UInt8] = []
            for i in offset..<end {
                let b = data[i]
                if b == 0 { break }
                bytes.append(b)
            }
            return String(decoding: bytes, as: UTF8.self)
        }

        let product = cString(at: 4, max: 16)          // e.g. "79071"
        let serverName = cString(at: 12, max: 24)       // e.g. "ZebraNet Wired PS"
        let systemName = cString(at: 84, max: 48)       // e.g. "ZPLKit-Test"
        let firmware = extractFirmware(data)

        let name = !systemName.isEmpty ? systemName
            : (!serverName.isEmpty ? serverName : "Zebra printer")

        var metadata: [String: String] = [:]
        if !firmware.isEmpty { metadata["firmware"] = firmware }
        if !product.isEmpty { metadata["product"] = product }
        if !serverName.isEmpty { metadata["server"] = serverName }

        // Key by host so repeated broadcasts update (rather than duplicate) the
        // same printer. Port 9100 is the raw-printing port send()/query() use.
        return DiscoveredPrinter(id: host, name: name, host: host,
                                 port: ZPLPrinter.defaultPort, metadata: metadata)
    }

    /// Extracts a Zebra firmware token (`V##.##.##<letter>`) from the header
    /// region of a reply. Bounded to the first 80 bytes to avoid the binary
    /// tail of the packet.
    private static func extractFirmware(_ data: [UInt8]) -> String {
        let limit = min(80, data.count)
        let chars = (0..<limit).map { i -> Character in
            let b = data[i]
            return (32 <= b && b < 127) ? Character(UnicodeScalar(b)) : " "
        }
        var i = 0
        while i < chars.count {
            if chars[i] == "V", i + 1 < chars.count, chars[i + 1].isNumber {
                var j = i + 1
                while j < chars.count, chars[j].isNumber || chars[j] == "." { j += 1 }
                var token = String(chars[i..<j])
                // Single trailing version letter (e.g. the "Z" in "V56.17.17Z").
                if j < chars.count, chars[j].isLetter, chars[j].isUppercase {
                    token.append(chars[j])
                }
                if token.filter({ $0 == "." }).count >= 2 { return token }
            }
            i += 1
        }
        return ""
    }
}
