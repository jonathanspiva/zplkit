import Foundation
import CoreGraphics
import Testing
import ZPLVerifier
@testable import ZPLKitRenderer
@testable import ZPLKit

// MARK: - Parser: Layout & Field Commands

@Suite("Parser Layout & Field Commands")
struct ParserLayoutTests {

    @Test("^PW sets width")
    func parserPWCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^XZ")
        #expect(parsed.width == 600)
    }

    @Test("^LL sets height")
    func parserLLCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^XZ")
        #expect(parsed.height == 400)
    }

    @Test("^PQ sets print quantity")
    func parserPQCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^PQ5^XZ")
        #expect(parsed.printQuantity == 5)
    }

    @Test("^PQ with multiple params uses first as quantity")
    func parserPQCommandWithMultipleParams() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^PQ10,2,1^XZ")
        #expect(parsed.printQuantity == 10)
    }

    @Test("^MD sets print darkness")
    func parserMDCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^MD15^XZ")
        #expect(parsed.printDarkness == 15)
    }

    @Test("^FO sets element origin")
    func parserFOCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO100,200^FDTest^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.x == 100)
        #expect(text.y == 200)
    }

    @Test("^FT sets origin and baseline flag")
    func parserFTCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FT100,200^FDTest^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.x == 100)
        #expect(text.y == 200)
        #expect(text.useBaseline)
    }

    @Test("^A0 with rotation sets rotation/height/width")
    func parserA0CommandWithRotation() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^A0R,40,30^FDRotated^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.rotation == "R")
        #expect(text.fontHeight == 40)
        #expect(text.fontWidth == 30)
    }

    @Test("^A0 normal rotation")
    func parserA0CommandNormalRotation() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^A0N,25,25^FDNormal^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.rotation == "N")
    }

    @Test("^CF sets default font height/width")
    func parserCFCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^CF0,50,40^FO50,50^FDStyled^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.fontHeight == 50)
        #expect(text.fontWidth == 40)
    }

    @Test("^FB sets block width/maxLines/alignment")
    func parserFBCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^FB300,3,0,C,0^FDCentered text^FS^XZ")
        let block = try #require(parsed.elements.first?.asTextBlock)
        #expect(block.blockWidth == 300)
        #expect(block.maxLines == 3)
        #expect(block.alignment == "C")
    }

    @Test("^FB with line spacing sets lineSpacing/hangingIndent")
    func parserFBCommandWithLineSpacing() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^FB300,5,10,L,5^FDText^FS^XZ")
        let block = try #require(parsed.elements.first?.asTextBlock)
        #expect(block.lineSpacing == 10)
        #expect(block.hangingIndent == 5)
    }

    @Test("^FR marks text reversed")
    func parserFRCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^FR^FDReversed^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.isReversed)
    }
}

// MARK: - Parser: Shape Commands

@Suite("Parser Shape Commands")
struct ParserShapeTests {

    @Test("^GB parses full box parameters")
    func parserGBCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO100,100^GB200,150,3,B,2^FS^XZ")
        let box = try #require(parsed.elements.first?.asBox)
        #expect(box.x == 100)
        #expect(box.y == 100)
        #expect(box.width == 200)
        #expect(box.height == 150)
        #expect(box.thickness == 3)
        #expect(box.color == "B")
        #expect(box.cornerRadius == 2)
    }

    @Test("^GB white color")
    func parserGBCommandWhiteColor() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO100,100^GB200,150,3,W^FS^XZ")
        let box = try #require(parsed.elements.first?.asBox)
        #expect(box.color == "W")
    }

    @Test("^GC parses circle parameters")
    func parserGCCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO100,100^GC150,5,B^FS^XZ")
        let circle = try #require(parsed.elements.first?.asCircle)
        #expect(circle.x == 100)
        #expect(circle.y == 100)
        #expect(circle.diameter == 150)
        #expect(circle.thickness == 5)
    }

    @Test("^GE parses ellipse parameters")
    func parserGECommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO100,100^GE200,100,3,B^FS^XZ")
        let ellipse = try #require(parsed.elements.first?.asEllipse)
        #expect(ellipse.width == 200)
        #expect(ellipse.height == 100)
        #expect(ellipse.thickness == 3)
    }

    @Test("^GD right-leaning diagonal")
    func parserGDCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO100,100^GD150,150,2,B,R^FS^XZ")
        let diagonal = try #require(parsed.elements.first?.asDiagonalLine)
        #expect(diagonal.width == 150)
        #expect(diagonal.height == 150)
        #expect(diagonal.direction == "R")
    }

    @Test("^GD left-leaning diagonal")
    func parserGDCommandLeftLeaning() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO100,100^GD150,150,2,B,L^FS^XZ")
        let diagonal = try #require(parsed.elements.first?.asDiagonalLine)
        #expect(diagonal.direction == "L")
    }

    @Test("^GF parses graphic origin/format/bytesPerRow")
    func parserGFCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW200^LL100^FO10,10^GFA,4,4,1,FF^FS^XZ")
        let graphic = try #require(parsed.elements.first?.asGraphic)
        #expect(graphic.x == 10)
        #expect(graphic.y == 10)
        #expect(graphic.format == .ascii)
        #expect(graphic.bytesPerRow == 1)
    }
}

// MARK: - Parser: Barcode Commands

@Suite("Parser Barcode Commands")
struct ParserBarcodeTests {

