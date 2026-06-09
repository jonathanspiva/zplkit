/// A serial number field element using ZPL's ^SN command.
/// Automatically increments or decrements a numeric or alphanumeric value
/// across multiple labels in a print job.
public struct SerialNumber: ZPLElement, Equatable, Hashable {
    private let startValue: String
    private let position: Position
    private var increment: Int = 1
    private var leadingZeros: Bool = true
    private var fontHeight: Dimension = .dots(30)
    private var fontWidth: Dimension? = nil
    private var font: ZPLFont = .default
    private var rotation: Rotation = .normal

    /// Creates a serial number field at the given position.
    ///
    /// The start value is sanitized to prevent ZPL injection: commas are
    /// stripped because they are the `^SN` parameter delimiter and are illegal
    /// in a serial seed (they cannot be hex-escaped within `^SN`'s parameters).
    /// Caret (`^`), tilde (`~`), and underscore (`_`) characters are preserved
    /// but emitted via `^FH` hex escaping at render time so they are treated as
    /// literal data rather than live ZPL commands.
    /// - Parameters:
    ///   - startValue: The starting value for the serial number.
    ///   - position: The position on the label.
    public init(_ startValue: String, at position: Position) {
        // Commas are the ^SN parameter separator and cannot appear in the seed;
        // strip them so a value like "1,2" cannot corrupt the ^SN parameters.
        self.startValue = startValue.replacingOccurrences(of: ",", with: "")
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

        // Escape control characters (^ ~ _) in the seed so they cannot break out
        // of the ^SN command. ^FH (permitted by the ZPL manual alongside ^SN)
        // tells the printer to interpret the _XX escapes as literal data.
        let (needsHex, escapedStart) = escapeZPLFieldData(startValue)

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^A\(font.rawValue)\(rotation.rawValue),\(height),\(width)"
        if needsHex {
            result += "^FH"
        }
        result += "^SN\(escapedStart),\(increment),\(leadingZerosFlag)"
        result += "^FS"

        return result
    }
}
