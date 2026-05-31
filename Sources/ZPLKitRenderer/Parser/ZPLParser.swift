import Foundation

/// Parses ZPL strings into a structured format for rendering.
///
/// The parser extracts label dimensions, elements (text, barcodes, shapes, graphics),
/// and print settings from ZPL command strings.
///
/// - Note: The `Parsed*` types returned by this parser are intended for internal
///   rendering use. Their structure may change between releases.
public enum ZPLParser {

    /// Matches a single ZPL command (starting with `^` or `~`) and its parameters.
    /// Compiled once and reused across parses.
    private static let commandRegex = try! NSRegularExpression(
        pattern: #"(\^[A-Z][A-Z0-9]?[^^\~]*|\~[A-Z][A-Z0-9]?[^^\~]*)"#,
        options: []
    )

    /// Matches the leading command token (e.g. `^A0`) of a single command string.
    /// Compiled once and reused across parses.
    private static let commandPrefixRegex = try! NSRegularExpression(
        pattern: #"^(\^[A-Z][A-Z0-9]?)"#,
        options: []
    )

    /// Parses a ZPL string into a ParsedLabel.
    ///
    /// - Parameter zpl: A ZPL command string (typically starting with `^XA` and ending with `^XZ`)
    /// - Returns: A structured representation of the label
    /// - Throws: An error if the ZPL cannot be parsed
    public static func parse(_ zpl: String) throws -> ParsedLabel {
        var state = ParserState()

        // Split into commands - ZPL commands start with ^ or ~
        let range = NSRange(zpl.startIndex..., in: zpl)
        let matches = commandRegex.matches(in: zpl, options: [], range: range)

        for match in matches {
            guard let cmdRange = Range(match.range, in: zpl) else { continue }
            let command = String(zpl[cmdRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            guard command.count >= 2 else { continue }

            let (cmdType, params) = extractCommand(command)
            processCommand(cmdType, params: params, state: &state)
        }

        return ParsedLabel(
            width: state.width,
            height: state.height,
            elements: state.elements,
            printQuantity: state.printQuantity,
            printDarkness: state.printDarkness
        )
    }

    // MARK: - Command Extraction

    private static func extractCommand(_ command: String) -> (type: String, params: String) {
        if let cmdMatch = commandPrefixRegex.firstMatch(in: command, range: NSRange(command.startIndex..., in: command)),
           let cmdMatchRange = Range(cmdMatch.range(at: 1), in: command) {
            let cmdType = String(command[cmdMatchRange])
            let params = String(command[cmdMatchRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return (cmdType, params)
        } else {
            let cmdType = String(command.prefix(2))
            let params = String(command.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            return (cmdType, params)
        }
    }

    // MARK: - Command Processing

    private static func processCommand(_ cmdType: String, params: String, state: inout ParserState) {
        switch cmdType {
        // Label format
        case "^PW":
            state.width = Int(params) ?? state.width

        case "^LL":
            state.height = Int(params) ?? state.height

        case "^PQ":
            let parts = params.split(separator: ",")
            state.printQuantity = Int(parts.first ?? "1") ?? 1

        case "^MD":
            state.printDarkness = Int(params)

        // Field positioning
        case "^FO":
            let coords = params.split(separator: ",")
            if coords.count >= 2 {
                state.currentX = Int(coords[0]) ?? 0
                state.currentY = Int(coords[1]) ?? 0
            }
            state.useFieldTypeset = false

        case "^FT":
            let coords = params.split(separator: ",")
            if coords.count >= 2 {
                state.currentX = Int(coords[0]) ?? 0
                state.currentY = Int(coords[1]) ?? 0
            }
            state.useFieldTypeset = true

        // Font
        case "^A0", "^A":
            let fontParams = cmdType == "^A0" ? params : String(params)
            TextParser.parseFontCommand(fontParams, rotation: &state.currentRotation, height: &state.currentFontHeight, width: &state.currentFontWidth)

        case "^CF":
            let parts = params.split(separator: ",")
            if parts.count >= 2 {
                state.currentFontHeight = Int(parts[1]) ?? 30
                state.currentFontWidth = parts.count > 2 ? (Int(parts[2]) ?? state.currentFontHeight) : state.currentFontHeight
            }

        // Field block (text block)
        case "^FB":
            let parts = params.split(separator: ",")
            state.textBlockWidth = Int(parts[safe: 0] ?? "0") ?? 0
            state.textBlockMaxLines = Int(parts[safe: 1] ?? "1") ?? 1
            state.textBlockLineSpacing = Int(parts[safe: 2] ?? "0") ?? 0
            state.textBlockAlignment = String(parts[safe: 3] ?? "L")
            state.textBlockHangingIndent = Int(parts[safe: 4] ?? "0") ?? 0

        case "^FR":
            state.isReversed = true

        case "^BY":
            let parts = params.split(separator: ",")
            state.moduleWidth = Int(parts.first ?? "2") ?? 2

        // Field data (text content or barcode data)
        case "^FD":
            processFieldData(params, state: &state)

        // Shapes
        case "^GB":
            if let box = ShapeParser.parseBox(params, x: state.currentX, y: state.currentY) {
                state.elements.append(.box(box))
            }

        case "^GC":
            if let circle = ShapeParser.parseCircle(params, x: state.currentX, y: state.currentY) {
                state.elements.append(.circle(circle))
            }

        case "^GE":
            if let ellipse = ShapeParser.parseEllipse(params, x: state.currentX, y: state.currentY) {
                state.elements.append(.ellipse(ellipse))
            }

        case "^GD":
            if let diagonal = ShapeParser.parseDiagonalLine(params, x: state.currentX, y: state.currentY) {
                state.elements.append(.diagonalLine(diagonal))
            }

        // Barcodes
        case "^BC":
            state.pendingBarcode = BarcodeParser.parseBarcode(.code128, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.currentRotation)

        case "^B3":
            state.pendingBarcode = BarcodeParser.parseBarcode(.code39, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.currentRotation)

        case "^BQ":
            state.pendingBarcode = BarcodeParser.parseQRCode(params, x: state.currentX, y: state.currentY, rotation: state.currentRotation)

        case "^BX":
            state.pendingBarcode = BarcodeParser.parseDataMatrix(params, x: state.currentX, y: state.currentY, rotation: state.currentRotation)

        case "^B7":
            state.pendingBarcode = BarcodeParser.parsePDF417(params, x: state.currentX, y: state.currentY, rotation: state.currentRotation)

        case "^B2":
            state.pendingBarcode = BarcodeParser.parseBarcode(.interleaved2of5, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.currentRotation)

        case "^BE":
            state.pendingBarcode = BarcodeParser.parseBarcode(.ean13, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.currentRotation)

        case "^B8":
            state.pendingBarcode = BarcodeParser.parseBarcode(.ean8, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.currentRotation)

        case "^BU":
            state.pendingBarcode = BarcodeParser.parseBarcode(.upcA, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.currentRotation)

        case "^B9":
            state.pendingBarcode = BarcodeParser.parseBarcode(.upcE, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.currentRotation)

        case "^B0":
            state.pendingBarcode = BarcodeParser.parseAztec(params, x: state.currentX, y: state.currentY, rotation: state.currentRotation)

        case "^BZ":
            state.pendingBarcode = BarcodeParser.parseBarcode(.intelligentMail, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.currentRotation)

        // Graphics
        case "^GF":
            if let graphic = GraphicParser.parseGraphic(params, x: state.currentX, y: state.currentY) {
                state.elements.append(.graphic(graphic))
            }

        default:
            break  // Ignore unknown commands
        }
    }

    // MARK: - Field Data Processing

    private static func processFieldData(_ params: String, state: inout ParserState) {
        let text = TextParser.decodeFieldData(params)

        // Check if this data is for a pending barcode
        if var barcode = state.pendingBarcode {
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
            state.elements.append(.barcode(barcode))
            state.pendingBarcode = nil
        } else if state.textBlockWidth > 0 {
            state.elements.append(.textBlock(ParsedTextBlock(
                text: text,
                x: state.currentX,
                y: state.currentY,
                blockWidth: state.textBlockWidth,
                font: state.currentFont,
                fontHeight: state.currentFontHeight,
                fontWidth: state.currentFontWidth,
                maxLines: state.textBlockMaxLines,
                lineSpacing: state.textBlockLineSpacing,
                alignment: state.textBlockAlignment,
                hangingIndent: state.textBlockHangingIndent,
                useBaseline: state.useFieldTypeset
            )))
            // Reset ALL text-block state together so a later `^FB` that omits
            // parameters does not inherit this block's alignment / maxLines / etc.
            state.resetTextBlock()
        } else {
            state.elements.append(.text(ParsedText(
                text: text,
                x: state.currentX,
                y: state.currentY,
                font: state.currentFont,
                fontHeight: state.currentFontHeight,
                fontWidth: state.currentFontWidth,
                rotation: state.currentRotation,
                isReversed: state.isReversed,
                useBaseline: state.useFieldTypeset
            )))
        }
        state.isReversed = false
    }
}

// MARK: - Parser State

private struct ParserState {
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

    /// Resets every `^FB` text-block field to its default so the next field does
    /// not inherit stale values from a previously consumed block.
    mutating func resetTextBlock() {
        textBlockWidth = 0
        textBlockMaxLines = 1
        textBlockAlignment = "L"
        textBlockLineSpacing = 0
        textBlockHangingIndent = 0
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
