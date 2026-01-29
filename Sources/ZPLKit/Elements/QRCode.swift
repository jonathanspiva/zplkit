/// QR code error correction levels.
public enum QRErrorCorrection: String, Sendable {
    case ultraHigh = "H"  // 30% recovery
    case high = "Q"       // 25% recovery
    case medium = "M"     // 15% recovery (default)
    case low = "L"        // 7% recovery
}

/// A QR code element.
public struct QRCode: ZPLElement {
    private let data: String
    private let position: Position
    private var magnification: Int = 3  // 1-10
    private var errorCorrection: QRErrorCorrection = .medium

    /// Creates a QR code at the given position.
    /// - Parameters:
    ///   - data: The data to encode.
    ///   - position: The position on the label.
    public init(_ data: String, at position: Position) {
        self.data = data
        self.position = position
    }

    /// Sets the magnification (1-10, default 3).
    public func magnification(_ mag: Int) -> QRCode {
        var copy = self
        copy.magnification = min(10, max(1, mag))
        return copy
    }

    /// Sets the error correction level.
    public func errorCorrection(_ level: QRErrorCorrection) -> QRCode {
        var copy = self
        copy.errorCorrection = level
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)

        var result = "^FO\(pos.x),\(pos.y)"
        // ^BQ: orientation, model (2=enhanced), magnification
        result += "^BQN,2,\(magnification),\(errorCorrection.rawValue)"
        // QR data must be prefixed with error correction and "A," for automatic encoding
        result += "^FD\(errorCorrection.rawValue)A,\(data)^FS"

        return result
    }
}
