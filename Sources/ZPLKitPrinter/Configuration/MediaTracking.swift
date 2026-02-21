/// How the printer detects individual labels on the media roll.
///
/// Maps to ZPL command `^MN`.
@frozen public enum MediaTracking: String, Sendable, Codable, CaseIterable {
    /// Gap/notch sensing between labels (most common for die-cut labels).
    case gap = "N"

    /// Continuous media with no gaps or marks.
    case continuous = "Y"

    /// Black mark sensing on the back of the media.
    case mark = "M"

    /// Auto-detect media type during calibration.
    case auto = "A"
}
