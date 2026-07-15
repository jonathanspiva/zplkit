import Foundation
import Network

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
    /// Uses the Swift-native `NetworkConnection` API (macOS 26+):
    /// `withNetworkConnection` establishes the connection, the data is written
    /// with a single async `send`, and the connection is torn down when the
    /// handler returns. That teardown is a clean TCP FIN (empirically verified
    /// against a slow-draining listener on macOS 27: payload preserved, no RST),
    /// so printers receive buffered data intact — the reason the old code used
    /// POSIX `close()` rather than `NWConnection.cancel()`, which sent an RST
    /// that made printers discard buffered data.
    ///
    /// - Parameter data: The data to send.
    /// - Throws: `PrinterError` if the connection or send fails.
    public func send(_ data: Data) async throws {
        // An empty send is a no-op success and opens no connection.
        guard !data.isEmpty else { return }

        // Honor cancellation before opening a connection.
        try Task.checkCancellation()

        let host = self.host
        let port = self.port
        // TCP connect timeout in whole seconds, clamped to [1, 1 day]; the same
        // deadline bounds the send drain so a paused printer can't hang forever.
        let connectTimeoutSeconds = UInt32(min(max(1, timeout), 86_400))
        let sendTimeoutNanos = nanoseconds(from: timeout)

        // Validate the port up front for parity with query(). A zero port
        // cannot be connected to and would otherwise fail opaquely.
        guard port != 0, let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw PrinterError.invalidConfiguration("Port \(port) is not valid")
        }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: endpointPort)

        do {
            try await withNetworkConnection(
                to: endpoint,
                using: { TCP().connectionTimeout(connectTimeoutSeconds) }
            ) { connection in
                // Bound the write: if the printer stops draining (paused, buffer
                // full), the send would otherwise hang. Mirrors the old
                // SO_SNDTIMEO -> timeout behavior.
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        try await connection.send(data)
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: sendTimeoutNanos)
                        throw PrinterError.timeout(host: host, port: port)
                    }
                    // Wait for the send to finish (or the timeout to fire), then
                    // cancel the loser.
                    try await group.next()
                    group.cancelAll()
                }
            }
        } catch let error as PrinterError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Connect-phase failures (refused, unreachable, connect timeout) and
            // mid-send resets surface as NWError here.
            throw Self.mapConnectionError(error, host: host, port: port)
        }
    }

    /// Converts a `TimeInterval` (seconds) to nanoseconds, clamped to
    /// [0, 1 day].
    ///
    /// The ceiling matters: `TimeInterval(UInt64.max) / 1e9 * 1e9` rounds UP to
    /// exactly 2^64 and traps the `UInt64` conversion, so `.infinity` or
    /// `.greatestFiniteMagnitude` timeouts would crash here without the clamp.
    private func nanoseconds(from interval: TimeInterval) -> UInt64 {
        let clamped = min(max(0, interval), 86_400)
        return UInt64(clamped * 1_000_000_000)
    }

    // MARK: - Query (Bidirectional Communication)

    /// Reference holder for the response `Data` produced inside the
    /// `withNetworkConnection` handler (whose closure returns `Void`). The
    /// handler fully completes (via `await`) before the value is read, so this
    /// crosses no real concurrency boundary.
    private final class ResponseBox: @unchecked Sendable {
        var data = Data()
    }

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
    /// Uses the Swift-native `NetworkConnection` API (macOS 26+): the connection
    /// is established and torn down by `withNetworkConnection`, the command is
    /// sent, and the response is read with structured-concurrency `receive`
    /// calls. The response timeout is a task-group race started *after* the send
    /// completes, so a slow connect is bounded by the TCP connect timeout rather
    /// than mislabeled as a response timeout.
    ///
    /// - Parameters:
    ///   - data: The data to send.
    ///   - responseTimeout: Time to wait for response after sending. Defaults to 5 seconds.
    /// - Returns: The raw response data from the printer.
    /// - Throws: `PrinterError` if connection, send, or receive fails.
    public func query(_ data: Data, responseTimeout: TimeInterval = 5) async throws -> Data {
        let host = self.host
        let port = self.port
        let responseTimeoutNanos = nanoseconds(from: responseTimeout)
        // TCP connect timeout in whole seconds, clamped to [1, 1 day]. A 0 would
        // be ambiguous (disable vs immediate); .infinity clamps to the ceiling.
        let connectTimeoutSeconds = UInt32(min(max(1, timeout), 86_400))

        // Reject port 0 explicitly: it is not a connectable port and connecting
        // to it just hangs until the timeout.
        guard port != 0, let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw PrinterError.invalidConfiguration("Port \(port) is not valid")
        }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: endpointPort)

        // The ~HS (Host Status) query returns three separate
        // <STX>...<ETX><CR><LF> frames, which can arrive in separate TCP
        // segments. Detect it so the receive loop waits for all three frames
        // rather than completing on the first ETX. Other queries (~HI, ~HM, ...)
        // return a single frame and complete on one ETX.
        let isStatusQuery = (String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() == "~HS")

        let box = ResponseBox()

        do {
            try await withNetworkConnection(
                to: endpoint,
                using: { TCP().connectionTimeout(connectTimeoutSeconds) }
            ) { connection in
                try await connection.send(data)

                // Response timeout starts here, after the send: race the receive
                // loop against a sleep. Whichever finishes first wins; cancelAll
                // tears down the loser (and `withNetworkConnection` closes the
                // connection when this handler returns or throws).
                box.data = try await withThrowingTaskGroup(of: Data.self) { group in
                    group.addTask {
                        try await Self.collectResponse(
                            from: connection,
                            isStatusQuery: isStatusQuery,
                            host: host,
                            port: port
                        )
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: responseTimeoutNanos)
                        throw PrinterError.responseTimeout(host: host, port: port)
                    }
                    let first = try await group.next()!
                    group.cancelAll()
                    return first
                }
            }
        } catch let error as PrinterError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Connect-phase failures (refused, unreachable, connect timeout)
            // surface as NWError here.
            throw Self.mapConnectionError(error, host: host, port: port)
        }

        return box.data
    }

    /// Reads response frames until the response is complete, the printer closes
    /// the connection, or the receive stream goes idle for 1s after data has
    /// started arriving (a fallback for responses whose framing the completion
    /// check doesn't recognize).
    ///
    /// - Parameter isStatusQuery: When true (a `~HS` query), the response is
    ///   three `<STX>...<ETX><CR><LF>` frames and may span multiple TCP
    ///   segments, so completion waits until all three ETX frames have arrived.
    ///   Single-frame queries (~HI, ~HM, ...) complete on their single ETX.
    private static func collectResponse(
        from connection: NetworkConnection<TCP>,
        isStatusQuery: Bool,
        host: String,
        port: UInt16
    ) async throws -> Data {
        let idleThresholdNanos: UInt64 = 1_000_000_000  // 1 second
        var buffer = Data()

        while true {
            if buffer.isEmpty {
                // No data yet: wait for the first bytes. The outer response
                // timeout bounds this, so there's no per-receive idle timer.
                let message = try await connection.receive(atLeast: 1, atMost: 4096)
                buffer.append(message.content)
                if responseIsComplete(buffer, isStatusQuery: isStatusQuery) {
                    return buffer
                }
                if message.metadata.endOfStream {
                    // Printer closed the connection. An empty buffer means it
                    // never replied (mirrors the old responseTimeout path);
                    // otherwise return what arrived and let the parser judge it.
                    if buffer.isEmpty {
                        throw PrinterError.responseTimeout(host: host, port: port)
                    }
                    return buffer
                }
            } else {
                // Have data: race the next receive against the idle threshold.
                // If no new bytes arrive within 1s, return what we have. The
                // idle timer only fires here (never leaves an in-flight receive
                // pending across another receive on the same connection).
                enum Step: Sendable {
                    case chunk(Data, endOfStream: Bool)
                    case idle
                }

                let step = try await withThrowingTaskGroup(of: Step.self) { group in
                    group.addTask {
                        let message = try await connection.receive(atLeast: 1, atMost: 4096)
                        return .chunk(message.content, endOfStream: message.metadata.endOfStream)
                    }
                    group.addTask {
                        try? await Task.sleep(nanoseconds: idleThresholdNanos)
                        return .idle
                    }
                    let first = try await group.next()!
                    group.cancelAll()
                    return first
                }

                switch step {
                case .idle:
                    return buffer
                case .chunk(let content, let endOfStream):
                    buffer.append(content)
                    if responseIsComplete(buffer, isStatusQuery: isStatusQuery) {
                        return buffer
                    }
                    if endOfStream {
                        return buffer
                    }
                }
            }
        }
    }

    /// Whether the accumulated buffer represents a complete response.
    ///
    /// Framed responses (~HI/~HS/~HM) end each frame with ETX CR LF, so the
    /// buffer ends 0x0A. A `^HH` configuration dump ends with a bare ETX after
    /// the final CR LF (verified against real ZM400/GX420t fixtures:
    /// `... 0x0D 0x0A 0x03`), so a trailing ETX also completes. ~HS returns
    /// three ETX-terminated frames and requires all three; other queries return
    /// a single frame and complete on their first (and only) ETX.
    private static func responseIsComplete(_ buffer: Data, isStatusQuery: Bool) -> Bool {
        guard buffer.count >= 3, let last = buffer.last,
              last == 0x0A || last == 0x03 else {
            return false
        }
        let requiredFrames = isStatusQuery ? 3 : 1
        let etxFrameCount = buffer.reduce(0) { $1 == 0x03 ? $0 + 1 : $0 }
        return etxFrameCount >= requiredFrames
    }

    /// Maps a connect/transport error thrown by `withNetworkConnection` to a
    /// `PrinterError`. Timeout-class POSIX failures (connect timeout, host or
    /// network unreachable) become `.timeout`; everything else, including a
    /// refused connection (`ECONNREFUSED`), becomes `.connectionFailed`. This
    /// preserves the old POSIX-socket code's `ETIMEDOUT -> .timeout` vs
    /// `ECONNREFUSED -> .connectionFailed` distinction.
    private static func mapConnectionError(_ error: Error, host: String, port: UInt16) -> PrinterError {
        if let nwError = error as? NWError, case .posix(let code) = nwError {
            switch code {
            case .ETIMEDOUT, .EHOSTUNREACH, .ENETUNREACH, .ENETDOWN, .EHOSTDOWN:
                return .timeout(host: host, port: port)
            default:
                return .connectionFailed(host: host, port: port, underlying: "\(nwError)")
            }
        }
        return .connectionFailed(host: host, port: port, underlying: String(describing: error))
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