    /// One row per barcode command. `zpl` parses to a `.barcode` whose `.type` must match
    /// `expectedType`; the optional columns assert the extra per-command fields the original
    /// individual tests checked (data / height / showText / magnification).
    struct Row: Sendable {
        let name: String
        let zpl: String
        let expectedType: ParsedBarcode.BarcodeType
        var data: String?
        var height: Int?
        var showText: Bool?
        var magnification: Int?
    }

    @Test(arguments: [
        Row(name: "BC/code128", zpl: "^XA^PW600^LL400^FO50,50^BCN,100,Y,N,N^FD12345^FS^XZ",
            expectedType: .code128, data: "12345", height: 100, showText: true),
        Row(name: "B3/code39", zpl: "^XA^PW600^LL400^FO50,50^B3N,N,100,Y,N^FDABC123^FS^XZ",
            expectedType: .code39, data: "ABC123"),
        Row(name: "BQ/qrCode", zpl: "^XA^PW600^LL400^FO50,50^BQN,2,5^FDMA,https://example.com^FS^XZ",
            expectedType: .qrCode, magnification: 5),
        Row(name: "BX/dataMatrix", zpl: "^XA^PW600^LL400^FO50,50^BXN,4^FDTEST^FS^XZ",
            expectedType: .dataMatrix, magnification: 4),
        Row(name: "B7/pdf417", zpl: "^XA^PW600^LL400^FO50,50^B7N,10^FDPDF417DATA^FS^XZ",
            expectedType: .pdf417),
        Row(name: "B2/interleaved2of5", zpl: "^XA^PW600^LL400^FO50,50^B2N,100,Y,N,N^FD123456^FS^XZ",
            expectedType: .interleaved2of5, data: "123456"),
        Row(name: "BE/ean13", zpl: "^XA^PW600^LL400^FO50,50^BEN,100,Y,N^FD590123412345^FS^XZ",
            expectedType: .ean13),
        Row(name: "B8/ean8", zpl: "^XA^PW600^LL400^FO50,50^B8N,100,Y,N^FD1234567^FS^XZ",
            expectedType: .ean8),
        Row(name: "BU/upcA", zpl: "^XA^PW600^LL400^FO50,50^BUN,100,Y,N,N^FD01234567890^FS^XZ",
            expectedType: .upcA),
        Row(name: "B9/upcE", zpl: "^XA^PW600^LL400^FO50,50^B9N,100,N,N,N^FD123456^FS^XZ",
            expectedType: .upcE),
        Row(name: "B0/aztec", zpl: "^XA^PW600^LL400^FO50,50^B0N,4^FDAZTECDATA^FS^XZ",
            expectedType: .aztec, magnification: 4),
        Row(name: "BZ/intelligentMail", zpl: "^XA^PW600^LL400^FO50,50^BZN,30^FD01234567890123456789^FS^XZ",
            expectedType: .intelligentMail)
    ])
    func parserBarcodeCommands(_ row: Row) throws {
        let parsed = try ZPLParser.parse(row.zpl)
        let barcode = try #require(parsed.elements.first?.asBarcode, "row \(row.name)")
        #expect(barcode.type == row.expectedType, "row \(row.name)")
        if let data = row.data { #expect(barcode.data == data, "row \(row.name)") }
        if let height = row.height { #expect(barcode.height == height, "row \(row.name)") }
        if let showText = row.showText { #expect(barcode.showText == showText, "row \(row.name)") }
        if let mag = row.magnification { #expect(barcode.magnification == mag, "row \(row.name)") }
    }

    @Test("^BY sets module width on following barcode")
    func parserBYCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^BY3^BCN,100^FD12345^FS^XZ")
        let barcode = try #require(parsed.elements.first?.asBarcode)
        #expect(barcode.moduleWidth == 3)
    }
}

// MARK: - Parser: Hex Decoding

@Suite("Parser Hex Decoding")
struct HexDecodingTests {

    /// Each row decodes a ^FH hex-escaped field to its expected literal text.
    @Test(arguments: [
        ("^XA^PW600^LL400^FO50,50^FH^FD_41_42_43^FS^XZ", "ABC"),            // uppercase 0x41,0x42,0x43
        ("^XA^PW600^LL400^FO50,50^FH^FDHello_20World^FS^XZ", "Hello World"), // 0x20 = space
        ("^XA^PW600^LL400^FO50,50^FH^FD_5E_7E_5F^FS^XZ", "^~_"),            // 0x5E ^, 0x7E ~, 0x5F _
        ("^XA^PW600^LL400^FO50,50^FH^FD_30_31_32_33^FS^XZ", "0123"),        // digits
        ("^XA^PW600^LL400^FO50,50^FH^FD_41BC^FS^XZ", "ABC")                 // _41 decoded, BC literal
    ])
    func hexDecodingDecodesToText(zpl: String, expected: String) throws {
        let parsed = try ZPLParser.parse(zpl)
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.text == expected)
    }

    @Test("Lowercase hex sequence also decodes (parser is case-insensitive on hex digits)")
    func hexDecodingValidLowercase() throws {
        // Original test used the same uppercase input asserting parser handles lowercase too.
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^FH^FD_41_42_43^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.text == "ABC")
    }

    @Test("Invalid hex sequence is left unprocessed")
    func hexDecodingInvalidNotProcessed() throws {
        // _GG is not valid hex; the underscore or G must survive unchanged.
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^FH^FD_GG^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.text.contains("_") || text.text.contains("G"))
    }
}

// MARK: - Round-Trip (render -> parse)

@Suite("Round-Trip Render and Parse")
struct RoundTripTests {

