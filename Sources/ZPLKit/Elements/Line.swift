/// A horizontal line element.
public struct HorizontalLine: ZPLElement, Equatable, Hashable {
    private let position: Position
    private let lineLength: Dimension
    private let lineThickness: Dimension

    /// Creates a horizontal line at the given position.
    /// - Parameters:
    ///   - position: The position on the label.
    ///   - length: The length of the line.
    ///   - thickness: The thickness of the line (default 2 dots).
    public init(at position: Position, length: Dimension, thickness: Dimension = 2) {
        self.position = position
        self.lineLength = length
        self.lineThickness = thickness
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        // Clamp to >= 1 dot: ^GB with a zero/negative dimension is out-of-range
        // and behaves inconsistently across firmware (same guard as Box/Circle).
        let length = max(1, lineLength.resolve(dpi: context.dpi))
        let thick = max(1, lineThickness.resolve(dpi: context.dpi))

        // A horizontal line is a box with width = length and height = thickness
        return "^FO\(pos.x),\(pos.y)^GB\(length),\(thick),\(thick)^FS"
    }
}

/// A vertical line element.
public struct VerticalLine: ZPLElement, Equatable, Hashable {
    private let position: Position
    private let lineLength: Dimension
    private let lineThickness: Dimension

    /// Creates a vertical line at the given position.
    /// - Parameters:
    ///   - position: The position on the label.
    ///   - length: The length of the line.
    ///   - thickness: The thickness of the line (default 2 dots).
    public init(at position: Position, length: Dimension, thickness: Dimension = 2) {
        self.position = position
        self.lineLength = length
        self.lineThickness = thickness
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        // Clamp to >= 1 dot: ^GB with a zero/negative dimension is out-of-range
        // and behaves inconsistently across firmware (same guard as Box/Circle).
        let length = max(1, lineLength.resolve(dpi: context.dpi))
        let thick = max(1, lineThickness.resolve(dpi: context.dpi))

        // A vertical line is a box with width = thickness and height = length
        return "^FO\(pos.x),\(pos.y)^GB\(thick),\(length),\(thick)^FS"
    }
}
