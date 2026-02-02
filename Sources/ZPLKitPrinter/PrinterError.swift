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

    /// Failed to receive response from printer.
    case receiveFailed(underlying: String)

    /// Response timed out waiting for printer reply.
    ///
    /// Note: Zebra printers may not respond to status queries (~HS) when in
    /// error states like MEDIA OUT, RIBBON OUT, or HEAD OPEN. A response
    /// timeout may indicate a printer error, not just a network issue.
    case responseTimeout(host: String, port: UInt16)

    /// Received invalid or malformed response from printer.
    case invalidResponse(String)

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
        case .receiveFailed(let underlying):
            return "Failed to receive response: \(underlying)"
        case .responseTimeout(let host, let port):
            return "No response from \(host):\(port) (printer may be in error state)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        }
    }
}
