/// A box (rectangle) element.
public struct Box: ZPLElement {
    private let position: Position
    private let boxWidth: Dimension
    private let boxHeight: Dimension
    private var thickness: Dimension = .dots(1)
    private var isFilled: Bool = false
    private var cornerRadius: Int = 0  // 0-8
    private var isWhite: Bool = false

    /// Creates a box at the given position with the specified dimensions.
    /// - Parameters:
    ///   - position: The position on the label.
    ///   - width: The width of the box.
    ///   - height: The height of the box.
    public init(at position: Position, width: Dimension, height: Dimension) {
        self.position = position
        self.boxWidth = width
        self.boxHeight = height
    }

    /// Sets the border thickness.
    public func thickness(_ thickness: Dimension) -> Box {
        var copy = self
        copy.thickness = thickness
        return copy
    }

    /// Fills the box with solid color.
    public func filled() -> Box {
        var copy = self
        copy.isFilled = true
        return copy
    }

    /// Sets the corner radius (0-8).
    public func cornerRadius(_ radius: Int) -> Box {
        var copy = self
        copy.cornerRadius = min(8, max(0, radius))
        return copy
    }

    /// Renders the box in white (reverse).
    public func white() -> Box {
        var copy = self
        copy.isWhite = true
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let width = boxWidth.resolve(dpi: context.dpi)
        let height = boxHeight.resolve(dpi: context.dpi)
        let thick = isFilled ? min(width, height) : thickness.resolve(dpi: context.dpi)

        let color = isWhite ? "W" : "B"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^GB\(width),\(height),\(thick),\(color),\(cornerRadius)^FS"

        return result
    }
}
