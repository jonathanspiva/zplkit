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
    private var moduleWidth: Int = 2  // 1-10

    /// Creates an EAN-13 barcode at the given position.
    /// Returns nil if the data is not exactly 12 or 13 digits, or if a 13-digit
    /// value carries a check digit that doesn't match the first 12.
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
        // If the caller supplied the full 13 digits, the 13th must be the correct
        // check digit; otherwise the printer would silently re-derive a different
        // one from the first 12 and encode a symbol that doesn't match the input.
        if data.count == 13, !hasValidGTINCheckDigit(data) {
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

    /// Sets the module (narrow-bar) width via `^BY`. Default is 2.
    ///
    /// - Parameter width: Module width from 1 to 10.
    public func moduleWidth(_ width: Int) -> EAN13 {
        var copy = self
        copy.moduleWidth = min(10, max(1, width))
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let height = barcodeHeight.resolve(dpi: context.dpi)

        let textFlag = showText ? "Y" : "N"
        let aboveFlag = isTextAbove ? "Y" : "N"

        var result = "^FO\(pos.x),\(pos.y)"
        // Emit ^BY so a preceding barcode's module width can't leak in (^BY is
        // sticky within a format).
        result += "^BY\(moduleWidth)"
        result += "^BE\(rotation.rawValue),\(height),\(textFlag),\(aboveFlag)"
        result += "^FD\(data)^FS"

        return result
    }
}
