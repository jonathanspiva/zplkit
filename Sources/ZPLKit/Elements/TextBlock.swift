/// Text alignment options for text blocks.
@frozen
public enum TextAlignment: String, Sendable, Codable, Hashable {
    /// Left-aligned text.
    case left = "L"
    /// Center-aligned text.
    case center = "C"
    /// Right-aligned text.
    case right = "R"
    /// Justified text (aligned to both edges).
    case justified = "J"
}

/// A text block element with word wrapping and multi-line support.
///
/// Use `TextBlock` for longer text that needs to wrap within a defined width.
/// Supports alignment, line spacing, and hanging indents.
///
/// ## Basic Usage
///
/// ```swift
/// TextBlock("This is a longer piece of text that will wrap automatically.",
///           at: .inches(0.25, 0.25),
///           width: .inches(2.0))
/// ```
///
/// ## Styling
///
/// ```swift
/// TextBlock("Product description goes here...",
///           at: .inches(0.25, 0.5),
///           width: .inches(3.0))
///     .font(.default, height: .inches(0.1))
///     .maxLines(3)
///     .alignment(.justified)
///     .lineSpacing(.dots(5))
/// ```
///
/// ## Line Breaks
///
/// Use `\n` in your text for explicit line breaks:
///
/// ```swift
/// TextBlock("Line 1\nLine 2\nLine 3",
///           at: .inches(0.25, 0.25),
///           width: .inches(2.0))
/// ```
public struct TextBlock: ZPLElement, Equatable, Hashable {
    private let text: String
    private let position: Position
    private let blockWidth: Dimension
    private var font: ZPLFont = .default
    private var fontHeight: Dimension = .dots(30)
    private var fontWidth: Dimension?
    private var maxLines: Int = 0  // 0 = unlimited
    private var lineSpacing: Dimension = .dots(0)
    private var alignment: TextAlignment = .left
    private var hangingIndent: Dimension = .dots(0)
    private var useBaselinePosition: Bool = false
    private var rotation: Rotation = .normal
    private var isReversed: Bool = false

    /// Creates a text block at the given position with the specified width.
    ///
    /// - Parameters:
    ///   - text: The text to display. Use `\n` for line breaks.
    ///   - position: The position on the label.
    ///   - width: The maximum width before text wraps.
    public init(_ text: String, at position: Position, width: Dimension) {
        self.text = text
        self.position = position
        self.blockWidth = width
    }

    /// Sets the font and size.
    ///
    /// - Parameters:
    ///   - font: The font to use.
    ///   - height: The font height.
    ///   - width: The font width. Defaults to the same as height if not specified.
    /// - Returns: A modified text block.
    public func font(_ font: ZPLFont, height: Dimension, width: Dimension? = nil) -> TextBlock {
        var copy = self
        copy.font = font
        copy.fontHeight = height
        copy.fontWidth = width
        return copy
    }

    /// Sets the maximum number of lines to display.
    ///
    /// Text exceeding this limit is truncated.
    ///
    /// - Parameter lines: Maximum lines. Use 0 for unlimited.
    /// - Returns: A modified text block.
    public func maxLines(_ lines: Int) -> TextBlock {
        var copy = self
        copy.maxLines = max(0, lines)
        return copy
    }

    /// Sets the spacing between lines.
    ///
    /// - Parameter spacing: The vertical space between lines.
    /// - Returns: A modified text block.
    public func lineSpacing(_ spacing: Dimension) -> TextBlock {
        var copy = self
        copy.lineSpacing = spacing
        return copy
    }

    /// Sets the text alignment within the block.
    ///
    /// - Parameter alignment: The alignment option.
    /// - Returns: A modified text block.
    public func alignment(_ alignment: TextAlignment) -> TextBlock {
        var copy = self
        copy.alignment = alignment
        return copy
    }

    /// Sets a hanging indent for wrapped lines.
    ///
    /// The first line starts at the normal position, while subsequent
    /// wrapped lines are indented by the specified amount.
    ///
    /// - Parameter indent: The indent amount for wrapped lines.
    /// - Returns: A modified text block.
    public func hangingIndent(_ indent: Dimension) -> TextBlock {
        var copy = self
        copy.hangingIndent = indent
        return copy
    }

    /// Uses baseline positioning instead of top-left positioning.
    ///
    /// - Returns: A modified text block using baseline positioning.
    public func baseline() -> TextBlock {
        var copy = self
        copy.useBaselinePosition = true
        return copy
    }

    /// Rotates the text block.
    ///
    /// - Parameter rotation: The rotation angle.
    /// - Returns: A modified text block with the specified rotation.
    public func rotated(_ rotation: Rotation) -> TextBlock {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Enables reverse print (white text on black background).
    ///
    /// - Returns: A modified text block with reverse printing enabled.
    public func reversed() -> TextBlock {
        var copy = self
        copy.isReversed = true
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let width = blockWidth.resolve(dpi: context.dpi)
        let height = fontHeight.resolve(dpi: context.dpi)
        let fontW = fontWidth?.resolve(dpi: context.dpi) ?? height
        let spacing = lineSpacing.resolve(dpi: context.dpi)
        let indent = hangingIndent.resolve(dpi: context.dpi)

        // Convert newlines to ZPL line break sequence
        let textWithLineBreaks = text.replacingOccurrences(of: "\n", with: "\\&")
        let (needsHex, escapedText) = escapeZPLFieldData(textWithLineBreaks)

        let positionCommand = useBaselinePosition ? "^FT" : "^FO"
        var result = "\(positionCommand)\(pos.x),\(pos.y)"

        // Add reverse field command if needed
        if isReversed {
            result += "^FR"
        }

        result += "^A\(font.rawValue)\(rotation.rawValue),\(height),\(fontW)"

        // ^FB command: width, max lines, line spacing, alignment, hanging indent
        result += "^FB\(width),\(maxLines),\(spacing),\(alignment.rawValue),\(indent)"

        if needsHex {
            result += "^FH"
        }

        result += "^FD\(escapedText)^FS"

        return result
    }
}
