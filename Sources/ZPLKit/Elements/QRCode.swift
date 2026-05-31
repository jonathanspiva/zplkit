/// QR code error correction levels.
///
/// Higher error correction allows the QR code to be read even if partially
/// damaged, but requires more space (larger QR code).
@frozen
public enum QRErrorCorrection: String, Sendable, Codable, Hashable {
    /// Ultra-high error correction (30% recovery capacity).
    case ultraHigh = "H"
    /// High error correction (25% recovery capacity).
    case high = "Q"
    /// Medium error correction (15% recovery capacity). Default.
    case medium = "M"
    /// Low error correction (7% recovery capacity).
    case low = "L"
}

/// A QR code element.
///
/// QR codes can encode URLs, text, or any data up to several thousand characters.
/// They're widely used for linking to websites, contact info, and tracking.
///
/// ## Basic Usage
///
/// ```swift
/// QRCode("https://example.com", at: .inches(0.5, 0.5))
/// ```
///
/// ## Size and Error Correction
///
/// ```swift
/// QRCode("https://example.com/product/12345", at: .inches(0.5, 0.5))
///     .magnification(5)
///     .errorCorrection(.high)
/// ```
///
/// ## Common Data Formats
///
/// ```swift
/// // URL
/// QRCode("https://example.com", at: .inches(0.5, 0.5))
///
/// // WiFi network
/// QRCode("WIFI:T:WPA;S:MyNetwork;P:MyPassword;;", at: .inches(0.5, 0.5))
///
/// // vCard contact
/// QRCode("BEGIN:VCARD\nVERSION:3.0\nN:Doe;John\nEND:VCARD", at: .inches(0.5, 0.5))
/// ```
public struct QRCode: ZPLElement, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var magnification: Int = 3  // 1-10
    private var errorCorrection: QRErrorCorrection = .medium

    /// Creates a QR code at the given position.
    ///
    /// - Parameters:
    ///   - data: The data to encode (URL, text, etc.).
    ///   - position: The position on the label.
    public init(_ data: String, at position: Position) {
        self.data = data
        self.position = position
    }

    /// Sets the magnification (size) of the QR code.
    ///
    /// Larger values produce bigger QR codes that are easier to scan
    /// from a distance.
    ///
    /// - Parameter mag: Magnification from 1 to 10. Default is 3.
    /// - Returns: A modified QR code element.
    public func magnification(_ mag: Int) -> QRCode {
        var copy = self
        copy.magnification = min(10, max(1, mag))
        return copy
    }

    /// Sets the error correction level.
    ///
    /// Higher levels allow the code to be read even if partially damaged,
    /// but result in a larger QR code.
    ///
    /// - Parameter level: The error correction level.
    /// - Returns: A modified QR code element.
    public func errorCorrection(_ level: QRErrorCorrection) -> QRCode {
        var copy = self
        copy.errorCorrection = level
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)

        // Escape only the user-supplied payload. The error-correction + input-mode
        // prefix (e.g. "MA,") is a ZPL control prefix and must remain unescaped.
        let (needsHex, escapedData) = escapeZPLFieldData(data)

        var result = "^FO\(pos.x),\(pos.y)"
        // ^BQ: orientation, model (2=enhanced), magnification.
        //
        // The error-correction level appears twice: once as the 4th ^BQ
        // parameter and again as the leading character of the ^FD data. This is
        // intentional and correct per the ZPL spec. For ^BQ the error-correction
        // and input-mode are supplied via the ^FD field-data prefix
        // ("<ecc><mode>,") — that prefix is authoritative and is what the printer
        // actually uses. The ^BQ parameter slot for error correction is largely
        // redundant/ignored for the QR symbology, but we emit it for completeness
        // and to keep the command explicit. The two values are always kept in
        // sync (both come from `errorCorrection.rawValue`).
        result += "^BQN,2,\(magnification),\(errorCorrection.rawValue)"
        if needsHex {
            result += "^FH"
        }
        // QR data must be prefixed with error correction and "A," for automatic
        // encoding. This ^FD prefix is the authoritative error-correction source
        // (see note above on ^BQ).
        result += "^FD\(errorCorrection.rawValue)A,\(escapedData)^FS"

        return result
    }
}
