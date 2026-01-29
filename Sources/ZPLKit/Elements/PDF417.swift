/// A PDF417 barcode element using ZPL's ^B7 command.
/// PDF417 is a 2D stacked barcode commonly used on shipping labels, ID cards, and official documents.
public struct PDF417: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var rotation: Rotation = .normal
    private var barcodeHeight: Dimension = .dots(10)  // Height of each row
    private var securityLevel: Int = 0  // 0-8, 0 = auto
    private var dataColumns: Int = 0     // 0 = auto, 1-30
    private var rows: Int = 0            // 0 = auto, 3-90
    private var truncate: Bool = false   // Truncated PDF417

    /// Creates a PDF417 barcode at the given position.
    /// - Parameters:
    ///   - data: The data to encode. PDF417 supports ASCII text and binary data.
    ///   - position: The position on the label.
    public init(_ data: String, at position: Position) {
        self.data = data
        self.position = position
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> PDF417 {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Sets the height of each row (default 10 dots).
    public func rowHeight(_ height: Dimension) -> PDF417 {
        var copy = self
        copy.barcodeHeight = height
        return copy
    }

    /// Sets the security/error correction level (0-8, 0 = auto).
    /// Higher values increase error correction but also barcode size.
    public func securityLevel(_ level: Int) -> PDF417 {
        var copy = self
        copy.securityLevel = min(8, max(0, level))
        return copy
    }

    /// Sets the number of data columns (1-30, 0 = auto).
    public func columns(_ cols: Int) -> PDF417 {
        var copy = self
        copy.dataColumns = min(30, max(0, cols))
        return copy
    }

    /// Sets the number of rows (3-90, 0 = auto).
    public func rows(_ rowCount: Int) -> PDF417 {
        var copy = self
        copy.rows = min(90, max(0, rowCount))
        return copy
    }

    /// Uses truncated PDF417 format (smaller, reduced error correction).
    public func truncated() -> PDF417 {
        var copy = self
        copy.truncate = true
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let height = barcodeHeight.resolve(dpi: context.dpi)

        let truncateFlag = truncate ? "Y" : "N"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^B7\(rotation.rawValue),\(height),\(securityLevel),\(dataColumns),\(rows),\(truncateFlag)"
        result += "^FD\(data)^FS"

        return result
    }
}
