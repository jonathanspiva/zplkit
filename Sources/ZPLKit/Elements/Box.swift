/// A rectangular box element.
///
/// Use `Box` to draw rectangles, borders, and filled regions on labels.
///
/// ## Basic Usage
///
/// ```swift
/// // Border box
/// Box(at: .inches(0.25, 0.25), width: .inches(2.0), height: .inches(1.0))
///
/// // Filled box
/// Box(at: .inches(0.25, 0.25), width: .inches(1.0), height: .inches(0.5))
///     .filled()
/// ```
///
/// ## Styling
///
/// ```swift
/// Box(at: .inches(0.5, 0.5), width: .inches(3.0), height: .inches(2.0))
///     .thickness(.dots(4))
///     .cornerRadius(3)
/// ```
///
/// ## White Boxes
///
/// Use ``white()`` to draw white boxes, useful for creating knockouts
/// or erasing parts of other elements:
///
/// ```swift
/// Box(at: .inches(1.0, 1.0), width: .inches(0.5), height: .inches(0.5))
///     .filled()
///     .white()
/// ```
public struct Box: ZPLElement, Equatable, Hashable {
    private let position: Position
    private let boxWidth: Dimension
    private let boxHeight: Dimension
    private var thickness: Dimension = .dots(1)
    private var isFilled: Bool = false
    private var cornerRadius: Int = 0  // 0-8
    private var isWhite: Bool = false

    /// Creates a box at the given position with the specified dimensions.
    ///
    /// - Parameters:
    ///   - position: The top-left corner position.
    ///   - width: The width of the box.
    ///   - height: The height of the box.
    public init(at position: Position, width: Dimension, height: Dimension) {
        self.position = position
        self.boxWidth = width
        self.boxHeight = height
    }

    /// Sets the border thickness.
    ///
    /// Ignored when the box is filled.
    ///
    /// - Parameter thickness: The line thickness.
    /// - Returns: A modified box element.
    public func thickness(_ thickness: Dimension) -> Box {
        var copy = self
        copy.thickness = thickness
        return copy
    }

    /// Fills the box with solid color.
    ///
    /// When filled, the thickness is automatically set to fill the entire box.
    ///
    /// - Returns: A modified box element that is filled.
    public func filled() -> Box {
        var copy = self
        copy.isFilled = true
        return copy
    }

    /// Sets the corner radius for rounded corners.
    ///
    /// - Parameter radius: Radius value from 0 (square) to 8 (most rounded).
    /// - Returns: A modified box element with rounded corners.
    public func cornerRadius(_ radius: Int) -> Box {
        var copy = self
        copy.cornerRadius = min(8, max(0, radius))
        return copy
    }

    /// Renders the box in white instead of black.
    ///
    /// Useful for creating knockouts or erasing parts of other elements.
    ///
    /// - Returns: A modified box element that renders in white.
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
