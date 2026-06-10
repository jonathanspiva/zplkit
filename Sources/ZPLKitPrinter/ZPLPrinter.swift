import Foundation
import Network

/// Thread-safe replacement for `strerror`, which returns a pointer to a shared
/// static buffer and is therefore not reentrant. `send()` runs its blocking
/// socket work on `DispatchQueue.global()`, so concurrent calls can race on
/// that buffer. `strerror_r` writes into a caller-provided buffer instead.
///
/// On Darwin (and other XSI-compliant platforms) `strerror_r` returns an
/// `Int32` (0 on success); the GNU variant that returns a `char *` is not used
/// here.
private func posixErrorString(_ code: Int32) -> String {
    var buffer = [UInt8](repeating: 0, count: 256)
    let result = buffer.withUnsafeMutableBytes { raw -> Int32 in
        guard let base = raw.baseAddress else { return -1 }
        return strerror_r(code, base.assumingMemoryBound(to: CChar.self), raw.count)
    }
    // XSI-compliant strerror_r returns 0 on success.
    if result == 0 {
        // Decode up to the NUL terminator written by strerror_r.
        let bytes = buffer.prefix { $0 != 0 }
        return String(decoding: bytes, as: UTF8.self)
    }
    return "Unknown error \(code)"
}

/// Actor to safely manage query (send + receive) state across async callbacks.
private actor QueryState {
    private var continuation: CheckedContinuation<Data, Error>?
    private var hasCompleted = false
    private var pendingResult: Result<Data, Error>?
    private var responseBuffer = Data()
    private var hasSentCommand = false
    private var lastReceiveTime: UInt64 = 0

    func setContinuation(_ continuation: CheckedContinuation<Data, Error>) {
        // If a result was already produced before the continuation was
        // registered (e.g. the connection failed before the detached
        // setup task ran), resume immediately with that result rather than
        // storing the continuation. Otherwise the continuation would never
        // be resumed and query() would hang forever.
        if let pending = pendingResult {
            self.pendingResult = nil
            QueryState.resume(continuation, with: pending)
        } else {
            self.continuation = continuation
        }
    }

    func markCommandSent() {
        hasSentCommand = true
    }

    func hasCommandBeenSent() -> Bool {
        hasSentCommand
    }

    func appendResponse(_ data: Data) {
        responseBuffer.append(data)
        lastReceiveTime = DispatchTime.now().uptimeNanoseconds
    }

    func getResponseBuffer() -> Data {
        responseBuffer
    }

    func getLastReceiveTime() -> UInt64 {
        lastReceiveTime
    }

    /// Number of complete ETX-terminated frames in the response buffer.
    func etxFrameCount() -> Int {
        responseBuffer.reduce(0) { $1 == 0x03 ? $0 + 1 : $0 }
    }

    func complete(with result: Result<Data, Error>) {
        // Only the first completion wins; subsequent calls are ignored.
        guard !hasCompleted else { return }
        hasCompleted = true

        if let continuation = continuation {
            self.continuation = nil
            QueryState.resume(continuation, with: result)
        } else {
            // The continuation hasn't been registered yet. Stash the result
            // so setContinuation() can resume it as soon as it arrives.
            pendingResult = result
        }
    }

    func isCompleted() -> Bool {
        hasCompleted
    }

    private static func resume(
        _ continuation: CheckedContinuation<Data, Error>,
        with result: Result<Data, Error>
    ) {
        switch result {
        case .success(let data):
            continuation.resume(returning: data)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

/// Sends ZPL commands to a Zebra printer over TCP.
///
/// ZPLPrinter provides a simple async interface for sending ZPL data to printers
/// on the local network. It handles connection management automatically.
///
/// ## Basic Usage
///
/// ```swift
/// let printer = ZPLPrinter(host: "192.168.1.100")
/// try await printer.send(label.render())
/// ```
///
/// ## With Discovered Printer
///
/// ```swift
/// let browser = ZPLPrinterBrowser()
/// for await discovered in browser.printers {
///     try await ZPLPrinter.send(zpl, to: discovered)
///     break
/// }
/// ```
public struct ZPLPrinter: Sendable {
    /// Default port for Zebra raw printing.
    public static let defaultPort: UInt16 = 9100

    /// Default connection timeout in seconds.
    public static let defaultTimeout: TimeInterval = 10

    /// The printer's hostname or IP address.
    public let host: String

    /// The port number (typically 9100).
    public let port: UInt16

    /// Connection timeout in seconds.
    public let timeout: TimeInterval

    /// Creates a printer connection configuration.
    ///
    /// - Parameters:
    ///   - host: The printer's hostname or IP address.
    ///   - port: The port number. Defaults to 9100.
    ///   - timeout: Connection timeout in seconds. Defaults to 10.
    public init(
        host: String,
        port: UInt16 = defaultPort,
        timeout: TimeInterval = defaultTimeout
    ) {
        self.host = host
        self.port = port
        self.timeout = timeout
    }

    /// Creates a printer from a discovered printer.
    ///
    /// - Parameters:
    ///   - printer: A printer discovered via Bonjour.
    ///   - timeout: Connection timeout in seconds. Defaults to 10.
    public init(
        _ printer: DiscoveredPrinter,
        timeout: TimeInterval = defaultTimeout
    ) {
        self.host = printer.host
        self.port = printer.port
        self.timeout = timeout
    }

    /// Sends ZPL data to the printer.
    ///
    /// This method establishes a connection, sends the data, and closes
    /// the connection. For sending multiple labels, call this method
    /// multiple times or concatenate the ZPL strings.
    ///
    /// - Parameter zpl: The ZPL command string to send.
    /// - Throws: `PrinterError` if the connection or send fails.
    public func send(_ zpl: String) async throws {
        guard let data = zpl.data(using: .utf8) else {
            throw PrinterError.invalidConfiguration("ZPL string could not be encoded as UTF-8")
        }
        try await send(data)
    }

    /// Sends raw data to the printer.
    ///
    /// Uses POSIX sockets for reliable delivery. NWConnection's cancel() sends
    /// TCP RST which causes printers to discard buffered data, and its
    /// .finalMessage mode has issues with subsequent connections from the same
    /// process. POSIX close() sends a clean TCP FIN that printers handle correctly.
    ///
    /// - Parameter data: The data to send.
    /// - Throws: `PrinterError` if the connection or send fails.
    public func send(_ data: Data) async throws {
        // An empty send is a no-op success. Returning early also avoids a
        // trap on `baseAddress` being nil for empty Data in withUnsafeBytes.
        guard !data.isEmpty else { return }

        // Honor cancellation before committing to blocking C socket work.
        try Task.checkCancellation()

        let host = self.host
        let port = self.port
        let timeout = self.timeout

        // Validate the port up front for parity with query(). A zero port
        // cannot be connected to and would otherwise fail opaquely.
        guard port != 0 else {
            throw PrinterError.invalidConfiguration("Port \(port) is not valid")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global().async {
                // Set send timeout, preserving fractional seconds. Clamp to a
                // 1-day ceiling so an extreme/.infinity timeout can't trap the
                // Int/Int32 conversions below.
                let clampedTimeout = min(max(0, timeout), 86_400)
                let timeoutSeconds = Int(clampedTimeout)
                let timeoutMicros = Int32((clampedTimeout - Double(timeoutSeconds)) * 1_000_000)

                // Resolve the host with getaddrinfo, supporting both IPv4 and
                // IPv6 (and DNS hostnames). The original code only accepted IPv4
                // dotted-quad literals via inet_pton, but the API promises
                // "hostname or IP address" and DiscoveredPrinter.host can be a
                // hostname or an IPv6 string.
                var hints = addrinfo()
                hints.ai_family = AF_UNSPEC
                hints.ai_socktype = SOCK_STREAM
                hints.ai_protocol = IPPROTO_TCP

                var addrList: UnsafeMutablePointer<addrinfo>?
                let gaiResult = host.withCString { hostPtr in
                    String(port).withCString { portPtr in
                        getaddrinfo(hostPtr, portPtr, &hints, &addrList)
                    }
                }

                guard gaiResult == 0, let resolved = addrList else {
                    if let addrList { freeaddrinfo(addrList) }
                    let detail = String(cString: gai_strerror(gaiResult))
                    continuation.resume(throwing: PrinterError.connectionFailed(
                        host: host, port: port, underlying: "Could not resolve host: \(detail)"))
                    return
                }
                // freeaddrinfo must run on every exit path below.
                defer { freeaddrinfo(resolved) }

                // Try each resolved address until one connects.
                var lastError: PrinterError?
                var connectedSock: Int32 = -1

                var candidate: UnsafeMutablePointer<addrinfo>? = resolved
                connectLoop: while let info = candidate {
                    defer { candidate = info.pointee.ai_next }

                    let sock = socket(info.pointee.ai_family,
                                      info.pointee.ai_socktype,
                                      info.pointee.ai_protocol)
                    guard sock >= 0 else {
                        lastError = PrinterError.connectionFailed(
                            host: host, port: port, underlying: "Failed to create socket")
                        continue
                    }

                    // Prevent SIGPIPE (which terminates the host process by
                    // default) if the printer resets the connection mid-write.
                    // Darwin has no MSG_NOSIGNAL, so SO_NOSIGPIPE is the right
                    // mechanism.
                    var on: Int32 = 1
                    setsockopt(sock, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))

                    var tv = timeval(tv_sec: timeoutSeconds, tv_usec: timeoutMicros)
                    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

                    // Non-blocking connect with poll() for connect timeout.
                    let getFlags = fcntl(sock, F_GETFL, 0)
                    guard getFlags >= 0 else {
                        let savedErrno = errno
                        let err = posixErrorString(savedErrno)
                        Darwin.close(sock)
                        lastError = PrinterError.connectionFailed(
                            host: host, port: port, underlying: "fcntl(F_GETFL) failed: \(err)")
                        continue
                    }
                    _ = fcntl(sock, F_SETFL, getFlags | O_NONBLOCK)

                    let connectResult = Darwin.connect(sock, info.pointee.ai_addr, info.pointee.ai_addrlen)
                    let connectErrno = errno

                    if connectResult != 0 && connectErrno != EINPROGRESS {
                        let err = posixErrorString(connectErrno)
                        Darwin.close(sock)
                        lastError = PrinterError.connectionFailed(
                            host: host, port: port, underlying: err)
                        continue
                    }

                    if connectResult != 0 {
                        // poll() expects milliseconds; preserve fractional timeout.
                        let pollTimeoutMillis = Int32((clampedTimeout * 1000).rounded())
                        var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
                        let pollResult = poll(&pfd, 1, pollTimeoutMillis)
                        if pollResult <= 0 {
                            Darwin.close(sock)
                            lastError = PrinterError.timeout(host: host, port: port)
                            continue
                        }

                        var soError: Int32 = 0
                        var soLen = socklen_t(MemoryLayout<Int32>.size)
                        let getsockoptResult = getsockopt(sock, SOL_SOCKET, SO_ERROR, &soError, &soLen)
                        if getsockoptResult != 0 {
                            let savedErrno = errno
                            let err = posixErrorString(savedErrno)
                            Darwin.close(sock)
                            lastError = PrinterError.connectionFailed(
                                host: host, port: port, underlying: "getsockopt(SO_ERROR) failed: \(err)")
                            continue
                        }
                        if soError != 0 {
                            Darwin.close(sock)
                            if soError == ETIMEDOUT {
                                lastError = PrinterError.timeout(host: host, port: port)
                            } else if soError == ECONNREFUSED {
                                lastError = PrinterError.connectionFailed(
                                    host: host, port: port, underlying: "Connection refused")
                            } else {
                                let err = posixErrorString(soError)
                                lastError = PrinterError.connectionFailed(
                                    host: host, port: port, underlying: err)
                            }
                            continue
                        }
                    }

                    // Connected successfully.
                    connectedSock = sock
                    break connectLoop
                }

                guard connectedSock >= 0 else {
                    continuation.resume(throwing: lastError ?? PrinterError.connectionFailed(
                        host: host, port: port, underlying: "Could not connect to any resolved address"))
                    return
                }

                let sock = connectedSock

                // Restore blocking mode for write.
                let blockingFlags = fcntl(sock, F_GETFL, 0)
                if blockingFlags >= 0 {
                    _ = fcntl(sock, F_SETFL, blockingFlags & ~O_NONBLOCK)
                }

                // Loop until all bytes are written. A single blocking write()
                // can short-write large payloads (e.g. ^GFA graphics) and can
                // be interrupted (EINTR) on a healthy socket.
                let count = data.count
                var sent = 0
                var writeErrno: Int32 = 0
                data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
                    guard let base = raw.baseAddress else { return }
                    while sent < count {
                        let n = Darwin.write(sock, base + sent, count - sent)
                        if n < 0 {
                            if errno == EINTR { continue }
                            writeErrno = errno
                            break
                        }
                        if n == 0 { break }
                        sent += n
                    }
                }

                // close() sends TCP FIN for graceful shutdown.
                Darwin.close(sock)

                if sent == count {
                    continuation.resume()
                } else if writeErrno != 0 {
                    let err = posixErrorString(writeErrno)
                    continuation.resume(throwing: PrinterError.sendFailed(underlying: err))
                } else {
                    continuation.resume(throwing: PrinterError.sendFailed(
                        underlying: "Partial write: \(sent) of \(count) bytes"))
                }
            }
        }
    }

    /// Converts a `TimeInterval` (seconds) to nanoseconds, clamped to a
    /// non-negative range so the `UInt64` conversion can never trap.
    private func nanoseconds(from interval: TimeInterval) -> UInt64 {
        let clamped = min(max(0, interval), TimeInterval(UInt64.max) / 1_000_000_000)
        return UInt64(clamped * 1_000_000_000)
    }

    // MARK: - Query (Bidirectional Communication)

    /// Sends a command and waits for a response from the printer.
    ///
    /// Use this method for ZPL control commands that return data, such as:
    /// - `~HS` (Host Status)
    /// - `~HI` (Host Identification)
    /// - `~HM` (Host RAM Status)
    ///
    /// The connection stays open after sending to receive the printer's response.
    /// Response data is collected until the response timeout expires or a complete
    /// response is detected (ETX character).
    ///
    /// - Important: Zebra printers may not respond to status queries when in
    ///   error states (MEDIA OUT, RIBBON OUT, HEAD OPEN). A timeout may indicate
    ///   a printer error condition, not just a network issue.
    ///
    /// - Parameters:
    ///   - command: The ZPL control command to send (e.g., "~HS").
    ///   - responseTimeout: Time to wait for response after sending. Defaults to 5 seconds.
    /// - Returns: The raw response data from the printer.
    /// - Throws: `PrinterError` if connection, send, or receive fails.
    public func query(_ command: String, responseTimeout: TimeInterval = 5) async throws -> Data {
        guard let data = command.data(using: .utf8) else {
            throw PrinterError.invalidConfiguration("Command could not be encoded as UTF-8")
        }
        return try await query(data, responseTimeout: responseTimeout)
    }

    /// Sends raw data and waits for a response from the printer.
    ///
    /// - Parameters:
    ///   - data: The data to send.
    ///   - responseTimeout: Time to wait for response after sending. Defaults to 5 seconds.
    /// - Returns: The raw response data from the printer.
    /// - Throws: `PrinterError` if connection, send, or receive fails.
    public func query(_ data: Data, responseTimeout: TimeInterval = 5) async throws -> Data {
        let host = self.host
        let port = self.port
        // Clamp timeouts to a non-negative range to avoid trapping when
        // converting a negative or absurdly large TimeInterval to UInt64.
        let connectionTimeoutNanos = nanoseconds(from: timeout)
        let responseTimeoutNanos = nanoseconds(from: responseTimeout)

        // Reject port 0 explicitly. NWEndpoint.Port(rawValue:) accepts 0 (so the
        // original force-unwrap would not have crashed on 0 specifically), but 0
        // is not a connectable port and connecting to it just hangs until the
        // timeout. Guarding also covers any future rawValue that returns nil.
        guard port != 0, let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw PrinterError.invalidConfiguration("Port \(port) is not valid")
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: endpointPort,
            using: .tcp
        )

        // The ~HS (Host Status) query returns three separate
        // <STX>...<ETX><CR><LF> frames, which can arrive in separate TCP
        // segments. Detect it so the receive handler waits for all three
        // frames rather than completing on the first ETX. Other queries
        // (~HI, ~HM, ...) return a single frame and complete on one ETX.
        let isStatusQuery = (String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() == "~HS")

        let state = QueryState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                Task {
                    await state.setContinuation(continuation)
                }

                // Connection timeout (before we're connected)
                Task {
                    try? await Task.sleep(nanoseconds: connectionTimeoutNanos)
                    if await !state.hasCommandBeenSent() {
                        await state.complete(with: .failure(PrinterError.timeout(host: host, port: port)))
                        connection.cancel()
                    }
                }

                connection.stateUpdateHandler = { connectionState in
                    switch connectionState {
                    case .ready:
                        // Connection established, send command
                        connection.send(content: data, completion: .contentProcessed { error in
                            Task {
                                if let error = error {
                                    await state.complete(with: .failure(PrinterError.sendFailed(underlying: error.localizedDescription)))
                                    connection.cancel()
                                    return
                                }

                                await state.markCommandSent()

                                // Start response timeout after send completes.
                                // Uses an idle check: if data has been received but
                                // no new data arrives within 1s, return what we have.
                                // This avoids waiting the full timeout for responses
                                // without ETX framing (like ^HH).
                                Task {
                                    let idleThresholdNanos: UInt64 = 1_000_000_000  // 1 second
                                    let checkIntervalNanos: UInt64 = 500_000_000     // check every 500ms
                                    let deadline = DispatchTime.now().uptimeNanoseconds + responseTimeoutNanos

                                    while DispatchTime.now().uptimeNanoseconds < deadline {
                                        try? await Task.sleep(nanoseconds: checkIntervalNanos)
                                        if await state.isCompleted() { return }

                                        let buffer = await state.getResponseBuffer()
                                        let lastRecv = await state.getLastReceiveTime()
                                        if !buffer.isEmpty && lastRecv > 0 {
                                            let elapsed = DispatchTime.now().uptimeNanoseconds - lastRecv
                                            if elapsed >= idleThresholdNanos {
                                                await state.complete(with: .success(buffer))
                                                connection.cancel()
                                                return
                                            }
                                        }
                                    }

                                    // Full timeout reached
                                    if await !state.isCompleted() {
                                        let buffer = await state.getResponseBuffer()
                                        if buffer.isEmpty {
                                            await state.complete(with: .failure(PrinterError.responseTimeout(host: host, port: port)))
                                        } else {
                                            await state.complete(with: .success(buffer))
                                        }
                                        connection.cancel()
                                    }
                                }

                                // Start receiving response
                                self.receiveResponse(connection: connection, state: state, isStatusQuery: isStatusQuery)
                            }
                        })

                    case .failed(let error):
                        Task {
                            await state.complete(with: .failure(PrinterError.connectionFailed(
                                host: host,
                                port: port,
                                underlying: error.localizedDescription
                            )))
                        }
                        connection.cancel()

                    case .cancelled:
                        // The connection was cancelled (e.g. the awaiting task
                        // was cancelled via onCancel). Complete with
                        // CancellationError so query() resolves immediately
                        // rather than hanging until the connection-timeout task
                        // fires. complete() is idempotent, so if a real result
                        // was already produced before cancellation this is a
                        // no-op.
                        Task {
                            await state.complete(with: .failure(CancellationError()))
                        }

                    default:
                        break
                    }
                }

                connection.start(queue: .global())
            }
        } onCancel: {
            connection.cancel()
        }
    }

    /// Recursively receives response data until complete or connection closes.
    ///
    /// - Parameter isStatusQuery: When true (a `~HS` query), the response is
    ///   three `<STX>...<ETX><CR><LF>` frames and may span multiple TCP
    ///   segments, so completion waits until all three ETX frames have arrived.
    ///   Single-frame queries (~HI, ~HM, ...) complete on their single ETX.
    private func receiveResponse(connection: NWConnection, state: QueryState, isStatusQuery: Bool) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { content, _, isComplete, error in
            Task {
                if await state.isCompleted() {
                    return
                }

                if let error = error {
                    await state.complete(with: .failure(PrinterError.receiveFailed(underlying: error.localizedDescription)))
                    connection.cancel()
                    return
                }

                if let data = content, !data.isEmpty {
                    await state.appendResponse(data)

                    // Check if response is complete (ends with ETX = 0x03)
                    // ZPL control responses end with ETX CR LF (0x03 0x0D 0x0A)
                    let buffer = await state.getResponseBuffer()
                    if buffer.last == 0x0A && buffer.count >= 3 {
                        // ~HS returns three ETX-terminated frames; wait for all
                        // three. Other queries return a single frame and
                        // complete on their first (and only) ETX. The idle
                        // timer remains a fallback if fewer frames arrive.
                        let requiredFrames = isStatusQuery ? 3 : 1
                        if await state.etxFrameCount() >= requiredFrames {
                            await state.complete(with: .success(buffer))
                            connection.cancel()
                            return
                        }
                    }
                }

                if isComplete {
                    // Connection closed by printer
                    let buffer = await state.getResponseBuffer()
                    if buffer.isEmpty {
                        await state.complete(with: .failure(PrinterError.responseTimeout(host: self.host, port: self.port)))
                    } else {
                        await state.complete(with: .success(buffer))
                    }
                    connection.cancel()
                    return
                }

                // Continue receiving
                self.receiveResponse(connection: connection, state: state, isStatusQuery: isStatusQuery)
            }
        }
    }

    /// Convenience method to send ZPL to a discovered printer.
    ///
    /// - Parameters:
    ///   - zpl: The ZPL command string to send.
    ///   - printer: The discovered printer to send to.
    ///   - timeout: Connection timeout in seconds.
    /// - Throws: `PrinterError` if the connection or send fails.
    public static func send(
        _ zpl: String,
        to printer: DiscoveredPrinter,
        timeout: TimeInterval = defaultTimeout
    ) async throws {
        let connection = ZPLPrinter(printer, timeout: timeout)
        try await connection.send(zpl)
    }

    /// Convenience method to query a discovered printer.
    ///
    /// - Parameters:
    ///   - command: The ZPL control command to send.
    ///   - printer: The discovered printer to query.
    ///   - timeout: Connection timeout in seconds.
    ///   - responseTimeout: Time to wait for response after sending.
    /// - Returns: The raw response data from the printer.
    /// - Throws: `PrinterError` if the connection, send, or receive fails.
    public static func query(
        _ command: String,
        from printer: DiscoveredPrinter,
        timeout: TimeInterval = defaultTimeout,
        responseTimeout: TimeInterval = 5
    ) async throws -> Data {
        let connection = ZPLPrinter(printer, timeout: timeout)
        return try await connection.query(command, responseTimeout: responseTimeout)
    }

    // MARK: - Status Queries

    /// Queries the printer's current status using the `~HS` command.
    ///
    /// Returns a `PrinterStatus` object containing information about:
    /// - Error conditions (paper out, ribbon out, head open, overheating)
    /// - Operational state (paused, buffer full, partial format in progress)
    /// - Print job info (formats in buffer, labels remaining)
    ///
    /// ## Example
    ///
    /// ```swift
    /// let printer = ZPLPrinter(host: "192.168.1.100")
    /// let status = try await printer.queryStatus()
    ///
    /// if status.isReadyToPrint {
    ///     try await printer.send(label.render())
    /// } else {
    ///     print("Printer not ready: \(status)")
    /// }
    /// ```
    ///
    /// - Important: The printer may not respond when in certain error states
    ///   (MEDIA OUT, RIBBON OUT, HEAD OPEN). A timeout may indicate an error.
    ///
    /// - Parameter responseTimeout: Time to wait for response. Defaults to 5 seconds.
    /// - Returns: The printer's current status.
    /// - Throws: `PrinterError` if the query fails or response cannot be parsed.
    public func queryStatus(responseTimeout: TimeInterval = 5) async throws -> PrinterStatus {
        let data = try await query("~HS", responseTimeout: responseTimeout)
        return try PrinterStatus.parse(from: data)
    }

    /// Queries status from a discovered printer.
    ///
    /// - Parameters:
    ///   - printer: The discovered printer to query.
    ///   - timeout: Connection timeout in seconds.
    ///   - responseTimeout: Time to wait for response after sending.
    /// - Returns: The printer's current status.
    /// - Throws: `PrinterError` if the query fails or response cannot be parsed.
    public static func queryStatus(
        from printer: DiscoveredPrinter,
        timeout: TimeInterval = defaultTimeout,
        responseTimeout: TimeInterval = 5
    ) async throws -> PrinterStatus {
        let connection = ZPLPrinter(printer, timeout: timeout)
        return try await connection.queryStatus(responseTimeout: responseTimeout)
    }

    /// Queries the printer's identification using the `~HI` command.
    ///
    /// Returns a `PrinterInfo` object containing:
    /// - Model name (e.g., "ZT410-203dpi")
    /// - Firmware version
    /// - Resolution (dots per millimeter / DPI)
    /// - Available memory
    /// - Installed options
    ///
    /// ## Example
    ///
    /// ```swift
    /// let printer = ZPLPrinter(host: "192.168.1.100")
    /// let info = try await printer.queryInfo()
    /// print("Connected to \(info.model) at \(info.dpi) dpi")
    /// ```
    ///
    /// - Parameter responseTimeout: Time to wait for response. Defaults to 5 seconds.
    /// - Returns: The printer's identification info.
    /// - Throws: `PrinterError` if the query fails or response cannot be parsed.
    public func queryInfo(responseTimeout: TimeInterval = 5) async throws -> PrinterInfo {
        let data = try await query("~HI", responseTimeout: responseTimeout)
        return try PrinterInfo.parse(from: data)
    }

    /// Queries identification from a discovered printer.
    ///
    /// - Parameters:
    ///   - printer: The discovered printer to query.
    ///   - timeout: Connection timeout in seconds.
    ///   - responseTimeout: Time to wait for response after sending.
    /// - Returns: The printer's identification info.
    /// - Throws: `PrinterError` if the query fails or response cannot be parsed.
    public static func queryInfo(
        from printer: DiscoveredPrinter,
        timeout: TimeInterval = defaultTimeout,
        responseTimeout: TimeInterval = 5
    ) async throws -> PrinterInfo {
        let connection = ZPLPrinter(printer, timeout: timeout)
        return try await connection.queryInfo(responseTimeout: responseTimeout)
    }

    /// Queries the printer's RAM memory status using the `~HM` command.
    ///
    /// Returns a `MemoryStatus` object containing:
    /// - Total RAM
    /// - Maximum usable RAM
    /// - Currently available (free) RAM
    ///
    /// ## Example
    ///
    /// ```swift
    /// let printer = ZPLPrinter(host: "192.168.1.100")
    /// let memory = try await printer.queryMemory()
    ///
    /// if memory.usagePercent > 90 {
    ///     print("Warning: Memory usage at \(memory.usagePercent)%")
    /// }
    /// ```
    ///
    /// - Parameter responseTimeout: Time to wait for response. Defaults to 5 seconds.
    /// - Returns: The printer's memory status.
    /// - Throws: `PrinterError` if the query fails or response cannot be parsed.
    public func queryMemory(responseTimeout: TimeInterval = 5) async throws -> MemoryStatus {
        let data = try await query("~HM", responseTimeout: responseTimeout)
        return try MemoryStatus.parse(from: data)
    }

    /// Queries memory status from a discovered printer.
    ///
    /// - Parameters:
    ///   - printer: The discovered printer to query.
    ///   - timeout: Connection timeout in seconds.
    ///   - responseTimeout: Time to wait for response after sending.
    /// - Returns: The printer's memory status.
    /// - Throws: `PrinterError` if the query fails or response cannot be parsed.
    public static func queryMemory(
        from printer: DiscoveredPrinter,
        timeout: TimeInterval = defaultTimeout,
        responseTimeout: TimeInterval = 5
    ) async throws -> MemoryStatus {
        let connection = ZPLPrinter(printer, timeout: timeout)
        return try await connection.queryMemory(responseTimeout: responseTimeout)
    }

    // MARK: - Test Page Commands

    /// Prints a configuration label showing current printer settings.
    ///
    /// The `~WC` command causes the printer to print a label with its current
    /// configuration, including:
    /// - Firmware version
    /// - Print speed and darkness
    /// - Label dimensions
    /// - Sensor calibration values
    /// - Network settings (if applicable)
    ///
    /// This is useful for verifying printer setup and troubleshooting.
    ///
    /// - Throws: `PrinterError` if the command cannot be sent.
    public func printConfigurationLabel() async throws {
        try await send("~WC")
    }
}
