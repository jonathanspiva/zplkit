/// A USPS Intelligent Mail barcode element using ZPL's ^BZ command.
/// Intelligent Mail (also called OneCode or 4-State Customer Barcode) is used
/// by USPS for mail tracking and sorting.
/// Encodes 20, 25, 29, or 31 digits depending on the routing information included.
///
/// The symbol itself is encoded by the printer's `^BZ` firmware (postal type 3);
/// ZPLKit emits the `^BZ` command and the digit field. Note that the software
/// renderer (`ZPLKitRenderer`) draws an approximate placeholder for the preview,
/// not a pixel-accurate 4-state symbol — validate final output on a printer.
public struct IntelligentMail: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var rotation: Rotation = .normal
    private var barcodeHeight: Dimension = .dots(20)

    /// Creates an Intelligent Mail barcode at the given position.
    /// Returns nil if the data is not 20, 25, 29, or 31 digits.
    /// - Parameters:
    ///   - data: The numeric data to encode.
    ///     - 20 digits: Tracking code only
    ///     - 25 digits: Tracking + 5-digit ZIP
    ///     - 29 digits: Tracking + 9-digit ZIP
    ///     - 31 digits: Tracking + 11-digit delivery point
    ///   - position: The position on the label.
    public init?(_ data: String, at position: Position) {
        // Validate: Intelligent Mail requires exactly 20, 25, 29, or 31 digits
        let validLengths = [20, 25, 29, 31]
        guard validLengths.contains(data.count) else {
            return nil
        }
        guard data.allSatisfy({ $0.isASCIIDigit }) else {
            return nil
        }
        // The first two digits are the Barcode Identifier; per USPS-B-3200 its
        // second digit must be 0-4. A larger value can't be encoded, so reject it
        // rather than let the printer produce an out-of-spec symbol.
        guard let secondDigit = data.dropFirst().first, ("0"..."4").contains(secondDigit) else {
            return nil
        }
        self.data = data
        self.position = position
    }

    /// Rotates the barcode.
    public func rotated(_ rotation: Rotation) -> IntelligentMail {
        var copy = self
        copy.rotation = rotation
        return copy
    }

    /// Sets the barcode height.
    /// Note: Intelligent Mail has a fixed aspect ratio; height affects overall scale.
    public func height(_ height: Dimension) -> IntelligentMail {
        var copy = self
        copy.barcodeHeight = height
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let height = barcodeHeight.resolve(dpi: context.dpi)

        var result = "^FO\(pos.x),\(pos.y)"
        // ^BZo,h,f,g,e — the 5th parameter selects the postal symbology and
        // defaults to 0 (POSTNET); 3 is USPS Intelligent Mail. Omitting it
        // makes real printers render a POSTNET barcode instead.
        result += "^BZ\(rotation.rawValue),\(height),N,N,3"
        result += "^FD\(data)^FS"

        return result
    }
}
