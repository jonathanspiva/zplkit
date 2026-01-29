/// A circle element using ZPL's ^GC command.
public struct Circle: ZPLElement {
    private let position: Position
    private let diameter: Dimension
    private var thickness: Dimension = .dots(1)
    private var isFilled: Bool = false
    private var isWhite: Bool = false

    /// Creates a circle at the given position with the specified diameter.
    /// - Parameters:
    ///   - position: The position on the label (top-left of bounding box).
    ///   - diameter: The diameter of the circle.
    public init(at position: Position, diameter: Dimension) {
        self.position = position
        self.diameter = diameter
    }

    /// Sets the border thickness.
    public func thickness(_ thickness: Dimension) -> Circle {
        var copy = self
        copy.thickness = thickness
        return copy
    }

    /// Fills the circle with solid color.
    public func filled() -> Circle {
        var copy = self
        copy.isFilled = true
        return copy
    }

    /// Renders the circle in white (reverse).
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
