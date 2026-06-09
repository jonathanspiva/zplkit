/// A UPC-E barcode element using ZPL's ^B9 command.
/// UPC-E is the zero-suppressed (compressed) version of UPC-A for small packages.
/// Encodes 6 digits which expand to a full UPC-A when scanned.
///
/// ## Expected field data
///
/// The string passed to ``init(_:at:)`` is emitted verbatim as the `^B9` field
/// data (`^FD`). Per the ZPL `^B9` specification the field data must be the
/// 6-digit zero-suppressed UPC-E code. The printer appends the check digit when
/// the check-digit flag is `Y` (see ``checkDigit(_:)``), so a 7th digit may be
/// supplied as an explicit check digit; in that case set `checkDigit(false)` so
/// the printer does not append a second one. Lengths other than 6 or 7 are
/// rejected by the initializer because the printer cannot encode them.
public struct UPCE: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var rotation: Rotation = .normal
    private var barcodeHeight: Dimension = .dots(100)
    private var showText: Bool = true
    private var isTextAbove: Bool = false
    private var checkDigit: Bool = true

    /// Creates a UPC-E barcode at the given position.
    ///
    /// The data is emitted verbatim as the `^B9` field data, so its length must
    /// match what `^B9` can encode: the 6-digit zero-suppressed UPC-E code, or 7
    /// digits when supplying an explicit check digit (in which case set
    /// `checkDigit(false)`). Returns `nil` for any other length or non-numeric
    /// input.
    /// - Parameters:
    ///   - data: The 6-digit UPC-E code, or 7 digits with an explicit check digit.
    ///   - position: The position on the label.
    public init?(_ data: String, at position: Position) {
        // ^B9 encodes the 6-digit zero-suppressed code. A 7th digit is allowed
        // only as an explicit check digit. An 8-digit value cannot be passed
        // through verbatim, so it is rejected rather than silently mis-encoded.
        guard data.count == 6 || data.count == 7 else {
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
