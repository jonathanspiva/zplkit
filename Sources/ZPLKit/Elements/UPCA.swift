/// A UPC-A barcode element using ZPL's ^BU command.
/// UPC-A is the Universal Product Code used primarily in North America.
/// Encodes exactly 11 digits (12th is check digit, auto-calculated).
public struct UPCA: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var rotation: Rotation = .normal
    private var barcodeHeight: Dimension = .dots(100)
    private var showText: Bool = true
    private var isTextAbove: Bool = false
    private var checkDigit: Bool = true

    /// Creates a UPC-A barcode at the given position.
    /// Returns nil if the data is not exactly 11 or 12 digits.
    /// - Parameters:
    ///   - data: The numeric data to encode (11 digits, or 12 with check digit).
    ///   - position: The position on the label.
    public init?(_ data: String, at position: Position) {
        // Validate: UPC-A requires exactly 11 or 12 digits
        guard data.count == 11 || data.count == 12 else {
            return nil
        }
        guard data.allSatisfy({ $0.isASCIIDigit }) else {
            return nil
        }
        self.data = data
        self.position = position
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> UPCA {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Sets the barcode height.
    public func height(_ height: Dimension) -> UPCA {
        var copy = self
        copy.barcodeHeight = height
        return copy
    }

    /// Shows or hides the human-readable text.
    public func showText(_ show: Bool) -> UPCA {
        var copy = self
        copy.showText = show
        return copy
    }

    /// Positions the text above the barcode instead of below.
    public func textAbove() -> UPCA {
        var copy = self
        copy.isTextAbove = true
        return copy
    }

    /// Includes or excludes the check digit in output.
    public func checkDigit(_ include: Bool) -> UPCA {
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
        result += "^BU\(rotation.rawValue),\(height),\(textFlag),\(aboveFlag),\(checkFlag)"
        result += "^FD\(data)^FS"

        return result
    }
}
