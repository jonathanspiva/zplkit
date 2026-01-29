/// Text alignment options for text blocks.
public enum TextAlignment: String, Sendable {
    case left = "L"
    case center = "C"
    case right = "R"
    case justified = "J"
}

/// A text block element with word wrapping support.
public struct TextBlock: ZPLElement {
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

    /// Creates a text block at the given position with the specified width.
    /// - Parameters:
    ///   - text: The text to display.
    ///   - position: The position on the label.
    ///   - width: The maximum width of the text block.
    public init(_ text: String, at position: Position, width: Dimension) {
        self.text = text
        self.position = position
        self.blockWidth = width
    }

    /// Sets the font and size.
    public func font(_ font: ZPLFont, height: Dimension, width: Dimension? = nil) -> TextBlock {
        var copy = self
        copy.font = font
        copy.fontHeight = height
        copy.fontWidth = width
        return copy
    }

    /// Sets the maximum number of lines (0 = unlimited).
    public func maxLines(_ lines: Int) -> TextBlock {
        var copy = self
        copy.maxLines = max(0, lines)
        return copy
    }

    /// Sets the spacing between lines.
    public func lineSpacing(_ spacing: Dimension) -> TextBlock {
        var copy = self
        copy.lineSpacing = spacing
        return copy
    }

    /// Sets the text alignment.
    public func alignment(_ alignment: TextAlignment) -> TextBlock {
        var copy = self
        copy.alignment = alignment
        return copy
    }

    /// Sets the hanging indent for wrapped lines.
    public func hangingIndent(_ indent: Dimension) -> TextBlock {
        var copy = self
        copy.hangingIndent = indent
        return copy
    }

    /// Uses baseline positioning (^FT) instead of top-left positioning (^FO).
    public func baseline() -> TextBlock {
        var copy = self
        copy.useBaselinePosition = true
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let width = blockWidth.resolve(dpi: context.dpi)
        let height = fontHeight.resolve(dpi: context.dpi)
        let fontW = fontWidth?.resolve(dpi: context.dpi) ?? height
        let spacing = lineSpacing.resolve(dpi: context.dpi)
        let indent = hangingIndent.resolve(dpi: context.dpi)

        let (needsHex, escapedText) = escapeZPLFieldData(text)

        let positionCommand = useBaselinePosition ? "^FT" : "^FO"
        var result = "\(positionCommand)\(pos.x),\(pos.y)"
        result += "^A\(font.rawValue)N,\(height),\(fontW)"

        // ^FB command: width, max lines, line spacing, alignment, hanging indent
        result += "^FB\(width),\(maxLines),\(spacing),\(alignment.rawValue),\(indent)"

        if needsHex {
            result += "^FH"
        }

        result += "^FD\(escapedText)^FS"

        return result
    }
}