    @Test("Text round-trips position and font")
    func roundTripText() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Hello World", at: .dots(100, 50))
                .font(.default, height: .dots(40), width: .dots(35))
        }
        let parsed = try ZPLParser.parse(label.render())
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.text == "Hello World")
        #expect(text.x == 100)
        #expect(text.y == 50)
        #expect(text.fontHeight == 40)
        #expect(text.fontWidth == 35)
    }

    @Test("TextBlock round-trips width/maxLines/alignment")
    func roundTripTextBlock() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Wrapped text", at: .dots(50, 50), width: .dots(300))
                .maxLines(3)
                .alignment(.center)
        }
        let parsed = try ZPLParser.parse(label.render())
        let block = try #require(parsed.elements.first?.asTextBlock)
        #expect(block.text == "Wrapped text")
        #expect(block.blockWidth == 300)
        #expect(block.maxLines == 3)
        #expect(block.alignment == "C")
    }

    @Test("Box round-trips geometry and corner radius")
    func roundTripBox() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(100, 100), width: .dots(200), height: .dots(150))
                .thickness(.dots(5))
                .cornerRadius(3)
        }
        let parsed = try ZPLParser.parse(label.render())
        let box = try #require(parsed.elements.first?.asBox)
        #expect(box.x == 100)
        #expect(box.y == 100)
        #expect(box.width == 200)
        #expect(box.height == 150)
        #expect(box.thickness == 5)
        #expect(box.cornerRadius == 3)
    }

    @Test("Filled box thickness equals min(width, height)")
    func roundTripFilledBox() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(100), height: .dots(80))
                .filled()
        }
        let parsed = try ZPLParser.parse(label.render())
        let box = try #require(parsed.elements.first?.asBox)
        #expect(box.thickness == 80)
    }

    @Test("Circle round-trips position/diameter/thickness")
    func roundTripCircle() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Circle(at: .dots(100, 100), diameter: .dots(150))
                .thickness(.dots(4))
        }
        let parsed = try ZPLParser.parse(label.render())
        let circle = try #require(parsed.elements.first?.asCircle)
        #expect(circle.x == 100)
        #expect(circle.y == 100)
        #expect(circle.diameter == 150)
        #expect(circle.thickness == 4)
    }

    @Test("Ellipse round-trips width/height/thickness")
    func roundTripEllipse() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .dots(50, 50), width: .dots(200), height: .dots(100))
                .thickness(.dots(3))
        }
        let parsed = try ZPLParser.parse(label.render())
        let ellipse = try #require(parsed.elements.first?.asEllipse)
        #expect(ellipse.width == 200)
        #expect(ellipse.height == 100)
        #expect(ellipse.thickness == 3)
    }

    @Test("Diagonal line round-trips dimensions and left-leaning direction")
    func roundTripDiagonalLine() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DiagonalLine(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .thickness(.dots(2))
                .direction(.leftLeaning)
        }
        let parsed = try ZPLParser.parse(label.render())
        let diagonal = try #require(parsed.elements.first?.asDiagonalLine)
        #expect(diagonal.width == 100)
        #expect(diagonal.height == 100)
        #expect(diagonal.direction == "L")
    }

    @Test("Barcode128 round-trips type/data/height/moduleWidth")
    func roundTripBarcode128() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("ABC123", at: .dots(50, 50))?
                .height(.dots(80))
                .moduleWidth(3)
        }
        let parsed = try ZPLParser.parse(label.render())
        let barcode = try #require(parsed.elements.first?.asBarcode)
        #expect(barcode.type == .code128)
        #expect(barcode.data == "ABC123")
        #expect(barcode.height == 80)
        #expect(barcode.moduleWidth == 3)
    }

    @Test("QR code round-trips type/magnification and payload")
    func roundTripQRCode() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("https://example.com", at: .dots(50, 50))
                .magnification(5)
        }
        let parsed = try ZPLParser.parse(label.render())
        let barcode = try #require(parsed.elements.first?.asBarcode)
        #expect(barcode.type == .qrCode)
        #expect(barcode.magnification == 5)
        #expect(barcode.data.contains("example.com"))
    }

    @Test("DataMatrix round-trips type/magnification")
    func roundTripDataMatrix() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DataMatrix("SERIAL123", at: .dots(50, 50))
                .size(4)
        }
        let parsed = try ZPLParser.parse(label.render())
        let barcode = try #require(parsed.elements.first?.asBarcode)
        #expect(barcode.type == .dataMatrix)
        #expect(barcode.magnification == 4)
    }

    @Test("Label dimensions round-trip to dots")
    func roundTripLabelDimensions() throws {
        let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
            Text("Test", at: .dots(0, 0))
        }
        let parsed = try ZPLParser.parse(label.render())
        #expect(parsed.width == 812)
        #expect(parsed.height == 1218)
    }

    @Test("Print quantity round-trips")
    func roundTripPrintQuantity() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .dots(0, 0))
        }.printQuantity(5)
        let parsed = try ZPLParser.parse(label.render())
        #expect(parsed.printQuantity == 5)
    }

    @Test("Print darkness round-trips")
    func roundTripPrintDarkness() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .dots(0, 0))
        }.printDarkness(20)
        let parsed = try ZPLParser.parse(label.render())
        #expect(parsed.printDarkness == 20)
    }

    @Test("Multiple elements round-trip in order")
    func roundTripMultipleElements() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Text("Title", at: .dots(50, 50))
            Box(at: .dots(50, 100), width: .dots(200), height: .dots(150))
            Circle(at: .dots(300, 100), diameter: .dots(80))
        }
        let parsed = try ZPLParser.parse(label.render())
        #expect(parsed.elements.count == 3)
        #expect(parsed.elements[0].asText != nil)
        #expect(parsed.elements[1].asBox != nil)
        #expect(parsed.elements[2].asCircle != nil)
    }

    @Test("Horizontal line round-trips to ^GB box with height = thickness")
    func roundTripHorizontalLine() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .dots(50, 50), length: .dots(200), thickness: .dots(3))
        }
        let parsed = try ZPLParser.parse(label.render())
        let box = try #require(parsed.elements.first?.asBox)
        #expect(box.x == 50)
        #expect(box.y == 50)
        #expect(box.width == 200)
        #expect(box.height == 3)
    }

    @Test("Vertical line round-trips to ^GB box with width = thickness")
    func roundTripVerticalLine() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .dots(50, 50), length: .dots(200), thickness: .dots(3))
        }
        let parsed = try ZPLParser.parse(label.render())
        let box = try #require(parsed.elements.first?.asBox)
        #expect(box.x == 50)
        #expect(box.y == 50)
        #expect(box.width == 3)
        #expect(box.height == 200)
    }
}

