import Foundation

/// Errors that can occur when communicating with a printer.
public enum PrinterError: Error, LocalizedError, Sendable {
    /// Failed to establish a connection to the printer.
    case connectionFailed(host: String, port: UInt16, underlying: String)

    /// Failed to send data to the printer.
    case sendFailed(underlying: String)

    /// Connection timed out.
    case timeout(host: String, port: UInt16)

    /// Printer was discovered but is no longer available.
    case printerNotFound(name: String)

    /// Invalid host or port configuration.
    case invalidConfiguration(String)

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let host, let port, let underlying):
            return "Failed to connect to \(host):\(port): \(underlying)"
        case .sendFailed(let underlying):
            return "Failed to send data: \(underlying)"
        case .timeout(let host, let port):
            return "Connection to \(host):\(port) timed out"
        case .printerNotFound(let name):
            return "Printer '\(name)' is no longer available"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }
}
