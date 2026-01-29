/// An ellipse element using ZPL's ^GE command.
public struct Ellipse: ZPLElement, Equatable, Hashable {
    private let position: Position
    private let ellipseWidth: Dimension
    private let ellipseHeight: Dimension
    private var thickness: Dimension = .dots(1)
    private var isFilled: Bool = false
    private var isWhite: Bool = false

    /// Creates an ellipse at the given position with the specified dimensions.
    /// - Parameters:
    ///   - position: The position on the label (top-left of bounding box).
    ///   - width: The width of the ellipse.
    ///   - height: The height of the ellipse.
    public init(at position: Position, width: Dimension, height: Dimension) {
        self.position = position
        self.ellipseWidth = width
        self.ellipseHeight = height
    }

    /// Sets the border thickness.
    public func thickness(_ thickness: Dimension) -> Ellipse {
        var copy = self
        copy.thickness = thickness
        return copy
    }

    /// Fills the ellipse with solid color.
    public func filled() -> Ellipse {
        var copy = self
        copy.isFilled = true
        return copy
    }

    /// Renders the ellipse in white (reverse).
    public func white() -> Ellipse {
        var copy = self
        copy.isWhite = true
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let width = ellipseWidth.resolve(dpi: context.dpi)
        let height = ellipseHeight.resolve(dpi: context.dpi)
        let thick = isFilled ? min(width, height) : thickness.resolve(dpi: context.dpi)

        let color = isWhite ? "W" : "B"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^GE\(width),\(height),\(thick),\(color)^FS"

        return result
    }
}