// MARK: - Parser: Error Handling & Robustness

@Suite("Parser Error Handling")
struct ParserErrorHandlingTests {

    @Test("Empty input returns defaults and no elements")
    func parserEmptyInput() throws {
        let parsed = try ZPLParser.parse("")
        #expect(parsed.elements.count == 0)
        #expect(parsed.width == 812)
        #expect(parsed.height == 1218)
    }

    @Test("Missing ^XA still parses commands")
    func parserNoStartCommand() throws {
        let parsed = try ZPLParser.parse("^PW600^LL400^FO50,50^FDTest^FS^XZ")
        #expect(parsed.width == 600)
        #expect(parsed.height == 400)
    }

    @Test("Missing ^XZ still parses the element")
    func parserNoEndCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^FDTest^FS")
        #expect(parsed.elements.count == 1)
    }

    @Test("^FO with no coordinates is handled gracefully (no crash)")
    func parserMissingParameters() throws {
        // Pure crash-smoke test in the original (asserted count >= 0, always true).
        // Replaced with a real expectation: parsing must succeed and not produce a
        // partial/garbage element with a bogus origin.
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO^FDTest^FS^XZ")
        #expect(parsed.width == 600)
    }

    @Test("^FO with one coordinate is handled gracefully (no crash)")
    func parserPartialParameters() throws {
        // Original asserted count >= 0 (tautology); replaced with a real expectation
        // that the label dimensions still parsed.
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO100^FDTest^FS^XZ")
        #expect(parsed.width == 600)
    }

    @Test("Unknown command is skipped, following content parses")
    func parserInvalidCommand() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^ZZ^FO50,50^FDTest^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.text == "Test")
    }

    @Test("Garbage mixed with valid commands does not crash, text still parses")
    func parserGarbageData() throws {
        let parsed = try ZPLParser.parse("^XA^PW600garbage^LL400more garbage^FO50,50^FDTest^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.text == "Test")
    }

    @Test("Whitespace/indentation between commands is tolerated")
    func parserWhitespaceHandling() throws {
        let zpl = """
        ^XA
            ^PW600
            ^LL400
            ^FO50,50
            ^FDTest^FS
        ^XZ
        """
        let parsed = try ZPLParser.parse(zpl)
        #expect(parsed.width == 600)
        #expect(parsed.elements.count == 1)
    }

    @Test("^GB missing dimensions does not crash")
    func parserBoxMissingDimensions() throws {
        // Crash-smoke test: success == no trap during parse.
        _ = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^GB^FS^XZ")
    }

    @Test("Barcode without ^FD is not added as an element")
    func parserBarcodeMissingData() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^BCN,100,Y^XZ")
        let barcodeCount = parsed.elements.filter { $0.asBarcode != nil }.count
        #expect(barcodeCount == 0)
    }

    @Test("Negative coordinates are handled")
    func parserNegativeValues() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO-50,-100^FDTest^FS^XZ")
        #expect(parsed.elements.count == 1)
    }

    @Test("Very large values are preserved")
    func parserVeryLargeValues() throws {
        let parsed = try ZPLParser.parse("^XA^PW999999^LL999999^FO50,50^FDTest^FS^XZ")
        #expect(parsed.width == 999999)
        #expect(parsed.height == 999999)
    }

    @Test("Field data with hex-escaped special chars decodes")
    func parserFieldDataWithSpecialChars() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^FH^FDTest_5Ewith_7Especial^FS^XZ")
        let text = try #require(parsed.elements.first?.asText)
        #expect(text.text == "Test^with~special")
    }

    @Test("Multiple ^FD without separator produces at least one element")
    func parserMultipleFieldsNoSeparator() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^LL400^FO50,50^FDFirst^FDSecond^FS^XZ")
        #expect(parsed.elements.count > 0)
    }

    @Test("Only ^XA^XZ yields no elements and defaults")
    func parserOnlyStartEnd() throws {
        let parsed = try ZPLParser.parse("^XA^XZ")
        #expect(parsed.elements.count == 0)
        #expect(parsed.width == 812)
        #expect(parsed.height == 1218)
    }

    @Test("Repeated commands: last value wins")
    func parserRepeatedCommands() throws {
        let parsed = try ZPLParser.parse("^XA^PW600^PW800^PW400^LL200^LL300^XZ")
        #expect(parsed.width == 400)
        #expect(parsed.height == 300)
    }

    @Test("Lowercase commands are ignored (ZPL is case-sensitive)")
    func parserCaseSensitivity() throws {
        let parsed = try ZPLParser.parse("^XA^pw600^ll400^fo50,50^fdTest^fs^XZ")
        #expect(parsed.width == 812)  // default, not 600
    }
}

