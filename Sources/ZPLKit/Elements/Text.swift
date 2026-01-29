/// A text field element.
public struct Text: ZPLElement {
    private let text: String
    private let position: Position
    private var font: ZPLFont = .default
    private var fontHeight: Dimension = .dots(30)
    private var fontWidth: Dimension?
    private var rotation: Rotation = .normal
    private var isReversed: Bool = false
    private var useBaselinePosition: Bool = false

    /// Creates a text element at the given position.
    /// - Parameters:
    ///   - text: The text to display.
    ///   - position: The position on the label.
    public init(_ text: String, at position: Position) {
        self.text = text
        self.position = position
    }

    /// Sets the font and size.
    /// - Parameters:
    ///   - font: The font to use.
    ///   - height: The font height.
    ///   - width: The font width (defaults to height if not specified).
    public func font(_ font: ZPLFont, height: Dimension, width: Dimension? = nil) -> Text {
        var copy = self
        copy.font = font
        copy.fontHeight = height
        copy.fontWidth = width
        return copy
    }

    /// Renders the text with reversed colors (white on black).
    public func reversed() -> Text {
        var copy = self
        copy.isReversed = true
        return copy
    }

    /// Rotates the text.
    public func rotated(_ rotation: Rotation) -> Text {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Uses baseline positioning (^FT) instead of top-left positioning (^FO).
    /// With baseline positioning, the y coordinate specifies the text baseline
    /// rather than the top of the text bounding box.
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
