/// Dithering method for converting grayscale images to monochrome.
///
/// Dithering simulates shades of gray using patterns of black and white dots.
/// This produces natural-looking halftone output on thermal printers,
/// especially for photographs and gradients.
///
/// ## Usage
///
/// ```swift
/// Graphic(photo, at: .inches(0.25, 0.25), width: .inches(2))
///     .dither(.floydSteinberg)
/// ```
public enum DitherMethod: Sendable, Equatable, Hashable {
    /// Simple threshold at 128 (current default behavior).
    /// Best for icons, line art, and high-contrast images.
    case none

    /// Floyd-Steinberg error diffusion dithering.
    /// Produces natural-looking halftones. Good general-purpose choice for photos.
    case floydSteinberg

    /// Atkinson dithering (distributes only 6/8 of error).
    /// Lighter result that preserves more whites. Good for text-heavy images
    /// or when you want a cleaner look.
    case atkinson

    /// Custom threshold value (0-255).
    /// Lower values produce more black; higher values produce more white.
    case threshold(UInt8)
}
