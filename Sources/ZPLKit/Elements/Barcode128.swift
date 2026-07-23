/// A Code 128 barcode element.
///
/// Code 128 is a high-density barcode supporting all 128 ASCII characters.
/// It's widely used for shipping labels, inventory, and general-purpose barcoding.
///
/// ## Basic Usage
///
/// ```swift
/// if let barcode = Barcode128("ABC-123", at: .inches(0.25, 0.5)) {
///     // Use barcode in label
/// }
/// ```
///
/// ## Styling
///
/// ```swift
/// Barcode128("SHIP-001", at: .inches(0.25, 0.5))?
///     .height(.inches(0.5))
///     .moduleWidth(3)
///     .showText(true)
/// ```
///
/// ## Failable Initializer
///
/// The initializer returns `nil` if the data contains non-ASCII characters.
/// Code 128 only supports ASCII values 0-127.
///
/// ```swift
/// // Returns nil - emoji not supported
/// let invalid = Barcode128("Hello 👋", at: .inches(0.25, 0.5))
/// ```
public struct Barcode128: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var barcodeHeight: Dimension = .dots(100)
    private var showText: Bool = true
    private var isTextAbove: Bool = false
    private var rotation: Rotation = .normal
    private var moduleWidth: Int = 2  // 1-10

    /// Creates a Code 128 barcode at the given position.
    ///
    /// - Parameters:
    ///   - data: The data to encode. Must contain only ASCII characters (0-127).
    ///   - position: The position on the label.
    /// - Returns: A barcode element, or `nil` if data contains invalid characters.
    public init?(_ data: String, at position: Position) {
        // Validate: Code 128 supports ASCII 0-127
        guard data.allSatisfy({ $0.isASCII }) else {
            return nil
        }
        self.data = data
        self.position = position
    }

    /// Sets the barcode height.
    ///
    /// - Parameter height: The height of the barcode bars.
    /// - Returns: A modified barcode element.
    public func height(_ height: Dimension) -> Barcode128 {
        var copy = self
        copy.barcodeHeight = height
        return copy
    }

    /// Shows or hides the human-readable text below the barcode.
    ///
    /// - Parameter show: Whether to show the text. Default is `true`.
    /// - Returns: A modified barcode element.
    public func showText(_ show: Bool) -> Barcode128 {
        var copy = self
        copy.showText = show
        return copy
    }

    /// Positions the human-readable text above the barcode instead of below.
    ///
    /// - Returns: A modified barcode element with text above.
    public func textAbove() -> Barcode128 {
        var copy = self
        copy.isTextAbove = true
        return copy
    }

    /// Rotates the barcode.
    ///
    /// - Parameter rotation: The rotation angle.
    /// - Returns: A modified barcode element with the specified rotation.
    public func rotated(_ rotation: Rotation) -> Barcode128 {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Sets the module (bar) width.
    ///
    /// Larger values produce wider barcodes that are easier to scan
    /// but take more space.
    ///
    /// - Parameter width: Module width from 1 to 10. Default is 2.
    /// - Returns: A modified barcode element.
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

        // Code 128 treats `>` in `^BC` field data as an invocation-code prefix:
        // `>9`/`>:`/`>;` switch subsets, `>1`-`>8`/`><`/`>=` are function codes,
        // and `>0` is the escape for a literal `>`. Left raw, caller data like
        // "PRICE>5" would silently encode a subset/function switch instead of the
        // intended `>`, corrupting the printed symbol. Emit `>0` for every literal
        // `>` so the payload round-trips verbatim. Runs before hex escaping, which
        // never touches `>` or digits, so the two transforms don't interfere.
        let invocationSafe = data.replacingOccurrences(of: ">", with: ">0")
        let (needsHex, escapedData) = escapeZPLFieldData(invocationSafe)

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^BY\(moduleWidth)"
        result += "^BC\(rotation.rawValue),\(height),\(textFlag),\(aboveFlag),N"
        if needsHex {
            result += "^FH"
        }
        result += "^FD\(escapedData)^FS"

        return result
    }
}
