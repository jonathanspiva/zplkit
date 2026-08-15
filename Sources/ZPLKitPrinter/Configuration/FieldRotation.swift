/// Default rotation applied to all fields on a label.
///
/// Maps to ZPL command `^FW`.
@frozen public enum FieldRotation: String, Sendable, Codable, CaseIterable {
    /// Normal orientation (no rotation).
    case normal = "N"

    /// Rotated 90 degrees clockwise.
    case rotated90 = "R"

    /// Rotated 180 degrees (inverted).
    case inverted = "I"

    /// Rotated 270 degrees clockwise.
    case rotated270 = "B"
}
