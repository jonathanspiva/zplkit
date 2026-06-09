import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// A loopback TCP "fake printer" used by the network round-trip tests.
///
/// It binds a plain POSIX/Darwin socket on `127.0.0.1` port 0 (ephemeral),
/// reads back the assigned port via `getsockname`, and serves connections on a
/// background thread. Using a raw POSIX listener (rather than `NWListener`)
/// gives the tests precise, deterministic control over accept / recv / send so
/// they can exercise the client's send loop, multi-frame receive logic,
/// timeouts, and error paths.
///
/// The server talks plain TCP, so it works with both halves of `ZPLPrinter`:
/// `send()` (POSIX sockets) and `query()` (NWConnection). `query()` opens a
/// fresh connection per call, so the per-connection scripting (`Behavior`)
/// applies to each accepted connection independently.
///
/// All shared state is guarded by an `NSLock`, so the type is `Sendable`.
final class FakePrinter: @unchecked Sendable {

    // MARK: - ASCII control bytes (ZPL response framing)

    static let stx: UInt8 = 0x02
    static let etx: UInt8 = 0x03
    static let cr: UInt8 = 0x0D
    static let lf: UInt8 = 0x0A

    // MARK: - Per-connection behavior

    /// How the server responds to one accepted connection.
    enum Behavior: Sendable {
        /// Read the request, send these response chunks (each in its own
        /// `write()` with a small gap so they tend to land in separate TCP
        /// segments), then close the connection.
        case respond(chunks: [Data], gap: TimeInterval)

        /// Accept the connection, read the request, but send nothing and hold
        /// the connection open until `shutdown()`. Exercises timeouts.
        case silent

        /// Accept and immediately close the connection without reading or
        /// replying. Exercises receive/send error and EOF handling.
        case closeImmediately

        /// Accept, drain the request fully, then close gracefully without a
        /// reply. Exercises a graceful close after a `send()`.
        case drainThenClose
    }

    // MARK: - State (lock-guarded)

    private let lock = NSLock()
    private var listenFD: Int32 = -1
    private var clientFDs: [Int32] = []
    private var _port: UInt16 = 0
    private var _received = Data()
    private var _connectionCount = 0
    private var behaviors: [Behavior]
    private var defaultBehavior: Behavior
    private var stopped = false
    private var serveThread: Thread?

    // MARK: - Init / port

    /// Creates and starts a fake printer.
    ///
    /// - Parameters:
    ///   - behaviors: A queue of behaviors applied to successive connections,
    ///     in order. Once exhausted, `defaultBehavior` is used.
    ///   - defaultBehavior: Behavior for connections beyond `behaviors`.
    init(behaviors: [Behavior] = [], defaultBehavior: Behavior = .drainThenClose) throws {
        self.behaviors = behaviors
        self.defaultBehavior = defaultBehavior
        try start()
    }

    /// The ephemeral port the listener bound to.
    var port: UInt16 {
        lock.lock(); defer { lock.unlock() }
        return _port
    }

    /// All bytes received across every connection so far.
    var received: Data {
        lock.lock(); defer { lock.unlock() }
        return _received
    }

    /// The received bytes decoded as UTF-8 (best effort).
    var receivedString: String {
        String(decoding: received, as: UTF8.self)
    }

    /// Number of connections accepted so far.
    var connectionCount: Int {
        lock.lock(); defer { lock.unlock() }
        return _connectionCount
    }

    // MARK: - Lifecycle

    private func start() throws {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else {
            throw FakePrinterError.setupFailed("socket() failed: \(errno)")
        }

        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0  // ephemeral
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(fd)
            throw FakePrinterError.setupFailed("bind() failed: \(errno)")
        }

        guard listen(fd, 16) == 0 else {
            Darwin.close(fd)
            throw FakePrinterError.setupFailed("listen() failed: \(errno)")
        }

