/// A single-value dimension that can be expressed in dots, inches, or millimeters.
/// Converted to dots at render time using the label's DPI.
public enum Dimension: Sendable, ExpressibleByIntegerLiteral {
    case dots(Int)
    case inches(Double)
    case mm(Double)

    /// Allows integer literals to be used as dots: `.height(100)` instead of `.height(.dots(100))`
    public init(integerLiteral value: Int) {
        self = .dots(value)
    }

    /// Resolves this dimension to dots using the given DPI.
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
