/// A single-line text element.
///
/// Use `Text` to display text on a label. Text supports fonts, rotation,
/// and reverse printing (white on black).
///
/// ## Basic Usage
///
/// ```swift
/// let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
///     Text("Hello World", at: .inches(0.25, 0.25))
/// }
/// ```
///
/// ## Styling
///
/// Chain modifiers to customize appearance:
///
/// ```swift
/// Text("FRAGILE", at: .inches(0.5, 0.5))
///     .font(.default, height: .inches(0.3))
///     .rotated(.rotated90)
///     .reversed()
/// ```
///
/// ## Positioning
///
/// By default, the position specifies the top-left corner of the text.
/// Use ``baseline()`` for baseline positioning, where the y coordinate
/// specifies where the text sits rather than the top of the bounding box.
///
/// - Note: For multi-line text with word wrapping, use ``TextBlock`` instead.
public struct Text: ZPLElement, Equatable, Hashable {
    private let text: String
    private let position: Position
    private var font: ZPLFont = .default
    private var fontHeight: Dimension = .dots(30)
    private var fontWidth: Dimension?
    private var rotation: Rotation = .normal
    private var isReversed: Bool = false
    private var useBaselinePosition: Bool = false

    /// Creates a text element at the given position.
    ///
    /// - Parameters:
    ///   - text: The text to display.
    ///   - position: The position on the label (top-left corner of text).
    public init(_ text: String, at position: Position) {
        self.text = text
        self.position = position
    }

    /// Sets the font and size.
    ///
    /// - Parameters:
    ///   - font: The font to use.
    ///   - height: The font height.
    ///   - width: The font width. Defaults to the same as height if not specified.
    /// - Returns: A modified text element.
    public func font(_ font: ZPLFont, height: Dimension, width: Dimension? = nil) -> Text {
        var copy = self
        copy.font = font
        copy.fontHeight = height
        copy.fontWidth = width
        return copy
    }

    /// Renders the text with reversed colors (white on black).
    ///
    /// - Returns: A modified text element with reverse printing enabled.
    public func reversed() -> Text {
        var copy = self
        copy.isReversed = true
        return copy
    }

    /// Rotates the text.
    ///
    /// - Parameter rotation: The rotation angle.
    /// - Returns: A modified text element with the specified rotation.
    public func rotated(_ rotation: Rotation) -> Text {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Uses baseline positioning instead of top-left positioning.
    ///
    /// With baseline positioning, the y coordinate specifies where the
    /// text baseline sits, rather than the top of the text bounding box.
    /// This is useful for aligning text with other elements.
    ///
    /// - Returns: A modified text element using baseline positioning.
    public func baseline() -> Text {
        var copy = self
        copy.useBaselinePosition = true
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let height = fontHeight.resolve(dpi: context.dpi)
        let width = fontWidth?.resolve(dpi: context.dpi) ?? height

        let (needsHex, escapedText) = escapeZPLFieldData(text)

        // Use ^FT for baseline positioning, ^FO for top-left positioning
        let positionCommand = useBaselinePosition ? "^FT" : "^FO"
        var result = "\(positionCommand)\(pos.x),\(pos.y)"

        if isReversed {
            result += "^FR"
        }

        result += "^A\(font.rawValue)\(rotation.rawValue),\(height),\(width)"

        if needsHex {
            result += "^FH"
        }

        result += "^FD\(escapedText)^FS"

        return result
    }
}