        // Read back the assigned port.
        var boundAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                getsockname(fd, sa, &len)
            }
        }
        guard nameResult == 0 else {
            Darwin.close(fd)
            throw FakePrinterError.setupFailed("getsockname() failed: \(errno)")
        }

        lock.lock()
        listenFD = fd
        _port = UInt16(bigEndian: boundAddr.sin_port)
        lock.unlock()

        let thread = Thread { [weak self] in
            self?.serveLoop(listenFD: fd)
        }
        thread.name = "FakePrinter.serve"
        thread.stackSize = 512 * 1024
        lock.lock()
        serveThread = thread
        lock.unlock()
        thread.start()
    }

    /// Closes the listener and all client sockets, and joins the serving
    /// thread. Safe to call multiple times. Tests must call this (via `defer`)
    /// so ports / fds don't leak between tests.
    func shutdown() {
        lock.lock()
        if stopped {
            lock.unlock()
            return
        }
        stopped = true
        let listen = listenFD
        listenFD = -1
        let clients = clientFDs
        clientFDs = []
        let thread = serveThread
        lock.unlock()

        // Closing the listen fd makes the blocking accept() return with an
        // error, unblocking the serve loop.
        if listen >= 0 { Darwin.close(listen) }
        for c in clients where c >= 0 { Darwin.close(c) }

        // Join the serve thread so no background work outlives the test.
        if let thread {
            while !thread.isFinished {
                usleep(2000)
            }
        }
    }

    deinit {
        shutdown()
    }

    // MARK: - Serve loop

    private func serveLoop(listenFD: Int32) {
        while true {
            lock.lock()
            let isStopped = stopped
            lock.unlock()
            if isStopped { return }

            var clientAddr = sockaddr()
            var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
            let clientFD = accept(listenFD, &clientAddr, &addrLen)

            if clientFD < 0 {
                // accept() failed, almost certainly because the listener was
                // closed by shutdown(). Exit the loop.
                return
            }

            // Pick the behavior for this connection.
            lock.lock()
            if stopped {
                lock.unlock()
                Darwin.close(clientFD)
                return
            }
            let behavior: Behavior
            if !behaviors.isEmpty {
                behavior = behaviors.removeFirst()
            } else {
                behavior = defaultBehavior
            }
            _connectionCount += 1
            clientFDs.append(clientFD)
            lock.unlock()

            handle(clientFD: clientFD, behavior: behavior)
        }
    }

    private func handle(clientFD: Int32, behavior: Behavior) {
        switch behavior {
        case .closeImmediately:
            closeClient(clientFD)

        case .silent:
            // Read whatever the client sends (so the request is recorded), but
            // never reply. Leave the connection open; shutdown() closes it.
            _ = readRequest(clientFD, drain: false)

        case .drainThenClose:
            _ = readRequest(clientFD, drain: true)
            closeClient(clientFD)

        case .respond(let chunks, let gap):
            _ = readRequest(clientFD, drain: false)
            for chunk in chunks {
                writeAll(clientFD, chunk)
                if gap > 0 {
                    usleep(useconds_t(gap * 1_000_000))
                }
            }
            closeClient(clientFD)
        }
    }

    /// Reads available request bytes into `_received`.
    ///
    /// - Parameter drain: When true, keep reading until the peer half-closes
    ///   (EOF). `send()` performs a clean shutdown after writing, so draining
    ///   captures the full payload. When false, do a single bounded read so the
    ///   server can move on to writing a reply (query() keeps its socket open).
    @discardableResult
    private func readRequest(_ fd: Int32, drain: Bool) -> Int {
        var total = 0
        var buffer = [UInt8](repeating: 0, count: 8192)
        while true {
            lock.lock()
            let isStopped = stopped
            lock.unlock()
            if isStopped { break }

            let n = buffer.withUnsafeMutableBytes { raw -> Int in
                Darwin.read(fd, raw.baseAddress, raw.count)
            }
            if n > 0 {
                total += n
                let slice = Data(buffer[0..<n])
                lock.lock()
                _received.append(slice)
                lock.unlock()
                if !drain {
                    // One bounded read is enough to capture a query command.
                    break
                }
                continue
            }
            // n == 0 -> EOF (peer closed). n < 0 -> error.
            break
        }
        return total
    }

    private func writeAll(_ fd: Int32, _ data: Data) {
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            var sent = 0
            let count = raw.count
            while sent < count {
                let n = Darwin.write(fd, base + sent, count - sent)
                if n <= 0 {
                    if n < 0 && errno == EINTR { continue }
                    break
                }
                sent += n
            }
        }
    }

    private func closeClient(_ fd: Int32) {
        lock.lock()
        if let idx = clientFDs.firstIndex(of: fd) {
            clientFDs.remove(at: idx)
        }
        lock.unlock()
        Darwin.close(fd)
    }

    // MARK: - Response builders (valid ZPL framing)

    /// Wraps content in a single `<STX>content<ETX><CR><LF>` frame.
    static func frame(_ content: String) -> Data {
        var data = Data([stx])
        data.append(contentsOf: Array(content.utf8))
        data.append(contentsOf: [etx, cr, lf])
        return data
    }

    /// Builds a valid three-frame `~HS` (Host Status) response.
    ///
    /// `~HS` returns three `<STX>...<ETX><CR><LF>` frames. The parser reads:
    /// - string 1 fields: `comm,paperOut,pause,labelLen,formats,bufferFull,commDiag,partial,unused,corruptRAM,tempRange,unused`
    /// - string 2 fields: `funcSettings,headUp,ribbonOut,thermalTransfer,printMode,printWidth,labelWaiting,labelsRemaining`
    /// - string 3: two values (unused by parser).
    ///
    /// Defaults describe a healthy, ready printer.
    static func makeHSResponse(
        paperOut: Bool = false,
        paused: Bool = false,
        labelLength: Int = 1218,
        formatsInBuffer: Int = 0,
        bufferFull: Bool = false,
        partialFormat: Bool = false,
        tempRange: Int = 0,
        headUp: Bool = false,
        ribbonOut: Bool = false,
        thermalTransfer: Bool = true,
        labelsRemaining: Int = 0
    ) -> [Data] {
        func b(_ v: Bool) -> String { v ? "1" : "0" }
        // string 1: 12 fields
        let s1 = [
            "030",                      // 0 comm settings
            b(paperOut),                // 1 paper out
            b(paused),                  // 2 pause
            String(format: "%04d", labelLength), // 3 label length
            String(format: "%03d", formatsInBuffer), // 4 formats in buffer
            b(bufferFull),              // 5 buffer full
            "0",                        // 6 comm diagnostic
            b(partialFormat),           // 7 partial format
            "000",                      // 8 unused
            "0",                        // 9 corrupt RAM
            String(tempRange),          // 10 temperature range
            "0"                         // 11 unused
        ].joined(separator: ",")
        // string 2: 8 fields
        let s2 = [
            "0",                        // 0 function settings
            b(headUp),                  // 1 head up
            b(ribbonOut),               // 2 ribbon out
            b(thermalTransfer),         // 3 thermal transfer mode
            "1",                        // 4 print mode
            "832",                      // 5 print width
            "0",                        // 6 label waiting
            String(labelsRemaining)     // 7 labels remaining
        ].joined(separator: ",")
        // string 3: 2 fields (password, static RAM)
        let s3 = "0000,0"
        return [frame(s1), frame(s2), frame(s3)]
    }

    /// Builds a valid single-frame `~HI` (Host Identification) response.
    ///
    /// Layout: `<STX>MODEL,FIRMWARE,DPM,MEMORYKB,OPTIONS<ETX><CR><LF>`.
    static func makeHIResponse(
        model: String = "ZM400-200dpi",
        firmware: String = "V53.17.14Z",
        dotsPerMillimeter: Int = 8,
        memoryKB: Int = 49152,
        options: String = "NONE"
    ) -> Data {
        let content = "\(model),\(firmware),\(dotsPerMillimeter),\(memoryKB)KB,\(options)"
        return frame(content)
    }

    /// Builds a valid single-frame `~HM` (Host RAM Status) response.
    ///
    /// Layout: `<STX>TOTAL,MAXIMUM,AVAILABLE<ETX><CR><LF>` (kilobytes/bytes;
    /// the parser only requires available <= total).
    static func makeHMResponse(
        total: Int = 2097152,
        maximum: Int = 2097152,
        available: Int = 1847296
    ) -> Data {
        return frame("\(total),\(maximum),\(available)")
    }

    /// Builds a `^HH` (configuration readback) plaintext response.
    ///
    /// `^HH` is a multi-line two-column text dump (value on the left, field
    /// name on the right). It is NOT STX/ETX framed by all printers, but real
    /// Zebra units wrap the dump in STX ... ETX CR LF; the parser tolerates
    /// both. We include the framing plus a trailing LF so query()'s completion
    /// check (`buffer.last == 0x0A` && >=1 ETX frame) fires promptly.
    static func makeHHResponse(
        darkness: Int = 15,
        printSpeed: Int = 4,
        serial: String = "31J114702349",
        firmware: String = "V53.17.14Z",
        printWidth: Int = 832,
        labelLength: Int = 1218
    ) -> Data {
        let lines = [
            "PRINTER CONFIGURATION",
            "+\(darkness)                 DARKNESS",
            "\(printSpeed) IPS               PRINT SPEED",
            "+000                TEAR OFF",
            "TEAR OFF            PRINT MODE",
            "GAP/NOTCH           MEDIA TYPE",
            "THERMAL-TRANS.      PRINT METHOD",
            "\(printWidth)                 PRINT WIDTH",
            "\(labelLength)                LABEL LENGTH",
            "39.0IN   988MM      MAXIMUM LENGTH",
            "\(serial)        SERIAL NUMBER",
            "\(firmware) <-       FIRMWARE",
            "111,367 IN          NONRESET CNTR",
            "1,234 IN            RESET CNTR1"
        ]
        let body = lines.joined(separator: "\r\n") + "\r\n"
        var data = Data([stx])
        data.append(contentsOf: Array(body.utf8))
        data.append(contentsOf: [etx, cr, lf])
        return data
    }
}

