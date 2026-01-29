/// A UPC-E barcode element using ZPL's ^B9 command.
/// UPC-E is the zero-suppressed (compressed) version of UPC-A for small packages.
/// Encodes 6 digits which expand to a full UPC-A when scanned.
public struct UPCE: ZPLElement {
    private let data: String
    private let position: Position
    private var rotation: Rotation = .normal
    private var barcodeHeight: Dimension = .dots(100)
    private var showText: Bool = true
    private var isTextAbove: Bool = false
    private var checkDigit: Bool = true

    /// Creates a UPC-E barcode at the given position.
    /// Returns nil if the data is not 6, 7, or 8 digits.
    /// - Parameters:
    ///   - data: The numeric data to encode (6 digits, or 7-8 with system/check digits).
    ///   - position: The position on the label.
    public init?(_ data: String, at position: Position) {
        // Validate: UPC-E requires 6, 7, or 8 digits
        // 6 digits = data only
        // 7 digits = number system + data
        // 8 digits = number system + data + check
        guard data.count >= 6 && data.count <= 8 else {
            return nil
        }
        guard data.allSatisfy({ $0.isNumber }) else {
            return nil
        }
        self.data = data
        self.position = position
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> UPCE {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Sets the barcode height.
    public func height(_ height: Dimension) -> UPCE {
        var copy = self
        copy.barcodeHeight = height
        return copy
    }

    /// Shows or hides the human-readable text.
    public func showText(_ show: Bool) -> UPCE {
        var copy = self
        copy.showText = show
        return copy
    }

    /// Positions the text above the barcode instead of below.
    public func textAbove() -> UPCE {
        var copy = self
        copy.isTextAbove = true
        return copy
    }

    /// Includes or excludes the check digit in output.
    public func checkDigit(_ include: Bool) -> UPCE {
        var copy = self
        copy.checkDigit = include
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let height = barcodeHeight.resolve(dpi: context.dpi)

        let textFlag = showText ? "Y" : "N"
        let aboveFlag = isTextAbove ? "Y" : "N"
        let checkFlag = checkDigit ? "Y" : "N"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^B9\(rotation.rawValue),\(height),\(textFlag),\(aboveFlag),\(checkFlag)"
        result += "^FD\(data)^FS"

        return result
    }
}