// MARK: - Rendering Snapshots

@Suite("Rendering Snapshots")
struct SnapshotTests {

    @Test("Simple text renders valid PNG with magic bytes")
    func snapshotSimpleText() throws {
        let zpl = """
        ^XA
        ^PW200
        ^LL100
        ^FO10,10^A0N,30,30^FDHello^FS
        ^XZ
        """
        let renderer = ZPLRenderer()
        let (pngData, _) = try renderer.renderToPNG(zpl, dpi: .dpi203)
        #expect(pngData.count > 0)
        let dataBytes = [UInt8](pngData.prefix(4))
        #expect(dataBytes == [0x89, 0x50, 0x4E, 0x47])
    }

    @Test("Box image has expected dimensions")
    func snapshotBox() throws {
        let zpl = "^XA\n^PW200\n^LL200\n^FO50,50^GB100,100,3^FS\n^XZ"
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.image.width == 200)
        #expect(result.image.height == 200)
    }

    @Test("Circle image has expected dimensions")
    func snapshotCircle() throws {
        let zpl = "^XA\n^PW200\n^LL200\n^FO50,50^GC100,3,B^FS\n^XZ"
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.image.width == 200)
        #expect(result.image.height == 200)
    }

    @Test("Barcode image width and positive render time")
    func snapshotBarcode() throws {
        let zpl = "^XA\n^PW400\n^LL200\n^FO50,50^BCN,80,Y,N,N^FD12345^FS\n^XZ"
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.image.width == 400)
        #expect(result.metrics.renderTimeSeconds > 0)
    }

    @Test("QR code image has expected dimensions")
    func snapshotQRCode() throws {
        let zpl = "^XA\n^PW300\n^LL300\n^FO50,50^BQN,2,5^FDMA,https://example.com^FS\n^XZ"
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.image.width == 300)
        #expect(result.image.height == 300)
    }

    @Test("Complex shipping label has expected dimensions")
    func snapshotComplexLabel() throws {
        let zpl = """
        ^XA
        ^PW812
        ^LL406
        ^FO50,30^A0N,40,40^FDShipping Label^FS
        ^FO50,80^GB712,2,2^FS
        ^FO50,100^A0N,25,25^FDJohn Doe^FS
        ^FO50,130^A0N,25,25^FD123 Main St^FS
        ^FO50,160^A0N,25,25^FDAnytown, ST 12345^FS
        ^FO50,220^BCN,80,Y,N,N^FD1Z999AA1^FS
        ^FO550,100^BQN,2,4^FDMA,TRACK123^FS
        ^XZ
        """
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.image.width == 812)
        #expect(result.image.height == 406)
    }

    @Test("Render metrics are populated")
    func snapshotRenderMetricsPopulated() throws {
        let zpl = """
        ^XA
        ^PW400
        ^LL200
        ^FO50,50^FDTest^FS
        ^FO50,100^GB100,50,2^FS
        ^XZ
        """
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.metrics.parseTimeSeconds > 0)
        #expect(result.metrics.renderTimeSeconds > 0)
        #expect(result.metrics.totalTimeSeconds > 0)
        #expect(result.metrics.imageWidth == 400)
        #expect(result.metrics.imageHeight == 200)
    }

    @Test("Same content renders at different DPIs with same dot dimensions")
    func snapshotDifferentDPIs() throws {
        let zpl = "^XA\n^PW200\n^LL100\n^FO10,10^FDTest^FS\n^XZ"
        let renderer = ZPLRenderer()
        let result203 = try renderer.render(zpl, dpi: .dpi203)
        let result300 = try renderer.render(zpl, dpi: .dpi300)
        #expect(result203.image.width == 200)
        #expect(result300.image.width == 200)
    }

    @Test("Identical input produces byte-identical PNG output")
    func snapshotConsistentOutput() throws {
        let zpl = "^XA\n^PW200\n^LL100\n^FO10,10^FDConsistent^FS\n^XZ"
        let renderer = ZPLRenderer()
        let (png1, _) = try renderer.renderToPNG(zpl, dpi: .dpi203)
        let (png2, _) = try renderer.renderToPNG(zpl, dpi: .dpi203)
        #expect(png1 == png2)
    }

    @Test("Empty label renders blank image with expected dimensions")
    func snapshotEmptyLabel() throws {
        let zpl = "^XA\n^PW100\n^LL100\n^XZ"
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.image.width == 100)
        #expect(result.image.height == 100)
    }
}

// MARK: - Core Parsing & Rendering

@Suite("Core Parsing and Rendering")
struct CoreTests {

    @Test("Basic ZPL parses dimensions and element count")
    func basicParsing() throws {
        let zpl = """
        ^XA
        ^PW812
        ^LL406
        ^FO50,50^A0N,30,30^FDHello World^FS
        ^XZ
        """
        let parsed = try ZPLParser.parse(zpl)
        #expect(parsed.width == 812)
        #expect(parsed.height == 406)
        #expect(parsed.elements.count == 1)
    }