enum FakePrinterError: Error {
    case setupFailed(String)
}

/// A loopback fake printer that routes its reply based on the request bytes.
///
/// `query()` opens a fresh connection per command and `queryDiagnostics()` runs
/// `~HI`, `~HS`, and `~HM` concurrently (each on its own connection), so those
/// connections race and a fixed behavior queue can't match request to response.
/// This server reads the request, inspects it for the command marker, and
/// replies with the matching framed response.
///
/// It reuses `FakePrinter`'s POSIX listener via composition; the routing logic
/// lives in a custom accept loop here.
final class FakePrinterRouting: @unchecked Sendable {

    private let lock = NSLock()
    private var listenFD: Int32 = -1
    private var clientFDs: [Int32] = []
    private var _port: UInt16 = 0
    private var stopped = false
    private var serveThread: Thread?
    private let answerHH: Bool

    init(answerHH: Bool = true) throws {
        self.answerHH = answerHH
        try start()
    }

    var port: UInt16 {
        lock.lock(); defer { lock.unlock() }
        return _port
    }

    private func start() throws {
        let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard fd >= 0 else { throw FakePrinterError.setupFailed("socket(): \(errno)") }
        var on: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(fd, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else { Darwin.close(fd); throw FakePrinterError.setupFailed("bind(): \(errno)") }
        guard listen(fd, 16) == 0 else { Darwin.close(fd); throw FakePrinterError.setupFailed("listen(): \(errno)") }

        var boundAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &boundAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                getsockname(fd, sa, &len)
            }
        }

