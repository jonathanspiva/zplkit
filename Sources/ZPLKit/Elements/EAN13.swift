/// An EAN-13 barcode element using ZPL's ^BE command.
/// EAN-13 is the European Article Number, commonly used in retail worldwide.
/// Encodes exactly 12 digits (13th is check digit, auto-calculated).
public struct EAN13: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var rotation: Rotation = .normal
    private var barcodeHeight: Dimension = .dots(100)
    private var showText: Bool = true
    private var isTextAbove: Bool = false

    /// Creates an EAN-13 barcode at the given position.
    /// Returns nil if the data is not exactly 12 or 13 digits.
    /// - Parameters:
    ///   - data: The numeric data to encode (12 digits, or 13 with check digit).
    ///   - position: The position on the label.
    public init?(_ data: String, at position: Position) {
        // Validate: EAN-13 requires exactly 12 or 13 digits
        guard data.count == 12 || data.count == 13 else {
            return nil
        }
        guard data.allSatisfy({ $0.isASCIIDigit }) else {
            return nil
        }
        self.data = data
        self.position = position
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> EAN13 {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Sets the barcode height.
    public func height(_ height: Dimension) -> EAN13 {
        var copy = self
        copy.barcodeHeight = height
        return copy
    }

    /// Shows or hides the human-readable text.
    public func showText(_ show: Bool) -> EAN13 {
        var copy = self
        copy.showText = show
        return copy
    }

    /// Positions the text above the barcode instead of below.
    public func textAbove() -> EAN13 {
        var copy = self
        copy.isTextAbove = true
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let height = barcodeHeight.resolve(dpi: context.dpi)

        let textFlag = showText ? "Y" : "N"
        let aboveFlag = isTextAbove ? "Y" : "N"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^BE\(rotation.rawValue),\(height),\(textFlag),\(aboveFlag)"
        result += "^FD\(data)^FS"

        return result
    }
}
