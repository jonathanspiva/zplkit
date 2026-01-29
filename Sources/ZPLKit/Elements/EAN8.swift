/// An EAN-8 barcode element using ZPL's ^B8 command.
/// EAN-8 is the compact European Article Number for small packages.
/// Encodes exactly 7 digits (8th is check digit, auto-calculated).
public struct EAN8: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var rotation: Rotation = .normal
    private var barcodeHeight: Dimension = .dots(100)
    private var showText: Bool = true
    private var isTextAbove: Bool = false

    /// Creates an EAN-8 barcode at the given position.
    /// Returns nil if the data is not exactly 7 or 8 digits.
    /// - Parameters:
    ///   - data: The numeric data to encode (7 digits, or 8 with check digit).
    ///   - position: The position on the label.
    public init?(_ data: String, at position: Position) {
        // Validate: EAN-8 requires exactly 7 or 8 digits
        guard data.count == 7 || data.count == 8 else {
            return nil
        }
        guard data.allSatisfy({ $0.isNumber }) else {
            return nil
        }
        self.data = data
        self.position = position
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> EAN8 {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Sets the barcode height.
    public func height(_ height: Dimension) -> EAN8 {
        var copy = self
        copy.barcodeHeight = height
        return copy
    }

    /// Shows or hides the human-readable text.
    public func showText(_ show: Bool) -> EAN8 {
        var copy = self
        copy.showText = show
        return copy
    }

    /// Positions the text above the barcode instead of below.
    public func textAbove() -> EAN8 {
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
        result += "^B8\(rotation.rawValue),\(height),\(textFlag),\(aboveFlag)"
        result += "^FD\(data)^FS"

        return result
    }
}
