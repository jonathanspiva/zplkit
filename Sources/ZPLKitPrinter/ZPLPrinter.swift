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
}