        lock.lock()
        listenFD = fd
        _port = UInt16(bigEndian: boundAddr.sin_port)
        lock.unlock()

        let thread = Thread { [weak self] in self?.serveLoop(fd) }
        thread.name = "FakePrinterRouting.serve"
        thread.stackSize = 512 * 1024
        lock.lock(); serveThread = thread; lock.unlock()
        thread.start()
    }

    func shutdown() {
        lock.lock()
        if stopped { lock.unlock(); return }
        stopped = true
        let listen = listenFD; listenFD = -1
        let clients = clientFDs; clientFDs = []
        let thread = serveThread
        lock.unlock()
        if listen >= 0 { Darwin.close(listen) }
        for c in clients where c >= 0 { Darwin.close(c) }
        if let thread { while !thread.isFinished { usleep(2000) } }
    }

    deinit { shutdown() }

    private func serveLoop(_ listenFD: Int32) {
        while true {
            lock.lock(); let s = stopped; lock.unlock()
            if s { return }

            var clientAddr = sockaddr()
            var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
            let clientFD = accept(listenFD, &clientAddr, &addrLen)
            if clientFD < 0 { return }

            lock.lock()
            if stopped { lock.unlock(); Darwin.close(clientFD); return }
            clientFDs.append(clientFD)
            lock.unlock()

            // Each connection is short-lived; handle inline so concurrent
            // queries each get their own accepted fd.
            handle(clientFD)
        }
    }

    private func handle(_ fd: Int32) {
        // Read the request command.
        var request = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        let n = buffer.withUnsafeMutableBytes { raw in
            Darwin.read(fd, raw.baseAddress, raw.count)
        }
        if n > 0 { request = Data(buffer[0..<n]) }
        let req = String(decoding: request, as: UTF8.self).uppercased()

        let response: Data?
        if req.contains("~HI") {
            response = FakePrinter.makeHIResponse()
        } else if req.contains("~HS") {
            var combined = Data()
            for f in FakePrinter.makeHSResponse() { combined.append(f) }
            response = combined
        } else if req.contains("~HM") {
            response = FakePrinter.makeHMResponse()
        } else if req.contains("^HH") {
            response = answerHH ? FakePrinter.makeHHResponse() : nil
        } else {
            response = nil
        }

        if let response {
            writeAll(fd, response)
        }
        closeClient(fd)
    }

    private func writeAll(_ fd: Int32, _ data: Data) {
        data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let base = raw.baseAddress else { return }
            var sent = 0
            let count = raw.count
            while sent < count {
                let w = Darwin.write(fd, base + sent, count - sent)
                if w <= 0 { if w < 0 && errno == EINTR { continue }; break }
                sent += w
            }
        }
    }

    private func closeClient(_ fd: Int32) {
        lock.lock()
        if let idx = clientFDs.firstIndex(of: fd) { clientFDs.remove(at: idx) }
        lock.unlock()
        Darwin.close(fd)
    }
}
