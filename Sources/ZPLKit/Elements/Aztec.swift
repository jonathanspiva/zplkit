/// An Aztec barcode element using ZPL's ^B0 (B-zero) command.
/// Aztec is a 2D barcode commonly used on tickets, boarding passes, and ID cards.
/// It can encode any data and has built-in error correction.
public struct Aztec: ZPLElement {
    private let data: String
    private let position: Position
    private var rotation: Rotation = .normal
    private var magnification: Int = 3          // 1-10
    private var extendedChannel: Bool = false   // Extended channel interpretation
    private var errorCorrection: Int = 0        // 0 = default, 1-99 = percentage + 1
    private var menuSymbol: Bool = false        // Reader initialization symbol
    private var symbolCount: Int = 1            // Number of symbols for structured append
    private var idField: String? = nil          // Optional ID for structured append

    /// Creates an Aztec barcode at the given position.
    /// - Parameters:
    ///   - data: The data to encode. Aztec can encode any data.
    ///   - position: The position on the label.
    public init(_ data: String, at position: Position) {
        self.data = data
        self.position = position
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> Aztec {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Sets the magnification factor (1-10, default 3).
    public func magnification(_ mag: Int) -> Aztec {
        var copy = self
        copy.magnification = min(10, max(1, mag))
        return copy
    }

    /// Enables extended channel interpretation for special character encoding.
    public func extendedChannel(_ enabled: Bool) -> Aztec {
        var copy = self
        copy.extendedChannel = enabled
        return copy
    }

    /// Sets the error correction level (0 = default, 1-99 = percentage + 1).
    /// Higher values increase error correction but also barcode size.
    public func errorCorrection(_ level: Int) -> Aztec {
        var copy = self
        copy.errorCorrection = min(99, max(0, level))
        return copy
    }

    /// Creates a menu/reader initialization symbol.
    public func menuSymbol(_ enabled: Bool) -> Aztec {
        var copy = self
        copy.menuSymbol = enabled
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)

        let eciFlag = extendedChannel ? "Y" : "N"
        let menuFlag = menuSymbol ? "Y" : "N"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^B0\(rotation.rawValue),\(magnification),\(eciFlag),\(errorCorrection),\(menuFlag),\(symbolCount)"
        result += "^FD\(data)^FS"

        return result
    }
}
