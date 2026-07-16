import Foundation

/// A printer discovered on the local network (via `ZPLPrinterBrowser`).
public struct DiscoveredPrinter: Sendable, Hashable, Identifiable, CustomStringConvertible {
    /// Unique identifier for this printer instance.
    public let id: String

    /// The display name of the printer (its configured system name).
    public let name: String

    /// The hostname or IP address of the printer.
    public let host: String

    /// The port number (typically 9100 for raw printing).
    public let port: UInt16

    /// Additional discovery metadata (e.g. `firmware`, `product`, `server`).
    public let metadata: [String: String]

    public init(
        id: String = UUID().uuidString,
        name: String,
        host: String,
        port: UInt16 = 9100,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.metadata = metadata
    }

    public var description: String {
        "\(name) (\(host):\(port))"
    }

    public static func == (lhs: DiscoveredPrinter, rhs: DiscoveredPrinter) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
