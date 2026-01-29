/// A position specification for placing elements on a label.
/// Converted to dots at render time using the label's DPI.
public enum Position: Sendable {
    case dots(Int, Int)
    case inches(Double, Double)
    case mm(Double, Double)

    /// Resolves this position to dots (x, y) using the given DPI.
    public func resolve(dpi: DPI) -> (x: Int, y: Int) {
        switch self {
        case .dots(let x, let y):
            return (x, y)
        case .inches(let x, let y):
            return (dpi.dots(fromInches: x), dpi.dots(fromInches: y))
        case .mm(let x, let y):
            return (dpi.dots(fromMM: x), dpi.dots(fromMM: y))
        }
    }
}