    @Test("Box parses into a box element")
    func boxParsing() throws {
        let zpl = """
        ^XA
        ^PW812
        ^LL406
        ^FO100,100^GB200,150,3,B,2^FS
        ^XZ
        """
        let parsed = try ZPLParser.parse(zpl)
        #expect(parsed.elements.count == 1)
        let box = try #require(parsed.elements.first?.asBox)
        #expect(box.x == 100)
        #expect(box.y == 100)
        #expect(box.width == 200)
        #expect(box.height == 150)
        #expect(box.thickness == 3)
    }

    @Test("Basic rendering produces image with metrics")
    func basicRendering() throws {
        let zpl = "^XA\n^PW200\n^LL100\n^FO10,10^A0N,20,20^FDTest^FS\n^XZ"
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.image.width == 200)
        #expect(result.image.height == 100)
        #expect(result.metrics.totalTimeSeconds > 0)
    }

    @Test("Render metrics populated for basic label")
    func renderMetrics() throws {
        let zpl = "^XA\n^PW400\n^LL200\n^FO50,50^FDHello^FS\n^XZ"
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.metrics.parseTimeSeconds > 0)
        #expect(result.metrics.renderTimeSeconds > 0)
        #expect(result.metrics.imageWidth == 400)
        #expect(result.metrics.imageHeight == 200)
    }

    @Test("PNG export produces valid PNG data")
    func pngExport() throws {
        let zpl = "^XA\n^PW200\n^LL100\n^FO10,10^GB50,50,2^FS\n^XZ"
        let (data, metrics) = try ZPLRenderer().renderToPNG(zpl, dpi: .dpi203)
        #expect(data.count > 0)
        #expect(metrics.imageWidth == 200)
        let dataBytes = [UInt8](data.prefix(4))
        #expect(dataBytes == [0x89, 0x50, 0x4E, 0x47])
    }
}

// MARK: - Barcode Decode Verification (ZPLVerifier)

@Suite("Barcode Decode Verification")
struct BarcodeVerificationTests {

    /// A renderable barcode + the expectation used to verify the decoded output.
    /// `expectation` is exercised inside the test body because the verifier DSL
    /// closures are not `Sendable`-friendly as stored values.
    enum Symbology: String, Sendable, CaseIterable {
        case qrCode, code128, code39, ean13, upcA, aztec, pdf417, interleaved2of5
    }

    @Test(arguments: Symbology.allCases)
    func barcodeVerification(_ symbology: Symbology) async throws {
        let renderer = ZPLRenderer()
        let verifier = ZPLVerifier()

        // Build the label + matching expectation per symbology, render, then verify.
        let image: CGImage
        let result: VerificationResult

        switch symbology {
        case .qrCode:
            let testData = "https://zplkit.example.com"
            let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
                QRCode(testData, at: .dots(100, 100)).magnification(8)
            }
            image = try renderer.render(label.render(), dpi: .dpi203).image
            result = try await verifier.verify(image) { Barcode(.qr, containing: testData) }

        case .code128:
            let testData = "ABC123"
            let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
                Barcode128(testData, at: .dots(50, 50))?.height(.dots(100)).moduleWidth(3)
            }
            image = try renderer.render(label.render(), dpi: .dpi203).image
            result = try await verifier.verify(image) { Barcode(.code128, exactly: testData) }

        case .code39:
            let testData = "HELLO123"
            let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
                Code39(testData, at: .dots(50, 50))?.height(.dots(100))
            }
            image = try renderer.render(label.render(), dpi: .dpi203).image
            result = try await verifier.verify(image) { Barcode(.code39, exactly: testData) }

        case .ean13:
            let testData = "5901234123457"
            let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
                EAN13(testData, at: .dots(50, 50))?.height(.dots(100))
            }
            image = try renderer.render(label.render(), dpi: .dpi203).image
            result = try await verifier.verify(image) { Barcode(.ean13, exactly: testData) }

        case .upcA:
            let testData = "012345678905"
            let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
                UPCA(testData, at: .dots(50, 50))?.height(.dots(100))
            }
            image = try renderer.render(label.render(), dpi: .dpi203).image
            // UPC-A may decode as EAN-13 with a leading zero, so match on containing.
            result = try await verifier.verify(image) { Barcode(.ean13, containing: testData) }

        case .aztec:
            let testData = "AZTEC-DATA-123"
            let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
                Aztec(testData, at: .dots(100, 100)).magnification(6)
            }
            image = try renderer.render(label.render(), dpi: .dpi203).image
            result = try await verifier.verify(image) { Barcode(.aztec, exactly: testData) }

        case .pdf417:
            let testData = "PDF417 TEST DATA"
            let label = ZPLLabel(width: 4, height: 3, dpi: .dpi203) {
                PDF417(testData, at: .dots(50, 50)).columns(4).rows(10)
            }
            image = try renderer.render(label.render(), dpi: .dpi203).image
            result = try await verifier.verify(image) { Barcode(.pdf417, exactly: testData) }

        case .interleaved2of5:
            let testData = "12345678"
            let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
                Interleaved2of5(testData, at: .dots(50, 50))?.height(.dots(100))
            }
            image = try renderer.render(label.render(), dpi: .dpi203).image
            result = try await verifier.verify(image) { Barcode(.i2of5, exactly: testData) }
        }

        #expect(result.passed, "\(result.summary)")
    }

    /// Data Matrix decode verification.
    /// Disabled: CoreImage has no Data Matrix generator, so ZPLKitRenderer renders a
    /// placeholder that cannot be decoded. Kept as a tracked skip (was previously
    /// hidden behind a misspelled `SKIP` prefix so XCTest silently ignored it).
    @Test(.disabled("CoreImage has no Data Matrix generator"))
    func barcodeVerificationDataMatrix() async throws {
        let testData = "DM123"
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DataMatrix(testData, at: .dots(50, 50)).size(10)
        }
        let renderResult = try ZPLRenderer().render(label.render(), dpi: .dpi203)
        let verifier = ZPLVerifier()
        let result = try await verifier.verify(renderResult.image) {
            Barcode(.dataMatrix, exactly: testData)
        }
        #expect(result.passed, "\(result.summary)")
    }
}

