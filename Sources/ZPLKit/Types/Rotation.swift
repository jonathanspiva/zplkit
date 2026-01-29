/// Rotation options for text and barcodes.
///
/// ## Usage
///
/// ```swift
/// Text("SIDE", at: .inches(0.5, 0.5))
///     .rotated(.rotated90)
///
/// Barcode128("12345", at: .inches(0.5, 1.0))?
///     .rotated(.rotated270)
/// ```
public enum Rotation: String, Sendable {
    /// No rotation (0 degrees).
    case normal = "N"
    /// Rotated 90 degrees clockwise.
    case rotated90 = "R"
    /// Rotated 180 degrees (upside down).
    case inverted = "I"
    /// Rotated 270 degrees clockwise (90 degrees counter-clockwise).
    case rotated270 = "B"
}
