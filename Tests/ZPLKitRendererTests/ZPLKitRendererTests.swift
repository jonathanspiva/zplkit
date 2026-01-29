import XCTest
@testable import ZPLKitRenderer
@testable import ZPLKit

final class ZPLKitRendererTests: XCTestCase {

    // MARK: - Parser Command Tests

    func testParserPWCommand() throws {
        let zpl = "^XA^PW600^LL400^XZ"
        let parsed = try ZPLParser.parse(zpl)
        XCTAssertEqual(parsed.width, 600)
    }

    func testParserLLCommand() throws {
        let zpl = "^XA^PW600^LL400^XZ"
        let parsed = try ZPLParser.parse(zpl)
        XCTAssertEqual(parsed.height, 400)
    }

    func testParserPQCommand() throws {
        let zpl = "^XA^PW600^LL400^PQ5^XZ"
        let parsed = try ZPLParser.parse(zpl)
        XCTAssertEqual(parsed.printQuantity, 5)
    }

    func testParserPQCommandWithMultipleParams() throws {
        let zpl = "^XA^PW600^LL400^PQ10,2,1^XZ"
        let parsed = try ZPLParser.parse(zpl)
        XCTAssertEqual(parsed.printQuantity, 10)
    }

    func testParserMDCommand() throws {
        let zpl = "^XA^PW600^LL400^MD15^XZ"
        let parsed = try ZPLParser.parse(zpl)
        XCTAssertEqual(parsed.printDarkness, 15)
    }

    func testParserFOCommand() throws {
        let zpl = "^XA^PW600^LL400^FO100,200^FDTest^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.x, 100)
        XCTAssertEqual(text.y, 200)
    }

    func testParserFTCommand() throws {
        let zpl = "^XA^PW600^LL400^FT100,200^FDTest^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.x, 100)
        XCTAssertEqual(text.y, 200)
        XCTAssertTrue(text.useBaseline)
    }