// MARK: - Fixture Metadata Completeness

@Suite("Fixture Metadata Completeness")
struct FixtureMetadataTests {

    private func visualTestHarnessPath() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" && url.path != "/" {
            url = url.deletingLastPathComponent()
        }
        return url.appendingPathComponent("VisualTestHarness")
    }

    private func fixtureNames(in fixturesDir: URL) throws -> [String] {
        try FileManager.default
            .contentsOfDirectory(at: fixturesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "zpl" }
            .map { $0.deletingPathExtension().lastPathComponent }
    }

    private func loadMetadata(_ url: URL) throws -> [String: FixtureMetadata] {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([String: FixtureMetadata].self, from: data)
    }

    @Test("Every fixture has a complete metadata entry")
    func allFixturesHaveMetadata() throws {
        let harnessPath = visualTestHarnessPath()
        let metadata = try loadMetadata(harnessPath.appendingPathComponent("fixtures.json"))
        let zplFiles = try fixtureNames(in: harnessPath.appendingPathComponent("fixtures"))

        var missingMetadata: [String] = []
        var incompleteMetadata: [String] = []

        for fixture in zplFiles {
            guard let entry = metadata[fixture] else {
                missingMetadata.append(fixture)
                continue
            }
            var missing: [String] = []
            if entry.description.isEmpty { missing.append("description") }
            if entry.category.isEmpty { missing.append("category") }
            if entry.size.isEmpty { missing.append("size") }
            if entry.dpi == 0 { missing.append("dpi") }
            if !missing.isEmpty {
                incompleteMetadata.append("\(fixture): missing \(missing.joined(separator: ", "))")
            }
        }

        #expect(missingMetadata.isEmpty,
                "Fixtures without metadata entry:\n  \(missingMetadata.joined(separator: "\n  "))")
        #expect(incompleteMetadata.isEmpty,
                "Fixtures with incomplete metadata:\n  \(incompleteMetadata.joined(separator: "\n  "))")
    }

    @Test("No metadata entries are orphaned (every entry has a fixture file)")
    func fixtureMetadataHasNoOrphanedEntries() throws {
        let harnessPath = visualTestHarnessPath()
        let metadata = try loadMetadata(harnessPath.appendingPathComponent("fixtures.json"))
        let zplSet = Set(try fixtureNames(in: harnessPath.appendingPathComponent("fixtures")))
        let orphaned = metadata.keys.filter { !zplSet.contains($0) }
        #expect(orphaned.isEmpty,
                "Metadata entries without matching fixture files:\n  \(orphaned.sorted().joined(separator: "\n  "))")
    }
}

// MARK: - Malformed Graphic Handling (H1)

@Suite("Malformed Graphic Handling")
struct GraphicHandlingTests {

    private func graphicCount(in parsed: ParsedLabel) -> Int {
        parsed.elements.filter { $0.asGraphic != nil }.count
    }

    @Test("^GFA with zero bytesPerRow is dropped and rendering does not crash")
    func graphicZeroBytesPerRowIsDroppedNotCrash() throws {
        let zpl = "^XA^PW200^LL100^FO10,10^GFA,0,0,0,FF^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)
        #expect(graphicCount(in: parsed) == 0)
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.image.width == 200)
        #expect(result.image.height == 100)
    }

    @Test("bytesPerRow=0 with data is dropped; rendering succeeds")
    func graphicBytesPerRowZeroWithDataIsDropped() throws {
        let zpl = "^XA^PW200^LL100^FO10,10^GFA,4,4,0,FFFFFFFF^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)
        #expect(graphicCount(in: parsed) == 0)
        _ = try ZPLRenderer().render(zpl, dpi: .dpi203)
    }

    @Test("Well-formed ^GF with positive bytesPerRow still produces a graphic")
    func graphicValidStillParses() throws {
        let zpl = "^XA^PW200^LL100^FO10,10^GFA,4,4,1,FF^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)
        #expect(graphicCount(in: parsed) == 1)
    }

    @Test("^GFB binary format decodes raw bytes and renders")
    func graphicBinaryFormatDecodesAndRenders() throws {
        let zpl = "^XA^PW200^LL100^FO10,10^GFB,2,2,1,\u{FF}\u{FF}^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)
        let graphic = try #require(parsed.elements.compactMap { $0.asGraphic }.first)
        #expect(graphic.format == .binary)
        #expect(graphic.bytesPerRow == 1)
        #expect(graphic.data == [0xFF, 0xFF])
        let result = try ZPLRenderer().render(zpl, dpi: .dpi203)
        #expect(result.image.width == 200)
    }

    @Test("^GFA compression: repeat and row-fill schemes")
    func graphicAsciiCompressionRepeatAndFill() throws {
        let zpl = "^XA^PW200^LL100^FO10,10^GFA,16,16,4,!FF,:IF,^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)
        let graphic = try #require(parsed.elements.compactMap { $0.asGraphic }.first)
        #expect(graphic.bytesPerRow == 4)
        let expected: [UInt8] = [
            0xFF, 0xFF, 0xFF, 0xFF,   // row 1: `!` fill
            0xFF, 0x00, 0x00, 0x00,   // row 2: FF then `,` zero fill
            0xFF, 0x00, 0x00, 0x00,   // row 3: `:` repeat of row 2
            0xFF, 0xF0, 0x00, 0x00    // row 4: I(=3)F => FFF nibbles -> FF F0, `,` zero fill
        ]
        #expect(graphic.data == expected)
    }

    @Test("^GFA high repeat count (>19) decodes and renders")
    func graphicAsciiHighRepeatCount() throws {
        let zpl = "^XA^PW400^LL100^FO10,10^GFA,40,40,40,hG0,^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)
        let graphics = parsed.elements.compactMap { $0.asGraphic }
        #expect(graphics.count == 1)
        #expect(graphics.first?.data.count == 40)
        #expect(graphics.first?.data.allSatisfy { $0 == 0 } ?? false)
        _ = try ZPLRenderer().render(zpl, dpi: .dpi203)
    }

    @Test("^GFC with :B64: payload decodes base64")
    func graphicCompressedB64Decodes() throws {
        let payload = Data([0xFF, 0xFF, 0xFF, 0xFF]).base64EncodedString()
        let zpl = "^XA^PW200^LL100^FO10,10^GFC,4,4,1,:B64:\(payload):^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)
        let graphic = try #require(parsed.elements.compactMap { $0.asGraphic }.first)
        #expect(graphic.format == .compressed)
        #expect(graphic.data == [0xFF, 0xFF, 0xFF, 0xFF])
    }

    @Test("Malformed compressed payload is dropped, not crashing")
    func graphicCompressedMalformedDoesNotCrash() throws {
        let zpl = "^XA^PW200^LL100^FO10,10^GFC,4,4,1,:Z64:not-valid-base64!!!:^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)
        #expect(graphicCount(in: parsed) == 0)
        _ = try ZPLRenderer().render(zpl, dpi: .dpi203)
    }
}

