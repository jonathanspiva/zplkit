/// A single measurement value for widths, heights, and other dimensions.
///
/// Dimensions can be specified in dots (printer native), inches, or millimeters.
/// The value is converted to dots at render time using the label's DPI setting.
///
/// ## Usage
///
/// ```swift
/// // Dimension in inches
/// Box(at: .inches(0.5, 0.5), width: .inches(2.0), height: .inches(1.0))
///
/// // Dimension in millimeters
/// Box(at: .mm(10, 10), width: .mm(50), height: .mm(25))
///
/// // Dimension in dots
/// Box(at: .dots(100, 100), width: .dots(400), height: .dots(200))
/// ```
///
/// ## Integer Literals
///
/// For convenience, integer literals are interpreted as dots:
///
/// ```swift
/// // These are equivalent:
/// Barcode128("123", at: .inches(0.5, 0.5)).height(.dots(100))
/// Barcode128("123", at: .inches(0.5, 0.5)).height(100)
/// ```
public enum Dimension: Sendable, ExpressibleByIntegerLiteral {
    /// Dimension in dots (printer native resolution).
    case dots(Int)

    /// Dimension in inches, converted to dots at render time.
    case inches(Double)

    /// Dimension in millimeters, converted to dots at render time.
    case mm(Double)

    /// Creates a dimension from an integer literal, interpreted as dots.
    ///
    /// This allows writing `.height(100)` instead of `.height(.dots(100))`.
    ///
    /// - Parameter value: The dimension in dots.
    public init(integerLiteral value: Int) {
        self = .dots(value)
    }

    /// Resolves this dimension to dots using the given DPI.
    ///
    /// - Parameter dpi: The target printer DPI.
    /// - Returns: The dimension in dots.
    public func resolve(dpi: DPI) -> Int {
        switch self {
        case .dots(let value):
            return value
        case .inches(let value):
            return dpi.dots(fromInches: value)
        case .mm(let value):
            return dpi.dots(fromMM: value)
        }
    }
}
