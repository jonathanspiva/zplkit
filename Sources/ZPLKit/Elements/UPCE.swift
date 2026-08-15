/// A UPC-E barcode element using ZPL's ^B9 command.
/// UPC-E is the zero-suppressed (compressed) version of UPC-A for small packages.
/// Encodes 6 digits which expand to a full UPC-A when scanned.
///
/// ## Expected field data
///
/// The string passed to ``init(_:at:)`` is emitted verbatim as the `^B9` field
/// data (`^FD`).
///
/// - **6 digits** is the zero-suppressed UPC-E item code, with number system 0.
/// - **7 digits** is a *leading number system digit* followed by that 6-digit
///   code. UPC-E only defines number systems 0 and 1.
///
/// The check digit is **never** part of the field data: the printer always
/// derives it, and ``checkDigit(_:)`` only controls whether it is printed in the
/// human-readable line. Lengths other than 6 or 7 are rejected by the
/// initializer because the printer cannot encode them.
///
/// - Warning: Do not pass a check digit as a 7th *trailing* digit. It is read as
///   a *leading* number system digit and silently shifts every other digit, so
///   the symbol scans as a different product. Verified against Labelary:
///   `^FD0123456` renders pixel-identical to `^FD123456`, whereas `^FD1234565`
///   (intended as "123456" plus check digit 5) encodes number system 1 with item
///   code 234565.
public struct UPCE: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var rotation: Rotation = .normal
    private var barcodeHeight: Dimension = .dots(100)
    private var showText: Bool = true
    private var isTextAbove: Bool = false
    private var checkDigit: Bool = true
    private var moduleWidth: Int = 2  // 1-10

    /// Creates a UPC-E barcode at the given position.
    ///
    /// The data is emitted verbatim as the `^B9` field data, so its length must
    /// match what `^B9` can encode: the 6-digit zero-suppressed UPC-E code, or a
    /// leading number system digit followed by that code (7 digits). Returns
    /// `nil` for any other length or non-numeric input.
    ///
    /// A 7th digit is a *leading* number system digit, never a trailing check
    /// digit; see the type documentation.
    /// - Parameters:
    ///   - data: The 6-digit UPC-E code, or a number system digit plus that code.
    ///   - position: The position on the label.
    public init?(_ data: String, at position: Position) {
        // ^B9 encodes the 6-digit zero-suppressed code. A 7th digit is allowed
        // only as an explicit check digit. An 8-digit value cannot be passed
        // through verbatim, so it is rejected rather than silently mis-encoded.
        guard data.count == 6 || data.count == 7 else {
            return nil
        }
        guard data.allSatisfy({ $0.isASCIIDigit }) else {
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

    /// Sets the module (narrow-bar) width via `^BY`. Default is 2.
    ///
    /// - Parameter width: Module width from 1 to 10.
    public func moduleWidth(_ width: Int) -> UPCE {
        var copy = self
        copy.moduleWidth = min(10, max(1, width))
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let height = barcodeHeight.resolve(dpi: context.dpi)

        let textFlag = showText ? "Y" : "N"
        let aboveFlag = isTextAbove ? "Y" : "N"
        let checkFlag = checkDigit ? "Y" : "N"

        var result = "^FO\(pos.x),\(pos.y)"
        result += "^BY\(moduleWidth)"
        result += "^B9\(rotation.rawValue),\(height),\(textFlag),\(aboveFlag),\(checkFlag)"
        result += "^FD\(data)^FS"

        return result
    }
}
