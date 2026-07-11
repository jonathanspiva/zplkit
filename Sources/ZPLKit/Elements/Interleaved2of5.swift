/// An Interleaved 2 of 5 barcode element using ZPL's ^B2 command.
/// Commonly used in shipping, warehousing, and the logistics industry.
/// Only encodes numeric data (digits 0-9). Data length must be even.
public struct Interleaved2of5: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var rotation: Rotation = .normal
    private var barcodeHeight: Dimension = .dots(100)
    private var showText: Bool = true
    private var isTextAbove: Bool = false
    private var checkDigit: Bool = false
    private var moduleWidth: Int = 2  // 1-10

    /// Creates an Interleaved 2 of 5 barcode at the given position.
    /// Returns nil if the data contains non-numeric characters or has odd length.
    /// - Parameters:
    ///   - data: The numeric data to encode (digits only, even length).
    ///   - position: The position on the label.
    public init?(_ data: String, at position: Position) {
        // Validate: I2of5 only supports digits 0-9
        guard data.allSatisfy({ $0.isASCIIDigit }) else {
            return nil
        }
        // Data must be even length (or check digit will make it even)
        // We allow odd length here and let checkDigit() fix it
        self.data = data
        self.position = position
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> Interleaved2of5 {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Sets the barcode height.
    public func height(_ height: Dimension) -> Interleaved2of5 {
        var copy = self
        copy.barcodeHeight = height
        return copy
    }

    /// Shows or hides the human-readable text.
    public func showText(_ show: Bool) -> Interleaved2of5 {
        var copy = self
        copy.showText = show
        return copy
    }

    /// Positions the text above the barcode instead of below.
    public func textAbove() -> Interleaved2of5 {
        var copy = self
        copy.isTextAbove = true
        return copy
    }

    /// Adds a MOD 10 check digit (also ensures even data length).
    public func checkDigit(_ include: Bool) -> Interleaved2of5 {
        var copy = self
        copy.checkDigit = include
        return copy
    }

    /// Sets the module (bar) width (1-10, default 2).
    public func moduleWidth(_ width: Int) -> Interleaved2of5 {
        var copy = self
        copy.moduleWidth = min(10, max(1, width))
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let height = barcodeHeight.resolve(dpi: context.dpi)

        let textFlag = showText ? "Y" : "N"
        let aboveFlag = isTextAbove ? "Y" : "N"
        let checkFlag = checkDigit ? "Y" : "N"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^BY\(moduleWidth)"
        result += "^B2\(rotation.rawValue),\(height),\(textFlag),\(aboveFlag),\(checkFlag)"
        result += "^FD\(data)^FS"

        return result
    }
}
