/// How a source image is fitted into the target dimensions.
///
/// ## Usage
///
/// ```swift
/// Graphic(photo, at: .inches(0.25, 0.25), width: .inches(2), height: .inches(3))
///     .contentMode(.aspectFill)
/// ```
public enum ContentMode: Sendable, Equatable, Hashable {
    /// Stretch the image to fill the target dimensions exactly.
    /// May distort the image if aspect ratios differ. This is the default.
    case stretch

    /// Scale and center-crop to fill the target dimensions while maintaining aspect ratio.
    /// Parts of the image outside the target aspect ratio are cropped from the edges.
    case aspectFill
}