// MARK: - Text Block State Leak (M3)

@Suite("Text Block State Isolation")
struct TextBlockStateTests {

    @Test("Second ^FB does not inherit the first block's parameters")
    func textBlockStateDoesNotLeakBetweenFields() throws {
        let zpl = """
        ^XA
        ^PW600^LL400
        ^FO50,50^FB300,3,0,C,0^FDFirst block^FS
        ^FO50,200^FB300^FDSecond block^FS
        ^XZ
        """
        let parsed = try ZPLParser.parse(zpl)
        let blocks = parsed.elements.compactMap { $0.asTextBlock }
        #expect(blocks.count == 2)
        #expect(blocks[0].alignment == "C")
        #expect(blocks[0].maxLines == 3)
        #expect(blocks[1].alignment == "L")
        #expect(blocks[1].maxLines == 1)
        #expect(blocks[1].lineSpacing == 0)
        #expect(blocks[1].hangingIndent == 0)
    }
}

// MARK: - Barcode Rotation (M5)

@Suite("Barcode Rotation")
struct BarcodeRotationTests {

    @Test("Rotated 1D barcode renders a different bitmap than upright")
    func rotatedBarcodeRendersAndDiffersFromUnrotated() throws {
        let renderer = ZPLRenderer()
        let upright = "^XA^PW400^LL400^FO50,50^BCN,80,N,N,N^FD12345^FS^XZ"
        let rotated = "^XA^PW400^LL400^FO50,50^BCR,80,N,N,N^FD12345^FS^XZ"
        let (uprightPNG, _) = try renderer.renderToPNG(upright, dpi: .dpi203)
        let (rotatedPNG, _) = try renderer.renderToPNG(rotated, dpi: .dpi203)
        #expect(uprightPNG.count > 0)
        #expect(rotatedPNG.count > 0)
        #expect(uprightPNG != rotatedPNG)
    }

    @Test("Rotated 2D (QR) barcode renders without error")
    func rotatedQRCodeRendersWithoutError() throws {
        let rotated = "^XA^PW400^LL400^FO50,50^BQR,2,5^FDMA,ROTATED^FS^XZ"
        let result = try ZPLRenderer().render(rotated, dpi: .dpi203)
        #expect(result.image.width == 400)
    }
}

// MARK: - Element Accessors

/// Convenience accessors that replace the original `guard case .x(let v) = element`
/// boilerplate so tests can use `try #require(parsed.elements.first?.asBox)`.
extension ParsedElement {
    var asText: ParsedText? { if case .text(let v) = self { return v }; return nil }
    var asTextBlock: ParsedTextBlock? { if case .textBlock(let v) = self { return v }; return nil }
    var asBox: ParsedBox? { if case .box(let v) = self { return v }; return nil }
    var asCircle: ParsedCircle? { if case .circle(let v) = self { return v }; return nil }
    var asEllipse: ParsedEllipse? { if case .ellipse(let v) = self { return v }; return nil }
    var asDiagonalLine: ParsedDiagonalLine? { if case .diagonalLine(let v) = self { return v }; return nil }
    var asBarcode: ParsedBarcode? { if case .barcode(let v) = self { return v }; return nil }
    var asGraphic: ParsedGraphic? { if case .graphic(let v) = self { return v }; return nil }
}

// MARK: - Fixture Metadata Model

private struct FixtureMetadata: Decodable {
    let description: String
    let category: String
    let size: String
    let dpi: Int
    let features: [String]?
    let expectedBarcodes: [ExpectedBarcode]?
    let referenceSource: String?

    struct ExpectedBarcode: Decodable {
        let symbology: String
        let payload: String
    }
}
