/// A DataMatrix barcode element.
public struct DataMatrix: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var moduleSize: Int = 3      // 1-10
    private var quality: Int = 200       // 0, 50, 80, 100, 140, 200
    private var columns: Int?
    private var rows: Int?
    private var rotation: Rotation = .normal

    /// Creates a DataMatrix barcode at the given position.
    /// - Parameters:
    ///   - data: The data to encode.
    ///   - position: The position on the label.
    public init(_ data: String, at position: Position) {
        self.data = data
        self.position = position
    }

    /// Sets the module size (1-10, default 3).
    public func size(_ size: Int) -> DataMatrix {
        var copy = self
        copy.moduleSize = min(10, max(1, size))
        return copy
    }

    /// Sets the quality level (0, 50, 80, 100, 140, 200; default 200).
    public func quality(_ level: Int) -> DataMatrix {
        var copy = self
        // Clamp to valid values
        let validLevels = [0, 50, 80, 100, 140, 200]
        copy.quality = validLevels.min(by: { abs($0 - level) < abs($1 - level) }) ?? 200
        return copy
    }

    /// Sets a fixed number of columns.
    public func columns(_ cols: Int) -> DataMatrix {
        var copy = self
        copy.columns = cols
        return copy
    }

    /// Sets a fixed number of rows.
    public func rows(_ rows: Int) -> DataMatrix {
        var copy = self
        copy.rows = rows
        return copy
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> DataMatrix {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)

        var result = "^FO\(pos.x),\(pos.y)"

        // ^BX: orientation, height, quality, columns, rows
        let colStr = columns.map { ",\($0)" } ?? ""
        let rowStr = rows.map { ",\($0)" } ?? ""
        result += "^BX\(rotation.rawValue),\(moduleSize),\(quality)\(colStr)\(rowStr)"
        result += "^FD\(data)^FS"

        return result
    }
}
