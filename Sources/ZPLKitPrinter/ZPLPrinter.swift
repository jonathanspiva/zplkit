import Foundation
import Network

/// Actor to safely manage send state across async callbacks.
private actor SendState {
    private var continuation: CheckedContinuation<Void, Error>?
    private var hasCompleted = false

    func setContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func complete(with result: Result<Void, Error>) {
        guard !hasCompleted, let continuation = continuation else { return }
        hasCompleted = true
        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

/// Actor to safely manage query (send + receive) state across async callbacks.
private actor QueryState {
    private var continuation: CheckedContinuation<Data, Error>?
    private var hasCompleted = false
    private var responseBuffer = Data()
    private var hasSentCommand = false

    func setContinuation(_ continuation: CheckedContinuation<Data, Error>) {
        self.continuation = continuation
    }

    func markCommandSent() {
        hasSentCommand = true
    }

    func hasCommandBeenSent() -> Bool {
        hasSentCommand
    }

    func appendResponse(_ data: Data) {
        responseBuffer.append(data)
    }

    func getResponseBuffer() -> Data {
        responseBuffer
    }

    func complete(with result: Result<Data, Error>) {
        guard !hasCompleted, let continuation = continuation else { return }
        hasCompleted = true
        switch result {
        case .success(let data):
            continuation.resume(returning: data)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    func isCompleted() -> Bool {
        hasCompleted
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
    /// - Parameter data: The data to send.
    /// - Throws: `PrinterError` if the connection or send fails.
    public func send(_ data: Data) async throws {
        let host = self.host
        let port = self.port
        let timeoutNanoseconds = UInt64(timeout * 1_000_000_000)

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )

        // Use actor to safely track state across callbacks
        let state = SendState()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // Store continuation in actor
                Task {
                    await state.setContinuation(continuation)
                }

                // Set up timeout
                Task {
                    try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                    await state.complete(with: .failure(PrinterError.timeout(host: host, port: port)))
                    connection.cancel()
                }

                connection.stateUpdateHandler = { connectionState in
                    switch connectionState {
                    case .ready:
                        // Connection established, send data
                        connection.send(content: data, completion: .contentProcessed { error in
                            Task {
                                if let error = error {
                                    await state.complete(with: .failure(PrinterError.sendFailed(underlying: error.localizedDescription)))
                                } else {
                                    await state.complete(with: .success(()))
                                }
                            }
                            connection.cancel()
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
                        break

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
        let connectionTimeoutNanos = UInt64(timeout * 1_000_000_000)
        let responseTimeoutNanos = UInt64(responseTimeout * 1_000_000_000)

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: port)!,
            using: .tcp
        )

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

                                // Start response timeout after send completes
                                Task {
                                    try? await Task.sleep(nanoseconds: responseTimeoutNanos)
                                    if await !state.isCompleted() {
                                        let buffer = await state.getResponseBuffer()
                                        if buffer.isEmpty {
                                            await state.complete(with: .failure(PrinterError.responseTimeout(host: host, port: port)))
                                        } else {
                                            // Return whatever we got
                                            await state.complete(with: .success(buffer))
                                        }
                                        connection.cancel()
                                    }
                                }

                                // Start receiving response
                                self.receiveResponse(connection: connection, state: state)
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
                        break

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
    private func receiveResponse(connection: NWConnection, state: QueryState) {
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
                        // Check for ETX in the response (may have multiple strings)
                        // For ~HS, we expect 3 strings each ending with ETX CR LF
                        // For simplicity, we'll check if buffer contains ETX
                        if buffer.contains(0x03) {
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
                self.receiveResponse(connection: connection, state: state)
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
}
