/// Printer resolution presets matching common Zebra thermal printers.
///
/// DPI (dots per inch) determines the resolution of the printed label.
/// Higher DPI values produce sharper text and graphics but require more
/// processing and may print slower.
///
/// ## Choosing a DPI
///
/// Most Zebra printers use 203 DPI (8 dots/mm), which is the default.
/// Use the DPI that matches your physical printer:
///
/// | DPI | Dots/mm | Common Use |
/// |-----|---------|------------|
/// | 152 | 6 | Economy desktop printers |
/// | 200 | ~8 | Compatibility alias (see note below) |
/// | 203 | 8 | Standard desktop and industrial |
/// | 300 | 12 | High-quality printing |
/// | 600 | 24 | Ultra-fine detail |
///
/// ## Note on 200 vs 203 DPI
///
/// Zebra printheads are manufactured to metric specs. The standard "low resolution"
/// head has exactly 8 dots per millimeter, which converts to 203.2 DPI. Many printer
/// models display "200dpi" in their name (e.g., ZM400-200dpi, GX420t-200dpi), but
/// the actual printhead is 8 dpmm / 203 DPI. Use ``dpi200`` when working with systems
/// that label output as "200 DPI". Use ``dpi203`` for the most accurate dot placement.
/// The practical difference is ~1.5%.
///
/// ## Example
///
/// ```swift
/// // Create a label targeting a 300 DPI printer
/// let label = ZPLLabel(width: 4, height: 2, dpi: .dpi300) {
///     Text("High Resolution", at: .inches(0.25, 0.25))
/// }
/// ```
@frozen
public enum DPI: Int, Sendable, Codable, Hashable, CustomStringConvertible {
    /// 152 DPI (6 dots/mm) - Economy desktop printers.
    case dpi152 = 152

    /// 200 DPI (~8 dots/mm) - Compatibility alias for printers labeled "200dpi".
    ///
    /// The actual printhead resolution is 8 dots/mm (203.2 DPI). Many Zebra models
    /// display "200dpi" in their model name (ZM400-200dpi, GX420t-200dpi). Use this
    /// when matching systems that call it "200 DPI", or ``dpi203`` for the technically
    /// accurate value. See the type-level documentation for details.
    case dpi200 = 200

    /// 203 DPI (8 dots/mm) - Most common, standard resolution.
    case dpi203 = 203

    /// 300 DPI (12 dots/mm) - High quality printing.
    case dpi300 = 300

    /// 600 DPI (24 dots/mm) - Ultra high resolution.
    case dpi600 = 600

    /// Converts inches to dots at this DPI.
    ///
    /// - Parameter inches: The measurement in inches.
    /// - Returns: The equivalent number of dots, rounded to the nearest integer.
    public func dots(fromInches inches: Double) -> Int {
        Int((inches * Double(rawValue)).rounded())
    }

    /// Converts millimeters to dots at this DPI.
    ///
    /// - Parameter mm: The measurement in millimeters.
    /// - Returns: The equivalent number of dots, rounded to the nearest integer.
    public func dots(fromMM mm: Double) -> Int {
        let inches = mm / 25.4
        return dots(fromInches: inches)
    }

    public var description: String {
        "\(rawValue) DPI"
    }
}
