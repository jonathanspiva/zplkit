/// A circle element.
///
/// Use `Circle` to draw circular shapes on labels.
///
/// ## Basic Usage
///
/// ```swift
/// Circle(at: .inches(0.5, 0.5), diameter: .inches(0.5))
/// ```
///
/// ## Filled Circle
///
/// ```swift
/// Circle(at: .inches(0.5, 0.5), diameter: .inches(0.3))
///     .filled()
/// ```
///
/// ## Custom Thickness
///
/// ```swift
/// Circle(at: .inches(0.5, 0.5), diameter: .inches(1.0))
///     .thickness(.dots(5))
/// ```
public struct Circle: ZPLElement {
    private let position: Position
    private let diameter: Dimension
    private var thickness: Dimension = .dots(1)
    private var isFilled: Bool = false
    private var isWhite: Bool = false

    /// Creates a circle at the given position with the specified diameter.
    ///
    /// - Parameters:
    ///   - position: The top-left corner of the circle's bounding box.
    ///   - diameter: The diameter of the circle.
    public init(at position: Position, diameter: Dimension) {
        self.position = position
        self.diameter = diameter
    }

    /// Sets the border thickness.
    ///
    /// Ignored when the circle is filled.
    ///
    /// - Parameter thickness: The line thickness.
    /// - Returns: A modified circle element.
    public func thickness(_ thickness: Dimension) -> Circle {
        var copy = self
        copy.thickness = thickness
        return copy
    }

    /// Fills the circle with solid color.
    ///
    /// - Returns: A modified circle element that is filled.
    public func filled() -> Circle {
        var copy = self
        copy.isFilled = true
        return copy
    }

    /// Renders the circle in white instead of black.
    ///
    /// Useful for creating knockouts or erasing parts of other elements.
    ///
    /// - Returns: A modified circle element that renders in white.
    public func white() -> Circle {
        var copy = self
        copy.isWhite = true
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let diam = diameter.resolve(dpi: context.dpi)
        let thick = isFilled ? diam : thickness.resolve(dpi: context.dpi)

        let color = isWhite ? "W" : "B"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^GC\(diam),\(thick),\(color)^FS"

        return result
    }
}
