import Foundation

/// Parses ZPL strings into a structured format for rendering.
///
/// The parser extracts label dimensions, elements (text, barcodes, shapes, graphics),
/// and print settings from ZPL command strings.
///
/// - Note: The `Parsed*` types returned by this parser are part of the public,
///   semver-stable API. ``ParsedElement`` may gain new cases in minor releases
///   as more ZPL commands are supported, so switch over it with a `default`.
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
            // Trim only newlines: printers strip CR/LF from the format stream, but
            // spaces inside `^FD` field data are significant and must survive.
            let command = String(zpl[cmdRange]).trimmingCharacters(in: .newlines)

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
        // Trim only newlines here too; leading/trailing spaces in `^FD` params
        // are field data and must be preserved.
        if let cmdMatch = commandPrefixRegex.firstMatch(in: command, range: NSRange(command.startIndex..., in: command)),
           let cmdMatchRange = Range(cmdMatch.range(at: 1), in: command) {
            let cmdType = String(command[cmdMatchRange])
            let params = String(command[cmdMatchRange.upperBound...]).trimmingCharacters(in: .newlines)
            return (cmdType, params)
        } else {
            let cmdType = String(command.prefix(2))
            let params = String(command.dropFirst(2)).trimmingCharacters(in: .newlines)
            return (cmdType, params)
        }
    }

    /// Splits a ZPL parameter list on commas, preserving empty slots.
    ///
    /// ZPL allows omitting middle parameters (`^GB100,,2`, `^BCN,,Y,N,N`), which
    /// means "use the default" for that slot. `split`'s default of omitting empty
    /// subsequences would shift every following parameter into the wrong slot.
    static func splitParams(_ params: String) -> [Substring] {
        params.split(separator: ",", omittingEmptySubsequences: false)
    }

    // MARK: - Command Processing

    private static func processCommand(_ cmdType: String, params rawParams: String, state: inout ParserState) {
        // Command parameters tolerate surrounding whitespace (pretty-printed /
        // indented ZPL), EXCEPT field data: spaces inside `^FD` are significant.
        let params = cmdType == "^FD"
            ? rawParams
            : rawParams.trimmingCharacters(in: .whitespacesAndNewlines)

        // Font selection: `^A` followed by a single font designator (0-9, A-Z),
        // e.g. `^A0N,30,30` or `^ABR,60,40`. Handled outside the switch so every
        // designator keeps its rotation/size instead of only `^A0`.
        if cmdType.count == 3, cmdType.hasPrefix("^A"),
           let designator = cmdType.last, designator.isLetter || designator.isNumber {
            state.currentFont = String(designator)
            TextParser.parseFontCommand(params, rotation: &state.currentRotation, height: &state.currentFontHeight, width: &state.currentFontWidth)
            // Clamp untrusted font dimensions so downstream block-height math
            // (maxLines * fontHeight) cannot overflow or balloon allocations.
            state.currentFontHeight = min(max(state.currentFontHeight, 0), RenderLimits.maxFontHeight)
            state.currentFontWidth = min(max(state.currentFontWidth, 0), RenderLimits.maxFontHeight)
            return
        }

        switch cmdType {
        // Label format
        case "^PW":
            // Clamp untrusted width to a safe range so the renderer never traps
            // on `width * 4` overflow or requests a multi-GB context.
            if let w = Int(params) { state.width = RenderLimits.clampDimension(w) }

        case "^LL":
            if let h = Int(params) { state.height = RenderLimits.clampDimension(h) }

        case "^PQ":
            let parts = splitParams(params)
            state.printQuantity = Int(parts.first ?? "1") ?? 1

        case "^MD":
            state.printDarkness = Int(params)

        // Field positioning
        // An omitted y defaults to 0 rather than inheriting the previous
        // field's y (verified against Labelary: `^FO150` lands at (150, 0)).
        // Requiring both coordinates silently dropped the whole command, so the
        // field stacked on top of whatever was positioned before it.
        case "^FO":
            let coords = splitParams(params)
            if !coords.isEmpty {
                state.currentX = Int(coords[0]) ?? 0
                state.currentY = coords.count >= 2 ? (Int(coords[1]) ?? 0) : 0
            }
            state.useFieldTypeset = false

        case "^FT":
            let coords = splitParams(params)
            if !coords.isEmpty {
                state.currentX = Int(coords[0]) ?? 0
                state.currentY = coords.count >= 2 ? (Int(coords[1]) ?? 0) : 0
            }
            state.useFieldTypeset = true

        // Bare `^A` (no designator matched above, e.g. `^A,30,30`)
        case "^A":
            TextParser.parseFontCommand(params, rotation: &state.currentRotation, height: &state.currentFontHeight, width: &state.currentFontWidth)
            state.currentFontHeight = min(max(state.currentFontHeight, 0), RenderLimits.maxFontHeight)
            state.currentFontWidth = min(max(state.currentFontWidth, 0), RenderLimits.maxFontHeight)

        case "^CF":
            let parts = splitParams(params)
            if parts.count >= 1, let designator = parts[0].first,
               designator.isLetter || designator.isNumber {
                state.currentFont = String(designator)
            }
            if parts.count >= 2 {
                // An omitted height follows the supplied width for the scalable
                // font (`^CF0,,20` renders at 20, verified against Labelary).
                // This previously fell back to a hardcoded 30, so any `^CF` with
                // an omitted height rendered at the wrong size.
                let parsedHeight = Int(parts[1])
                let parsedWidth = parts.count > 2 ? Int(parts[2]) : nil
                let height = parsedHeight ?? parsedWidth ?? state.currentFontHeight
                state.currentFontHeight = min(height, RenderLimits.maxFontHeight)
                state.currentFontWidth = min(parsedWidth ?? height, RenderLimits.maxFontHeight)
            }

        // Default field orientation. Applies to any field that omits its own
        // orientation slot. A barcode must take its default from here, NOT from
        // the last `^A` font command: `^A0R` followed by `^BC,...` renders the
        // barcode UNrotated on a printer.
        case "^FW":
            if let orientation = splitParams(params).first?.first,
               "NRIB".contains(orientation) {
                state.fieldDefaultRotation = String(orientation)
                state.currentRotation = String(orientation)
            }

        // Field hex mode: `^FHa` enables `_XX`-style escapes (indicator defaults
        // to `_`) for the next field's data. Scoped to one field, reset at ^FS/^FD.
        case "^FH":
            state.fieldHexIndicator = params.first ?? "_"

        // Field separator: ends the current field. A barcode command whose field
        // closed without `^FD` must not survive to capture a later field's data,
        // and `^FR` / `^FH` are field-scoped.
        case "^FS":
            state.pendingBarcode = nil
            state.isReversed = false
            state.fieldHexIndicator = nil
            // `^FB` is field-scoped too. Without this, a `^FB` whose field
            // closed with no `^FD` leaked its block width/alignment onto the
            // next field, centering text that should have been left-anchored.
            state.resetTextBlock()

        // Field block (text block)
        case "^FB":
            let parts = splitParams(params)
            state.textBlockWidth = min(max(Int(parts[safe: 0] ?? "0") ?? 0, 0), RenderLimits.maxDimensionDots)
            // Clamp untrusted line count so `maxLines * fontHeight` (block height)
            // stays bounded.
            state.textBlockMaxLines = min(max(Int(parts[safe: 1] ?? "1") ?? 1, 1), RenderLimits.maxTextBlockLines)
            state.textBlockLineSpacing = Int(parts[safe: 2] ?? "0") ?? 0
            state.textBlockAlignment = String(parts[safe: 3] ?? "L")
            state.textBlockHangingIndent = Int(parts[safe: 4] ?? "0") ?? 0

        case "^FR":
            state.isReversed = true

        case "^BY":
            let parts = splitParams(params)
            // Clamp module width: it scales CoreImage barcode bitmaps, so an
            // unbounded value asks CoreImage to materialize a giant image.
            if let w = parts[safe: 0].flatMap(Int.init) {
                state.moduleWidth = min(max(w, 1), RenderLimits.maxBarcodeScale)
            }
            // Third parameter is the default bar height for subsequent barcodes.
            if let h = parts[safe: 2].flatMap(Int.init) {
                state.defaultBarcodeHeight = min(max(h, 1), RenderLimits.maxBarcodeHeight)
            }

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
            state.pendingBarcode = BarcodeParser.parseBarcode(.code128, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.fieldDefaultRotation, defaultHeight: state.defaultBarcodeHeight)

        case "^B3":
            // ^B3o,e,h,f,g puts the mod-43 check-digit flag BEFORE height,
            // unlike the shared o,h,f,g layout; drop that slot before parsing.
            state.pendingBarcode = BarcodeParser.parseBarcode(.code39, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.fieldDefaultRotation, defaultHeight: state.defaultBarcodeHeight, dropsLeadingFlag: true)

        case "^BQ":
            state.pendingBarcode = BarcodeParser.parseQRCode(params, x: state.currentX, y: state.currentY, rotation: state.fieldDefaultRotation)

        case "^BX":
            state.pendingBarcode = BarcodeParser.parseDataMatrix(params, x: state.currentX, y: state.currentY, rotation: state.fieldDefaultRotation)

        case "^B7":
            state.pendingBarcode = BarcodeParser.parsePDF417(params, x: state.currentX, y: state.currentY, rotation: state.fieldDefaultRotation)

        case "^B2":
            state.pendingBarcode = BarcodeParser.parseBarcode(.interleaved2of5, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.fieldDefaultRotation, defaultHeight: state.defaultBarcodeHeight)

        case "^BE":
            state.pendingBarcode = BarcodeParser.parseBarcode(.ean13, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.fieldDefaultRotation, defaultHeight: state.defaultBarcodeHeight)

        case "^B8":
            state.pendingBarcode = BarcodeParser.parseBarcode(.ean8, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.fieldDefaultRotation, defaultHeight: state.defaultBarcodeHeight)

        case "^BU":
            state.pendingBarcode = BarcodeParser.parseBarcode(.upcA, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.fieldDefaultRotation, defaultHeight: state.defaultBarcodeHeight)

        case "^B9":
            state.pendingBarcode = BarcodeParser.parseBarcode(.upcE, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.fieldDefaultRotation, defaultHeight: state.defaultBarcodeHeight)

        case "^B0":
            state.pendingBarcode = BarcodeParser.parseAztec(params, x: state.currentX, y: state.currentY, rotation: state.fieldDefaultRotation)

        case "^BZ":
            state.pendingBarcode = BarcodeParser.parseBarcode(.intelligentMail, params: params, x: state.currentX, y: state.currentY, moduleWidth: state.moduleWidth, rotation: state.fieldDefaultRotation, defaultHeight: state.defaultBarcodeHeight)

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
        // `_XX` escapes are only active when the field was preceded by `^FH`.
        let text = TextParser.decodeFieldData(params, hexIndicator: state.fieldHexIndicator)
        state.fieldHexIndicator = nil

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
                magnification: barcode.magnification,
                useBaseline: state.useFieldTypeset
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
                // Text takes the `^A` rotation. Only barcodes fall back to the
                // `^FW` default, since `^A` must not steer them.
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
    var currentFont = "0"
    var currentFontHeight = 30
    var currentFontWidth = 30
    var currentRotation = "N"
    /// Default field orientation from `^FW`, used by any field that omits its
    /// own orientation slot. Kept separate from `currentRotation` (which `^A`
    /// overwrites) so a font rotation cannot leak into a barcode.
    var fieldDefaultRotation = "N"
    var useFieldTypeset = false
    var isReversed = false
    var fieldHexIndicator: Character? = nil
    var moduleWidth = 2
    // Set by ^BY's third parameter; nil means "no ^BY height seen", in which
    // case the parser keeps its historical 100-dot preview default.
    var defaultBarcodeHeight: Int? = nil
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
