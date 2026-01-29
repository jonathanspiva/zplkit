/// A Code 39 barcode element.
public struct Code39: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var barcodeHeight: Dimension = .dots(100)
    private var showText: Bool = true
    private var checkDigit: Bool = false
    private var rotation: Rotation = .normal

    /// Valid characters for Code 39.
    private static let validCharacters = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -.$/+%")

    /// Creates a Code 39 barcode at the given position.
    /// Returns nil if the data contains invalid characters.
    /// Valid characters: A-Z, 0-9, space, - . $ / + %
    /// - Parameters:
    ///   - data: The data to encode (will be uppercased).
    ///   - position: The position on the label.
    public init?(_ data: String, at position: Position) {
        let uppercased = data.uppercased()
        guard uppercased.allSatisfy({ Code39.validCharacters.contains($0) }) else {
            return nil
        }
        self.data = uppercased
        self.position = position
    }

    /// Sets the barcode height.
    public func height(_ height: Dimension) -> Code39 {
        var copy = self
        copy.barcodeHeight = height
        return copy
    }

    /// Shows or hides the human-readable text.
    public func showText(_ show: Bool) -> Code39 {
        var copy = self
        copy.showText = show
        return copy
    }

    /// Includes a check digit in the barcode.
    public func checkDigit(_ include: Bool) -> Code39 {
        var copy = self
        copy.checkDigit = include
        return copy
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> Code39 {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let height = barcodeHeight.resolve(dpi: context.dpi)

        let checkFlag = checkDigit ? "Y" : "N"
        let textFlag = showText ? "Y" : "N"

        var result = "^FO\(pos.x),\(pos.y)"
        // ^B3: orientation, check digit, height, print text, print text above
        result += "^B3\(rotation.rawValue),\(checkFlag),\(height),\(textFlag),N"
        result += "^FD\(data)^FS"

        return result
    }
}
