/// A Code 128 barcode element.
public struct Barcode128: ZPLElement {
    private let data: String
    private let position: Position
    private var barcodeHeight: Dimension = .dots(100)
    private var showText: Bool = true
    private var isTextAbove: Bool = false
    private var rotation: Rotation = .normal
    private var moduleWidth: Int = 2  // 1-10

    /// Creates a Code 128 barcode at the given position.
    /// Returns nil if the data contains invalid characters (non-ASCII).
    /// - Parameters:
    ///   - data: The data to encode.
    ///   - position: The position on the label.
    public init?(_ data: String, at position: Position) {
        // Validate: Code 128 supports ASCII 0-127
        guard data.allSatisfy({ $0.asciiValue != nil && $0.asciiValue! < 128 }) else {
            return nil
        }
        self.data = data
        self.position = position
    }

    /// Sets the barcode height.
    public func height(_ height: Dimension) -> Barcode128 {
        var copy = self
        copy.barcodeHeight = height
        return copy
    }

    /// Shows or hides the human-readable text.
    public func showText(_ show: Bool) -> Barcode128 {
        var copy = self
        copy.showText = show
        return copy
    }

    /// Positions the text above the barcode instead of below.
    public func textAbove() -> Barcode128 {
        var copy = self
        copy.isTextAbove = true
        return copy
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> Barcode128 {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Sets the module (bar) width (1-10, default 2).
    public func moduleWidth(_ width: Int) -> Barcode128 {
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
        result += "^BY\(moduleWidth)"
        result += "^BC\(rotation.rawValue),\(height),\(textFlag),\(aboveFlag),N"
        result += "^FD\(data)^FS"

        return result
    }
}
