import Foundation

/// Internal parsers for barcode commands (^BC, ^B3, ^BQ, ^BX, ^B7, ^B2, ^BE, ^B8, ^BU, ^B9, ^B0, ^BZ)
enum BarcodeParser {

    static func parseBarcode(_ type: ParsedBarcode.BarcodeType, params: String, x: Int, y: Int, moduleWidth: Int, rotation: String, defaultHeight: Int? = nil, dropsLeadingFlag: Bool = false) -> ParsedBarcode? {
        var remaining = params
        var rot = rotation
        // `^BY`'s third parameter sets the default bar height; without one the
        // parser keeps its historical 100-dot preview default.
        var height = defaultHeight ?? 100
        var showText = true
        var textAbove = false

        // First char might be rotation
        if let first = remaining.first, "NRIB".contains(first) {
            rot = String(first)
            remaining = String(remaining.dropFirst())
        }
        if remaining.hasPrefix(",") {
            remaining = String(remaining.dropFirst())
        }

        var parts = ZPLParser.splitParams(remaining)
        // ^B3 (Code 39) has a mod-43 check-digit flag before the height slot.
        if dropsLeadingFlag, !parts.isEmpty {
            parts.removeFirst()
        }

        // Empty slots mean "use the default", so only assign from non-empty ones.
        if let h = parts[safe: 0].flatMap(Int.init) {
            // Clamp bar height: it scales CoreImage barcode bitmaps directly.
            height = min(max(h, 1), RenderLimits.maxBarcodeHeight)
        }
        if let f = parts[safe: 1], !f.isEmpty {
            showText = f == "Y"
        }
        if let g = parts[safe: 2], !g.isEmpty {
            textAbove = g == "Y"
        }

        return ParsedBarcode(
            type: type,
            data: "",  // Data comes from ^FD
            x: x, y: y,
            height: height,
            moduleWidth: moduleWidth,
            rotation: rot,
            showText: showText,
            textAbove: textAbove,
            magnification: 1
        )
    }

    static func parseQRCode(_ params: String, x: Int, y: Int, rotation: String) -> ParsedBarcode? {
        var remaining = params
        var rot = rotation

        if let first = remaining.first, "NRIB".contains(first) {
            rot = String(first)
            remaining = String(remaining.dropFirst())
        }
        if remaining.hasPrefix(",") {
            remaining = String(remaining.dropFirst())
        }

        let parts = ZPLParser.splitParams(remaining)
        // parts[0] is the model (1 or 2); unused by the CoreImage generator.
        // Clamp magnification: it scales the generated CoreImage bitmap.
        let magnification = min(max(parts[safe: 1].flatMap(Int.init) ?? 3, 1), RenderLimits.maxBarcodeScale)

        return ParsedBarcode(
            type: .qrCode,
            data: "",
            x: x, y: y,
            height: magnification * 10,  // Approximate
            moduleWidth: 2,
            rotation: rot,
            showText: false,
            textAbove: false,
            magnification: magnification
        )
    }

    static func parseDataMatrix(_ params: String, x: Int, y: Int, rotation: String) -> ParsedBarcode? {
        var remaining = params
        var rot = rotation

        if let first = remaining.first, "NRIB".contains(first) {
            rot = String(first)
            remaining = String(remaining.dropFirst())
        }
        if remaining.hasPrefix(",") {
            remaining = String(remaining.dropFirst())
        }

        let parts = ZPLParser.splitParams(remaining)
        let size = min(max(parts[safe: 0].flatMap(Int.init) ?? 3, 1), RenderLimits.maxBarcodeScale)

        return ParsedBarcode(
            type: .dataMatrix,
            data: "",
            x: x, y: y,
            height: size * 10,
            moduleWidth: 2,
            rotation: rot,
            showText: false,
            textAbove: false,
            magnification: size
        )
    }

    static func parsePDF417(_ params: String, x: Int, y: Int, rotation: String) -> ParsedBarcode? {
        var remaining = params
        var rot = rotation

        if let first = remaining.first, "NRIB".contains(first) {
            rot = String(first)
            remaining = String(remaining.dropFirst())
        }
        if remaining.hasPrefix(",") {
            remaining = String(remaining.dropFirst())
        }

        let parts = ZPLParser.splitParams(remaining)
        let rowHeight = min(max(parts[safe: 0].flatMap(Int.init) ?? 10, 1), RenderLimits.maxBarcodeScale)

        return ParsedBarcode(
            type: .pdf417,
            data: "",
            x: x, y: y,
            height: rowHeight * 10,
            moduleWidth: 2,
            rotation: rot,
            showText: false,
            textAbove: false,
            magnification: rowHeight
        )
    }

    static func parseAztec(_ params: String, x: Int, y: Int, rotation: String) -> ParsedBarcode? {
        var remaining = params
        var rot = rotation

        if let first = remaining.first, "NRIB".contains(first) {
            rot = String(first)
            remaining = String(remaining.dropFirst())
        }
        if remaining.hasPrefix(",") {
            remaining = String(remaining.dropFirst())
        }

        let parts = ZPLParser.splitParams(remaining)
        let magnification = min(max(parts[safe: 0].flatMap(Int.init) ?? 3, 1), RenderLimits.maxBarcodeScale)

        return ParsedBarcode(
            type: .aztec,
            data: "",
            x: x, y: y,
            height: magnification * 10,
            moduleWidth: 2,
            rotation: rot,
            showText: false,
            textAbove: false,
            magnification: magnification
        )
    }
}
