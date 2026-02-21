/// The default orientation for printed labels.
///
/// Maps to ZPL command `^PO`.
@frozen public enum PrintOrientation: String, Sendable, Codable, CaseIterable {
    /// Normal orientation (no inversion).
    case normal = "N"

    /// Inverted (rotated 180 degrees).
    case inverted = "I"
}
