/// A serial number field element using ZPL's ^SN command.
/// Automatically increments or decrements a numeric or alphanumeric value
/// across multiple labels in a print job.
public struct SerialNumber: ZPLElement {
    private let startValue: String
    private let position: Position
    private var increment: Int = 1
    private var leadingZeros: Bool = true
    private var fontHeight: Dimension = .dots(30)
    private var fontWidth: Dimension? = nil
    private var font: ZPLFont = .default
    private var rotation: Rotation = .normal

    /// Creates a serial number field at the given position.
    /// - Parameters:
    ///   - startValue: The starting value for the serial number.
    ///   - position: The position on the label.
    public init(_ startValue: String, at position: Position) {
        self.startValue = startValue
        self.position = position
    }

    /// Sets the increment value (positive to count up, negative to count down).
    public func increment(_ value: Int) -> SerialNumber {
        var copy = self
        copy.increment = value
        return copy
    }

    /// Controls whether leading zeros are preserved during incrementing.
    public func leadingZeros(_ preserve: Bool) -> SerialNumber {
        var copy = self
        copy.leadingZeros = preserve
        return copy
    }

    /// Sets the font and size for the serial number text.
    public func font(_ font: ZPLFont, height: Dimension, width: Dimension? = nil) -> SerialNumber {
        var copy = self
        copy.font = font
        copy.fontHeight = height
        copy.fontWidth = width
        return copy
    }

    /// Rotates the text.
    public func rotated(_ rotation: Rotation) -> SerialNumber {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let height = fontHeight.resolve(dpi: context.dpi)
        let width = fontWidth?.resolve(dpi: context.dpi) ?? height

        let leadingZerosFlag = leadingZeros ? "Y" : "N"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^A\(font.rawValue)\(rotation.rawValue),\(height),\(width)"
        result += "^SN\(startValue),\(increment),\(leadingZerosFlag)"
        result += "^FS"

        return result
    }
}
