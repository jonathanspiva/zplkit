/// A position for placing elements on a label.
///
/// Positions can be specified in dots (printer native), inches, or millimeters.
/// The position is converted to dots at render time using the label's DPI setting.
///
/// ## Usage
///
/// Use the static factory methods for clear, readable code:
///
/// ```swift
/// // Position in inches (recommended for most use cases)
/// Text("Hello", at: .inches(0.5, 1.0))
///
/// // Position in millimeters
/// Text("Hello", at: .mm(12.7, 25.4))
///
/// // Position in dots (printer native)
/// Text("Hello", at: .dots(100, 200))
/// ```
///
/// ## Coordinate System
///
/// The origin (0, 0) is at the top-left corner of the label.
/// X increases to the right, Y increases downward.
public enum Position: Sendable, Codable, Equatable, Hashable {
    /// Position in dots (printer native resolution).
    ///
    /// - Parameters:
    ///   - x: Horizontal position from left edge in dots.
    ///   - y: Vertical position from top edge in dots.
    case dots(Int, Int)

    /// Position in inches, converted to dots at render time.
    ///
    /// - Parameters:
    ///   - x: Horizontal position from left edge in inches.
    ///   - y: Vertical position from top edge in inches.
    case inches(Double, Double)

    /// Position in millimeters, converted to dots at render time.
    ///
    /// - Parameters:
    ///   - x: Horizontal position from left edge in millimeters.
    ///   - y: Vertical position from top edge in millimeters.
    case mm(Double, Double)

    /// Resolves this position to dots using the given DPI.
    ///
    /// - Parameter dpi: The target printer DPI.
    /// - Returns: A tuple containing the X and Y coordinates in dots.
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
