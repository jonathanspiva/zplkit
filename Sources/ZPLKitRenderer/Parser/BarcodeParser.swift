import Foundation

/// Internal parsers for barcode commands (^BC, ^B3, ^BQ, ^BX, ^B7, ^B2, ^BE, ^B8, ^BU, ^B9, ^B0, ^BZ)
enum BarcodeParser {

    static func parseBarcode(_ type: ParsedBarcode.BarcodeType, params: String, x: Int, y: Int, moduleWidth: Int, rotation: String) -> ParsedBarcode? {
        var remaining = params
        var rot = rotation
        var height = 100
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

        let parts = remaining.split(separator: ",")
        if parts.count >= 1, let h = Int(parts[0]) {
            height = h
        }
        if parts.count >= 2 {
            showText = String(parts[1]) == "Y"
        }
        if parts.count >= 3 {
            textAbove = String(parts[2]) == "Y"
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

        let parts = remaining.split(separator: ",")
        let _ = parts.count >= 1 ? (Int(parts[0]) ?? 2) : 2  // model (1 or 2)
        let magnification = parts.count >= 2 ? (Int(parts[1]) ?? 3) : 3

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

        let parts = remaining.split(separator: ",")
        let size = parts.count >= 1 ? (Int(parts[0]) ?? 3) : 3

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

        let parts = remaining.split(separator: ",")
        let rowHeight = parts.count >= 1 ? (Int(parts[0]) ?? 10) : 10

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

        let parts = remaining.split(separator: ",")
        let magnification = parts.count >= 1 ? (Int(parts[0]) ?? 3) : 3

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
