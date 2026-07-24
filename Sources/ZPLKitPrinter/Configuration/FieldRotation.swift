/// Default rotation applied to all fields on a label.
///
/// Maps to ZPL command `^FW`.
@frozen public enum FieldRotation: String, Sendable, Codable, CaseIterable {
    /// Normal orientation (no rotation).
    case normal = "N"

    /// Rotated 90 degrees clockwise.
    case rotate90 = "R"

    /// Rotated 180 degrees.
    case rotate180 = "I"

    /// Rotated 270 degrees clockwise.
    case rotate270 = "B"
}
