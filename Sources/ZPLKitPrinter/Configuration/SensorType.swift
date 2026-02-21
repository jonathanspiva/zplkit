/// Which media sensor the printer uses for label detection.
///
/// Maps to ZPL command `^JS`.
@frozen public enum SensorType: String, Sendable, Codable, CaseIterable {
    /// Auto-select sensor based on media type.
    case auto = "A"

    /// Transmissive sensor (shines through media, for gap detection).
    case transmissive = "T"

    /// Reflective sensor (reads marks on back of media).
    case reflective = "R"
}
