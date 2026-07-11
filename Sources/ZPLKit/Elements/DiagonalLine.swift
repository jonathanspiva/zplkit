/// A diagonal line element using ZPL's ^GD command.
public struct DiagonalLine: ZPLElement, Equatable, Hashable {
    private let position: Position
    private let boxWidth: Dimension
    private let boxHeight: Dimension
    private var thickness: Dimension = .dots(1)
    private var isWhite: Bool = false
    private var direction: DiagonalDirection = .rightLeaning

    /// The direction of the diagonal line.
    @frozen
    public enum DiagonalDirection: String, Sendable, Codable, Hashable {
        /// Bottom-left to top-right, like "/" (default).
        case rightLeaning = "R"
        /// Top-left to bottom-right, like "\".
        case leftLeaning = "L"
    }

    /// Creates a diagonal line within the given bounding box.
    /// - Parameters:
    ///   - position: The position on the label (top-left of bounding box).
    ///   - width: The width of the bounding box.
    ///   - height: The height of the bounding box.
    public init(at position: Position, width: Dimension, height: Dimension) {
        self.position = position
        self.boxWidth = width
        self.boxHeight = height
    }

    /// Sets the line thickness.
    public func thickness(_ thickness: Dimension) -> DiagonalLine {
        var copy = self
        copy.thickness = thickness
        return copy
    }

    /// Sets the diagonal direction.
    public func direction(_ direction: DiagonalDirection) -> DiagonalLine {
        var copy = self
        copy.direction = direction
        return copy
    }

    /// Renders the line in white (reverse).
    public func white() -> DiagonalLine {
        var copy = self
        copy.isWhite = true
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        // Clamp to >= 1 dot: zero/negative ^GD parameters are out of range.
        let width = max(1, boxWidth.resolve(dpi: context.dpi))
        let height = max(1, boxHeight.resolve(dpi: context.dpi))
        let thick = max(1, thickness.resolve(dpi: context.dpi))

        let color = isWhite ? "W" : "B"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^GD\(width),\(height),\(thick),\(color),\(direction.rawValue)^FS"

        return result
    }
}
