import Foundation

/// Parses ZPL strings into a structured format for rendering
public enum ZPLParser {

    /// Parses a ZPL string into a ParsedLabel
    public static func parse(_ zpl: String) throws -> ParsedLabel {
        var width = 812        // Default 4 inches at 203 DPI
        var height = 1218      // Default 6 inches at 203 DPI
        var elements: [ParsedElement] = []
        var printQuantity = 1
        var printDarkness: Int? = nil

        // Current state during parsing
        var currentX = 0
        var currentY = 0
        let currentFont = "0"
        var currentFontHeight = 30
        var currentFontWidth = 30
        var currentRotation = "N"
        var useFieldTypeset = false
        var isReversed = false
        var moduleWidth = 2
        var textBlockWidth = 0
        var textBlockMaxLines = 1
        var textBlockAlignment = "L"
        var textBlockLineSpacing = 0
        var textBlockHangingIndent = 0

        // Pending barcode (barcode commands come before ^FD with the data)
        var pendingBarcode: ParsedBarcode? = nil

        // Split into commands - ZPL commands start with ^ or ~
        let pattern = #"(\^[A-Z][A-Z0-9]?[^^\~]*|\~[A-Z][A-Z0-9]?[^^\~]*)"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(zpl.startIndex..., in: zpl)
        let matches = regex.matches(in: zpl, options: [], range: range)

        for match in matches {
            guard let cmdRange = Range(match.range, in: zpl) else { continue }
            let command = String(zpl[cmdRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard command.count >= 2 else { continue }

            // Extract command type and parameters
            // ZPL commands are ^XY where X is a letter, Y is optional letter/number
            // Examples: ^PW812 -> cmd=^PW, params=812
            //           ^A0N,30,30 -> cmd=^A0, params=N,30,30
            //           ^FDHello -> cmd=^FD, params=Hello

            let cmdType: String
            let params: String

            // Use regex to extract command prefix
            let cmdPattern = #"^(\^[A-Z][A-Z0-9]?)"#
            if let cmdRegex = try? NSRegularExpression(pattern: cmdPattern),
               let cmdMatch = cmdRegex.firstMatch(in: command, range: NSRange(command.startIndex..., in: command)),
               let cmdMatchRange = Range(cmdMatch.range(at: 1), in: command) {
                cmdType = String(command[cmdMatchRange])
                params = String(command[cmdMatchRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                cmdType = String(command.prefix(2))
                params = String(command.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            }

            switch cmdType {
            // Label format
            case "^PW":
                width = Int(params) ?? width

            case "^LL":
                height = Int(params) ?? height

            case "^PQ":
                let parts = params.split(separator: ",")
                printQuantity = Int(parts.first ?? "1") ?? 1

            case "^MD":
                printDarkness = Int(params)

            // Field positioning
            case "^FO":
                let coords = params.split(separator: ",")
                if coords.count >= 2 {
                    currentX = Int(coords[0]) ?? 0
                    currentY = Int(coords[1]) ?? 0
                }
                useFieldTypeset = false

            case "^FT":
                let coords = params.split(separator: ",")
                if coords.count >= 2 {
                    currentX = Int(coords[0]) ?? 0
                    currentY = Int(coords[1]) ?? 0
                }
                useFieldTypeset = true

            // Font
            case "^A0", "^A":
                let fontParams = cmdType == "^A0" ? params : String(command.dropFirst(2))
                parseFontCommand(fontParams, rotation: &currentRotation, height: &currentFontHeight, width: &currentFontWidth)

            case "^CF":
                let parts = params.split(separator: ",")
                if parts.count >= 2 {
                    currentFontHeight = Int(parts[1]) ?? 30
                    currentFontWidth = parts.count > 2 ? (Int(parts[2]) ?? currentFontHeight) : currentFontHeight
                }

            // Field block (text block)
            case "^FB":
                let parts = params.split(separator: ",")
                textBlockWidth = Int(parts[safe: 0] ?? "0") ?? 0
                textBlockMaxLines = Int(parts[safe: 1] ?? "1") ?? 1
                textBlockLineSpacing = Int(parts[safe: 2] ?? "0") ?? 0
                textBlockAlignment = String(parts[safe: 3] ?? "L")
                textBlockHangingIndent = Int(parts[safe: 4] ?? "0") ?? 0

            case "^FR":
                isReversed = true

            case "^BY":
                let parts = params.split(separator: ",")
                moduleWidth = Int(parts.first ?? "2") ?? 2

            // Field data (text content or barcode data)
            case "^FD":
                let text = decodeFieldData(params)

                // Check if this data is for a pending barcode
                if var barcode = pendingBarcode {
                    barcode = ParsedBarcode(
                        type: barcode.type,
                        data: text,
                        x: barcode.x,
                        y: barcode.y,
                        height: barcode.height,
                        moduleWidth: barcode.moduleWidth,
                        rotation: barcode.rotation,
                        showText: barcode.showText,
                        textAbove: barcode.textAbove,
                        magnification: barcode.magnification
                    )
                    elements.append(.barcode(barcode))
                    pendingBarcode = nil
                } else if textBlockWidth > 0 {
                    elements.append(.textBlock(ParsedTextBlock(
                        text: text,
                        x: currentX,
                        y: currentY,
                        blockWidth: textBlockWidth,
                        font: currentFont,
                        fontHeight: currentFontHeight,
                        fontWidth: currentFontWidth,
                        maxLines: textBlockMaxLines,
                        lineSpacing: textBlockLineSpacing,
                        alignment: textBlockAlignment,
                        hangingIndent: textBlockHangingIndent,
                        useBaseline: useFieldTypeset
                    )))
                    textBlockWidth = 0  // Reset for next field
                } else {
                    elements.append(.text(ParsedText(
                        text: text,
                        x: currentX,
                        y: currentY,
                        font: currentFont,
                        fontHeight: currentFontHeight,
                        fontWidth: currentFontWidth,
                        rotation: currentRotation,
                        isReversed: isReversed,
                        useBaseline: useFieldTypeset
                    )))
                }
                isReversed = false

            // Graphics
            case "^GB":
                if let box = parseBox(params, x: currentX, y: currentY) {
                    elements.append(.box(box))
                }

            case "^GC":
                if let circle = parseCircle(params, x: currentX, y: currentY) {
                    elements.append(.circle(circle))
                }

            case "^GE":
                if let ellipse = parseEllipse(params, x: currentX, y: currentY) {
                    elements.append(.ellipse(ellipse))
                }

            case "^GD":
                if let diagonal = parseDiagonalLine(params, x: currentX, y: currentY) {
                    elements.append(.diagonalLine(diagonal))
                }

            // Barcodes - set as pending, data comes in ^FD
            case "^BC":
                pendingBarcode = parseBarcode(.code128, params: params, x: currentX, y: currentY, moduleWidth: moduleWidth, rotation: currentRotation)

            case "^B3":
                pendingBarcode = parseBarcode(.code39, params: params, x: currentX, y: currentY, moduleWidth: moduleWidth, rotation: currentRotation)

            case "^BQ":
                pendingBarcode = parseQRCode(params, x: currentX, y: currentY, rotation: currentRotation)

            case "^BX":
                pendingBarcode = parseDataMatrix(params, x: currentX, y: currentY, rotation: currentRotation)

            case "^B7":
                pendingBarcode = parsePDF417(params, x: currentX, y: currentY, rotation: currentRotation)

            case "^B2":
                pendingBarcode = parseBarcode(.interleaved2of5, params: params, x: currentX, y: currentY, moduleWidth: moduleWidth, rotation: currentRotation)

            case "^BE":
                pendingBarcode = parseBarcode(.ean13, params: params, x: currentX, y: currentY, moduleWidth: moduleWidth, rotation: currentRotation)

            case "^B8":
                pendingBarcode = parseBarcode(.ean8, params: params, x: currentX, y: currentY, moduleWidth: moduleWidth, rotation: currentRotation)

            case "^BU":
                pendingBarcode = parseBarcode(.upcA, params: params, x: currentX, y: currentY, moduleWidth: moduleWidth, rotation: currentRotation)

            case "^B9":
                pendingBarcode = parseBarcode(.upcE, params: params, x: currentX, y: currentY, moduleWidth: moduleWidth, rotation: currentRotation)

            case "^B0":
                pendingBarcode = parseAztec(params, x: currentX, y: currentY, rotation: currentRotation)

            case "^BZ":
                pendingBarcode = parseBarcode(.intelligentMail, params: params, x: currentX, y: currentY, moduleWidth: moduleWidth, rotation: currentRotation)

            default:
                break  // Ignore unknown commands
            }
        }

        return ParsedLabel(
            width: width,
            height: height,
            elements: elements,
            printQuantity: printQuantity,
            printDarkness: printDarkness
        )
    }

    // MARK: - Parse Helpers

    private static func parseFontCommand(_ params: String, rotation: inout String, height: inout Int, width: inout Int) {
        // Format: ^A0N,height,width or ^A0R,height,width etc.
        var remaining = params

        // First char might be rotation
        if let first = remaining.first, "NRIB".contains(first) {
            rotation = String(first)
            remaining = String(remaining.dropFirst())
        }

        // Remove leading comma if present
        if remaining.hasPrefix(",") {
            remaining = String(remaining.dropFirst())
        }

        let parts = remaining.split(separator: ",")
        if parts.count >= 1, let h = Int(parts[0]) {
            height = h
        }
        if parts.count >= 2, let w = Int(parts[1]) {
            width = w
        } else {
            width = height
        }
    }

    private static func decodeFieldData(_ data: String) -> String {
        // Handle hex encoding (_XX)
        var result = data
        // Remove trailing ^FS if present
        if result.hasSuffix("^FS") {
            result = String(result.dropLast(3))
        }

        // Decode hex escapes
        let hexPattern = #"_([0-9A-Fa-f]{2})"#
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            var decoded = result
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let hexRange = Range(match.range(at: 1), in: result),
                   let byte = UInt8(result[hexRange], radix: 16) {
                    let char = Character(UnicodeScalar(byte))
                    if let fullRange = Range(match.range, in: decoded) {
                        decoded.replaceSubrange(fullRange, with: String(char))
                    }
                }
            }
            result = decoded
        }

        return result
    }

    private static func parseBox(_ params: String, x: Int, y: Int) -> ParsedBox? {
        let parts = params.split(separator: ",")
        guard parts.count >= 2 else { return nil }

        let width = Int(parts[0]) ?? 0
        let height = Int(parts[1]) ?? 0
        let thickness = parts.count > 2 ? (Int(parts[2]) ?? 1) : 1
        let color = parts.count > 3 ? String(parts[3]) : "B"
        let cornerRadius = parts.count > 4 ? (Int(parts[4]) ?? 0) : 0

        return ParsedBox(x: x, y: y, width: width, height: height, thickness: thickness, color: color, cornerRadius: cornerRadius)
    }

    private static func parseCircle(_ params: String, x: Int, y: Int) -> ParsedCircle? {
        let parts = params.split(separator: ",")
        guard !parts.isEmpty else { return nil }

        let diameter = Int(parts[0]) ?? 0
        let thickness = parts.count > 1 ? (Int(parts[1]) ?? 1) : 1
        let color = parts.count > 2 ? String(parts[2]) : "B"

        return ParsedCircle(x: x, y: y, diameter: diameter, thickness: thickness, color: color)
    }

    private static func parseEllipse(_ params: String, x: Int, y: Int) -> ParsedEllipse? {
        let parts = params.split(separator: ",")
        guard parts.count >= 2 else { return nil }

        let width = Int(parts[0]) ?? 0
        let height = Int(parts[1]) ?? 0
        let thickness = parts.count > 2 ? (Int(parts[2]) ?? 1) : 1
        let color = parts.count > 3 ? String(parts[3]) : "B"

        return ParsedEllipse(x: x, y: y, width: width, height: height, thickness: thickness, color: color)
    }

    private static func parseDiagonalLine(_ params: String, x: Int, y: Int) -> ParsedDiagonalLine? {
        let parts = params.split(separator: ",")
        guard parts.count >= 2 else { return nil }

        let width = Int(parts[0]) ?? 0
        let height = Int(parts[1]) ?? 0
        let thickness = parts.count > 2 ? (Int(parts[2]) ?? 1) : 1
        let color = parts.count > 3 ? String(parts[3]) : "B"
        let direction = parts.count > 4 ? String(parts[4]) : "R"

        return ParsedDiagonalLine(x: x, y: y, width: width, height: height, thickness: thickness, color: color, direction: direction)
    }

    private static func parseBarcode(_ type: ParsedBarcode.BarcodeType, params: String, x: Int, y: Int, moduleWidth: Int, rotation: String) -> ParsedBarcode? {
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

    private static func parseQRCode(_ params: String, x: Int, y: Int, rotation: String) -> ParsedBarcode? {
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

    private static func parseDataMatrix(_ params: String, x: Int, y: Int, rotation: String) -> ParsedBarcode? {
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

    private static func parsePDF417(_ params: String, x: Int, y: Int, rotation: String) -> ParsedBarcode? {
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

    private static func parseAztec(_ params: String, x: Int, y: Int, rotation: String) -> ParsedBarcode? {
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

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Array where Element == Substring {
    subscript(safe index: Int) -> String? {
        return indices.contains(index) ? String(self[index]) : nil
    }
}