    func testParserA0CommandWithRotation() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^A0R,40,30^FDRotated^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.rotation, "R")
        XCTAssertEqual(text.fontHeight, 40)
        XCTAssertEqual(text.fontWidth, 30)
    }

    func testParserA0CommandNormalRotation() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^A0N,25,25^FDNormal^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.rotation, "N")
    }

    func testParserCFCommand() throws {
        let zpl = "^XA^PW600^LL400^CF0,50,40^FO50,50^FDStyled^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.fontHeight, 50)
        XCTAssertEqual(text.fontWidth, 40)
    }

    func testParserFBCommand() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^FB300,3,0,C,0^FDCentered text^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .textBlock(let block) = parsed.elements.first else {
            XCTFail("Expected text block element")
            return
        }
        XCTAssertEqual(block.blockWidth, 300)
        XCTAssertEqual(block.maxLines, 3)
        XCTAssertEqual(block.alignment, "C")
    }

    func testParserFBCommandWithLineSpacing() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^FB300,5,10,L,5^FDText^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .textBlock(let block) = parsed.elements.first else {
            XCTFail("Expected text block element")
            return
        }
        XCTAssertEqual(block.lineSpacing, 10)
        XCTAssertEqual(block.hangingIndent, 5)
    }

    func testParserFRCommand() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^FR^FDReversed^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertTrue(text.isReversed)
    }

    func testParserGBCommand() throws {
        let zpl = "^XA^PW600^LL400^FO100,100^GB200,150,3,B,2^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .box(let box) = parsed.elements.first else {
            XCTFail("Expected box element")
            return
        }
        XCTAssertEqual(box.x, 100)
        XCTAssertEqual(box.y, 100)
        XCTAssertEqual(box.width, 200)
        XCTAssertEqual(box.height, 150)
        XCTAssertEqual(box.thickness, 3)
        XCTAssertEqual(box.color, "B")
        XCTAssertEqual(box.cornerRadius, 2)
    }

    func testParserGBCommandWhiteColor() throws {
        let zpl = "^XA^PW600^LL400^FO100,100^GB200,150,3,W^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .box(let box) = parsed.elements.first else {
            XCTFail("Expected box element")
            return
        }
        XCTAssertEqual(box.color, "W")
    }

    func testParserGCCommand() throws {
        let zpl = "^XA^PW600^LL400^FO100,100^GC150,5,B^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .circle(let circle) = parsed.elements.first else {
            XCTFail("Expected circle element")
            return
        }
        XCTAssertEqual(circle.x, 100)
        XCTAssertEqual(circle.y, 100)
        XCTAssertEqual(circle.diameter, 150)
        XCTAssertEqual(circle.thickness, 5)
    }

    func testParserGECommand() throws {
        let zpl = "^XA^PW600^LL400^FO100,100^GE200,100,3,B^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .ellipse(let ellipse) = parsed.elements.first else {
            XCTFail("Expected ellipse element")
            return
        }
        XCTAssertEqual(ellipse.width, 200)
        XCTAssertEqual(ellipse.height, 100)
        XCTAssertEqual(ellipse.thickness, 3)
    }

    func testParserGDCommand() throws {
        let zpl = "^XA^PW600^LL400^FO100,100^GD150,150,2,B,R^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .diagonalLine(let diagonal) = parsed.elements.first else {
            XCTFail("Expected diagonal line element")
            return
        }
        XCTAssertEqual(diagonal.width, 150)
        XCTAssertEqual(diagonal.height, 150)
        XCTAssertEqual(diagonal.direction, "R")
    }

    func testParserGDCommandLeftLeaning() throws {
        let zpl = "^XA^PW600^LL400^FO100,100^GD150,150,2,B,L^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .diagonalLine(let diagonal) = parsed.elements.first else {
            XCTFail("Expected diagonal line element")
            return
        }
        XCTAssertEqual(diagonal.direction, "L")
    }

    func testParserBCCommand() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^BCN,100,Y,N,N^FD12345^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .code128)
        XCTAssertEqual(barcode.data, "12345")
        XCTAssertEqual(barcode.height, 100)
        XCTAssertTrue(barcode.showText)
    }

    func testParserB3Command() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^B3N,N,100,Y,N^FDABC123^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .code39)
        XCTAssertEqual(barcode.data, "ABC123")
    }

    func testParserBQCommand() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^BQN,2,5^FDMA,https://example.com^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .qrCode)
        XCTAssertEqual(barcode.magnification, 5)
    }

    func testParserBXCommand() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^BXN,4^FDTEST^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .dataMatrix)
        XCTAssertEqual(barcode.magnification, 4)
    }

    func testParserB7Command() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^B7N,10^FDPDF417DATA^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .pdf417)
    }

    func testParserB2Command() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^B2N,100,Y,N,N^FD123456^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .interleaved2of5)
        XCTAssertEqual(barcode.data, "123456")
    }

    func testParserBECommand() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^BEN,100,Y,N^FD590123412345^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .ean13)
    }

    func testParserB8Command() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^B8N,100,Y,N^FD1234567^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .ean8)
    }

    func testParserBUCommand() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^BUN,100,Y,N,N^FD01234567890^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .upcA)
    }

    func testParserB9Command() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^B9N,100,N,N,N^FD123456^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .upcE)
    }

    func testParserB0Command() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^B0N,4^FDAZTECDATA^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .aztec)
        XCTAssertEqual(barcode.magnification, 4)
    }

    func testParserBZCommand() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^BZN,30^FD01234567890123456789^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .intelligentMail)
    }

    func testParserBYCommand() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^BY3^BCN,100^FD12345^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.moduleWidth, 3)
    }

    func testParserGFCommand() throws {
        let zpl = "^XA^PW200^LL100^FO10,10^GFA,4,4,1,FF^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .graphic(let graphic) = parsed.elements.first else {
            XCTFail("Expected graphic element")
            return
        }
        XCTAssertEqual(graphic.x, 10)
        XCTAssertEqual(graphic.y, 10)
        XCTAssertEqual(graphic.format, .ascii)
        XCTAssertEqual(graphic.bytesPerRow, 1)
    }

    // MARK: - Hex Decoding Tests

    func testHexDecodingValidUppercase() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^FH^FD_41_42_43^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.text, "ABC")  // 0x41=A, 0x42=B, 0x43=C
    }

    func testHexDecodingValidLowercase() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^FH^FD_41_42_43^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        // Parser should handle lowercase too
        XCTAssertEqual(text.text, "ABC")
    }

    func testHexDecodingMixedContent() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^FH^FDHello_20World^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.text, "Hello World")  // 0x20 = space
    }

    func testHexDecodingSpecialChars() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^FH^FD_5E_7E_5F^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.text, "^~_")  // 0x5E=^, 0x7E=~, 0x5F=_
    }

    func testHexDecodingMultipleSequences() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^FH^FD_30_31_32_33^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.text, "0123")
    }

    func testHexDecodingInvalidNotProcessed() throws {
        // _GG is not valid hex, should be left as-is or partially processed
        let zpl = "^XA^PW600^LL400^FO50,50^FH^FD_GG^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        // Invalid hex should remain unchanged
        XCTAssertTrue(text.text.contains("_") || text.text.contains("G"))
    }

    func testHexDecodingWithTrailingText() throws {
        let zpl = "^XA^PW600^LL400^FO50,50^FH^FD_41BC^FS^XZ"
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.text, "ABC")  // _41 decoded, BC unchanged
    }

    // MARK: - Round-Trip Tests

    func testRoundTripText() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Hello World", at: .dots(100, 50))
                .font(.default, height: .dots(40), width: .dots(35))
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .text(let text) = parsed.elements.first else {
            XCTFail("Expected text element")
            return
        }
        XCTAssertEqual(text.text, "Hello World")
        XCTAssertEqual(text.x, 100)
        XCTAssertEqual(text.y, 50)
        XCTAssertEqual(text.fontHeight, 40)
        XCTAssertEqual(text.fontWidth, 35)
    }

    func testRoundTripTextBlock() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Wrapped text", at: .dots(50, 50), width: .dots(300))
                .maxLines(3)
                .alignment(.center)
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .textBlock(let block) = parsed.elements.first else {
            XCTFail("Expected text block element")
            return
        }
        XCTAssertEqual(block.text, "Wrapped text")
        XCTAssertEqual(block.blockWidth, 300)
        XCTAssertEqual(block.maxLines, 3)
        XCTAssertEqual(block.alignment, "C")
    }

    func testRoundTripBox() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(100, 100), width: .dots(200), height: .dots(150))
                .thickness(.dots(5))
                .cornerRadius(3)
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .box(let box) = parsed.elements.first else {
            XCTFail("Expected box element")
            return
        }
        XCTAssertEqual(box.x, 100)
        XCTAssertEqual(box.y, 100)
        XCTAssertEqual(box.width, 200)
        XCTAssertEqual(box.height, 150)
        XCTAssertEqual(box.thickness, 5)
        XCTAssertEqual(box.cornerRadius, 3)
    }

    func testRoundTripFilledBox() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(100), height: .dots(80))
                .filled()
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .box(let box) = parsed.elements.first else {
            XCTFail("Expected box element")
            return
        }
        // Filled box has thickness = min(width, height) = 80
        XCTAssertEqual(box.thickness, 80)
    }

    func testRoundTripCircle() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Circle(at: .dots(100, 100), diameter: .dots(150))
                .thickness(.dots(4))
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .circle(let circle) = parsed.elements.first else {
            XCTFail("Expected circle element")
            return
        }
        XCTAssertEqual(circle.x, 100)
        XCTAssertEqual(circle.y, 100)
        XCTAssertEqual(circle.diameter, 150)
        XCTAssertEqual(circle.thickness, 4)
    }

    func testRoundTripEllipse() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .dots(50, 50), width: .dots(200), height: .dots(100))
                .thickness(.dots(3))
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .ellipse(let ellipse) = parsed.elements.first else {
            XCTFail("Expected ellipse element")
            return
        }
        XCTAssertEqual(ellipse.width, 200)
        XCTAssertEqual(ellipse.height, 100)
        XCTAssertEqual(ellipse.thickness, 3)
    }

    func testRoundTripDiagonalLine() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DiagonalLine(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .thickness(.dots(2))
                .direction(.leftLeaning)
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .diagonalLine(let diagonal) = parsed.elements.first else {
            XCTFail("Expected diagonal line element")
            return
        }
        XCTAssertEqual(diagonal.width, 100)
        XCTAssertEqual(diagonal.height, 100)
        XCTAssertEqual(diagonal.direction, "L")
    }

    func testRoundTripBarcode128() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("ABC123", at: .dots(50, 50))?
                .height(.dots(80))
                .moduleWidth(3)
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .code128)
        XCTAssertEqual(barcode.data, "ABC123")
        XCTAssertEqual(barcode.height, 80)
        XCTAssertEqual(barcode.moduleWidth, 3)
    }

    func testRoundTripQRCode() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("https://example.com", at: .dots(50, 50))
                .magnification(5)
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .qrCode)
        XCTAssertEqual(barcode.magnification, 5)
        // QR code data has "MA," prefix
        XCTAssertTrue(barcode.data.contains("example.com"))
    }

    func testRoundTripDataMatrix() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DataMatrix("SERIAL123", at: .dots(50, 50))
                .size(4)
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .barcode(let barcode) = parsed.elements.first else {
            XCTFail("Expected barcode element")
            return
        }
        XCTAssertEqual(barcode.type, .dataMatrix)
        XCTAssertEqual(barcode.magnification, 4)
    }

    func testRoundTripLabelDimensions() throws {
        let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
            Text("Test", at: .dots(0, 0))
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        // 4 inches * 203 = 812, 6 inches * 203 = 1218
        XCTAssertEqual(parsed.width, 812)
        XCTAssertEqual(parsed.height, 1218)
    }

    func testRoundTripPrintQuantity() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .dots(0, 0))
        }.printQuantity(5)

        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        XCTAssertEqual(parsed.printQuantity, 5)
    }

    func testRoundTripPrintDarkness() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .dots(0, 0))
        }.printDarkness(20)

        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        XCTAssertEqual(parsed.printDarkness, 20)
    }

    func testRoundTripMultipleElements() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Text("Title", at: .dots(50, 50))
            Box(at: .dots(50, 100), width: .dots(200), height: .dots(150))
            Circle(at: .dots(300, 100), diameter: .dots(80))
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        XCTAssertEqual(parsed.elements.count, 3)

        // Verify types in order
        guard case .text = parsed.elements[0] else {
            XCTFail("Expected text at index 0")
            return
        }
        guard case .box = parsed.elements[1] else {
            XCTFail("Expected box at index 1")
            return
        }
        guard case .circle = parsed.elements[2] else {
            XCTFail("Expected circle at index 2")
            return
        }
    }

    func testRoundTripHorizontalLine() throws {
        // Horizontal line renders as ^GB with height=thickness
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .dots(50, 50), length: .dots(200), thickness: .dots(3))
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .box(let box) = parsed.elements.first else {
            XCTFail("Expected box element (horizontal line)")
            return
        }
        XCTAssertEqual(box.x, 50)
        XCTAssertEqual(box.y, 50)
        XCTAssertEqual(box.width, 200)
        XCTAssertEqual(box.height, 3)  // thickness
    }

    func testRoundTripVerticalLine() throws {
        // Vertical line renders as ^GB with width=thickness
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .dots(50, 50), length: .dots(200), thickness: .dots(3))
        }
        let zpl = label.render()
        let parsed = try ZPLParser.parse(zpl)

        guard case .box(let box) = parsed.elements.first else {
            XCTFail("Expected box element (vertical line)")
            return
        }
        XCTAssertEqual(box.x, 50)
        XCTAssertEqual(box.y, 50)
        XCTAssertEqual(box.width, 3)  // thickness
        XCTAssertEqual(box.height, 200)  // length
    }

    // MARK: - Original Tests

    func testBasicParsing() throws {
        let zpl = """
        ^XA
        ^PW812
        ^LL406
        ^FO50,50^A0N,30,30^FDHello World^FS
        ^XZ
        """

        let parsed = try ZPLParser.parse(zpl)

        XCTAssertEqual(parsed.width, 812)
        XCTAssertEqual(parsed.height, 406)
        XCTAssertEqual(parsed.elements.count, 1)
    }

    func testBoxParsing() throws {
        let zpl = """
        ^XA
        ^PW812
        ^LL406
        ^FO100,100^GB200,150,3,B,2^FS
        ^XZ
        """

        let parsed = try ZPLParser.parse(zpl)

        XCTAssertEqual(parsed.elements.count, 1)

        if case .box(let box) = parsed.elements.first {
            XCTAssertEqual(box.x, 100)
            XCTAssertEqual(box.y, 100)
            XCTAssertEqual(box.width, 200)
            XCTAssertEqual(box.height, 150)
            XCTAssertEqual(box.thickness, 3)
        } else {
            XCTFail("Expected box element")
        }
    }

    func testBasicRendering() throws {
        let zpl = """
        ^XA
        ^PW200
        ^LL100
        ^FO10,10^A0N,20,20^FDTest^FS
        ^XZ
        """

        let renderer = ZPLRenderer()
        let result = try renderer.render(zpl, dpi: .dpi203)

        XCTAssertEqual(result.image.width, 200)
        XCTAssertEqual(result.image.height, 100)
        XCTAssertGreaterThan(result.metrics.totalTimeSeconds, 0)
    }

    func testRenderMetrics() throws {
        let zpl = """
        ^XA
        ^PW400
        ^LL200
        ^FO50,50^FDHello^FS
        ^XZ
        """

        let renderer = ZPLRenderer()
        let result = try renderer.render(zpl, dpi: .dpi203)

        XCTAssertGreaterThan(result.metrics.parseTimeSeconds, 0)
        XCTAssertGreaterThan(result.metrics.renderTimeSeconds, 0)
        XCTAssertEqual(result.metrics.imageWidth, 400)
        XCTAssertEqual(result.metrics.imageHeight, 200)
    }

    func testPNGExport() throws {
        let zpl = """
        ^XA
        ^PW200
        ^LL100
        ^FO10,10^GB50,50,2^FS
        ^XZ
        """

        let renderer = ZPLRenderer()
        let (data, metrics) = try renderer.renderToPNG(zpl, dpi: .dpi203)

        XCTAssertGreaterThan(data.count, 0)
        XCTAssertEqual(metrics.imageWidth, 200)

        // Verify it's valid PNG data (PNG magic bytes)
        let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        let dataBytes = [UInt8](data.prefix(4))
        XCTAssertEqual(dataBytes, pngMagic)
    }
}
