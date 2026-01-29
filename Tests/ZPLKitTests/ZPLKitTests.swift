import XCTest
@testable import ZPLKit

final class ZPLKitTests: XCTestCase {

    func testBasicLabelRenders() {
        let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
            Text("Hello World", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^XA"))
        XCTAssertTrue(zpl.contains("^XZ"))
        XCTAssertTrue(zpl.contains("^FDHello World^FS"))
    }

    func testLabelDimensionsCorrect() {
        let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
            Text("Test", at: .dots(0, 0))
        }

        let zpl = label.render()
        // 4 inches * 203 DPI = 812 dots
        XCTAssertTrue(zpl.contains("^PW812"))
        // 6 inches * 203 DPI = 1218 dots
        XCTAssertTrue(zpl.contains("^LL1218"))
    }

    func testTextWithFont() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Styled", at: .inches(0.5, 0.5))
                .font(.default, height: .dots(50), width: .dots(40))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^A0N,50,40"))
    }

    func testTextRotation() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Rotated", at: .inches(0.5, 0.5))
                .rotated(.rotated90)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^A0R"))
    }

    func testBarcode128Valid() {
        let barcode = Barcode128("ABC123", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testBarcode128Invalid() {
        let barcode = Barcode128("ABC\u{0080}123", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testCode39Valid() {
        let barcode = Code39("HELLO-123", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testCode39Invalid() {
        let barcode = Code39("hello@world", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testCode39Uppercases() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Code39("abc123", at: .inches(0.5, 0.5))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FDABC123^FS"))
    }

    func testQRCodeRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("https://example.com", at: .inches(0.5, 0.5))
                .magnification(5)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BQN,2,5"))
    }

    func testDataMatrixRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DataMatrix("SERIAL123", at: .inches(0.5, 0.5))
                .size(5)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BXN,5"))
    }

    func testBoxRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .inches(0.25, 0.25), width: .inches(1.0), height: .inches(0.5))
                .thickness(3)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GB"))
    }

    func testFilledBoxRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .inches(0.25, 0.25), width: .dots(100), height: .dots(50))
                .filled()
        }

        let zpl = label.render()
        // Filled box has thickness equal to min(width, height)
        XCTAssertTrue(zpl.contains("^GB100,50,50"))
    }

    func testHorizontalLineRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .inches(0.25, 0.5), length: .inches(2.0))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GB"))
    }

    func testTextBlockRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("This is a long text that should wrap", at: .inches(0.25, 0.25), width: .inches(2.0))
                .maxLines(3)
                .alignment(.center)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FB"))
        XCTAssertTrue(zpl.contains(",C,"))
    }

    func testSpecialCharactersEscaped() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Price: $5 (50% off) ^test~ _under", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        // Should have hex mode enabled
        XCTAssertTrue(zpl.contains("^FH"))
        // Caret should be escaped
        XCTAssertTrue(zpl.contains("_5E"))
        // Tilde should be escaped
        XCTAssertTrue(zpl.contains("_7E"))
        // Underscore should be escaped
        XCTAssertTrue(zpl.contains("_5F"))
    }

    func testPrintQuantity() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printQuantity(5)

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^PQ5"))
    }

    func testDimensionConversions() {
        let dpi = DPI.dpi203

        // 1 inch = 203 dots
        XCTAssertEqual(ZPLKit.Dimension.inches(1.0).resolve(dpi: dpi), 203)

        // 25.4 mm = 1 inch = 203 dots
        XCTAssertEqual(ZPLKit.Dimension.mm(25.4).resolve(dpi: dpi), 203)

        // Integer literal becomes dots
        let dim: ZPLKit.Dimension = 100
        XCTAssertEqual(dim.resolve(dpi: dpi), 100)
    }

    func testPositionConversions() {
        let dpi = DPI.dpi203

        let dotsPos = Position.dots(100, 200).resolve(dpi: dpi)
        XCTAssertEqual(dotsPos.x, 100)
        XCTAssertEqual(dotsPos.y, 200)

        let inchesPos = Position.inches(1.0, 2.0).resolve(dpi: dpi)
        XCTAssertEqual(inchesPos.x, 203)
        XCTAssertEqual(inchesPos.y, 406)
    }

    func testPrettyPrintAddsNewlines() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }

        let compact = label.render(prettyPrint: false)
        let pretty = label.render(prettyPrint: true)

        XCTAssertFalse(compact.contains("\n"))
        XCTAssertTrue(pretty.contains("\n"))
    }

    // MARK: - Circle Tests

    func testCircleRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Circle(at: .inches(0.5, 0.5), diameter: .inches(1.0))
                .thickness(3)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GC"))
    }

    func testFilledCircleRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Circle(at: .inches(0.5, 0.5), diameter: .dots(100))
                .filled()
        }

        let zpl = label.render()
        // Filled circle has thickness equal to diameter
        XCTAssertTrue(zpl.contains("^GC100,100,B"))
    }

    // MARK: - Ellipse Tests

    func testEllipseRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .inches(0.5, 0.5), width: .inches(1.0), height: .inches(0.5))
                .thickness(2)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GE"))
    }

    func testFilledEllipseRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .dots(50, 50), width: .dots(200), height: .dots(100))
                .filled()
        }

        let zpl = label.render()
        // Filled ellipse has thickness = min(width, height)
        XCTAssertTrue(zpl.contains("^GE200,100,100"))
    }

    // MARK: - Diagonal Line Tests

    func testDiagonalLineRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DiagonalLine(at: .inches(0.25, 0.25), width: .inches(1.0), height: .inches(1.0))
                .thickness(3)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GD"))
    }

    func testDiagonalLineDirections() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DiagonalLine(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .direction(.leftLeaning)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains(",L^FS"))
    }

    // MARK: - PDF417 Tests

    func testPDF417Renders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            PDF417("SHIPPING-MANIFEST-12345", at: .inches(0.25, 0.25))
                .rowHeight(.dots(8))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B7"))
        XCTAssertTrue(zpl.contains("^FDSHIPPING-MANIFEST-12345^FS"))
    }

    func testPDF417WithOptions() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            PDF417("ID-CARD-DATA", at: .inches(0.25, 0.25))
                .securityLevel(3)
                .columns(5)
                .truncated()
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B7N,10,3,5,0,Y"))
    }

    // MARK: - Interleaved 2 of 5 Tests

    func testInterleaved2of5Valid() {
        let barcode = Interleaved2of5("1234567890", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testInterleaved2of5Invalid() {
        // Should fail with non-numeric characters
        let barcode = Interleaved2of5("123ABC", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testInterleaved2of5Renders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Interleaved2of5("123456", at: .inches(0.25, 0.25))?
                .height(.dots(80))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B2"))
        XCTAssertTrue(zpl.contains("^FD123456^FS"))
    }

    func testInterleaved2of5WithCheckDigit() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Interleaved2of5("12345", at: .inches(0.25, 0.25))?
                .checkDigit(true)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains(",Y^FD"))  // Check digit flag = Y
    }

    // MARK: - EAN-13 Tests

    func testEAN13Valid() {
        let barcode = EAN13("590123412345", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testEAN13InvalidLength() {
        // Should fail with wrong length
        let barcode = EAN13("12345", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testEAN13InvalidChars() {
        // Should fail with non-numeric characters
        let barcode = EAN13("59012341234A", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testEAN13Renders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            EAN13("590123412345", at: .inches(0.25, 0.25))?
                .height(.dots(80))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BE"))
        XCTAssertTrue(zpl.contains("^FD590123412345^FS"))
    }

    // MARK: - UPC-A Tests

    func testUPCAValid() {
        let barcode = UPCA("01234567890", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testUPCAInvalidLength() {
        // Should fail with wrong length
        let barcode = UPCA("12345", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testUPCAInvalidChars() {
        // Should fail with non-numeric characters
        let barcode = UPCA("0123456789A", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testUPCARenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            UPCA("01234567890", at: .inches(0.25, 0.25))?
                .height(.dots(80))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BU"))
        XCTAssertTrue(zpl.contains("^FD01234567890^FS"))
    }

    // MARK: - Aztec Tests

    func testAztecRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Aztec("TICKET-DATA-12345", at: .inches(0.5, 0.5))
                .magnification(5)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B0"))
        XCTAssertTrue(zpl.contains("^FDTICKET-DATA-12345^FS"))
    }

    func testAztecWithOptions() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Aztec("SECURE-DATA", at: .inches(0.5, 0.5))
                .magnification(4)
                .errorCorrection(50)
                .extendedChannel(true)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B0N,4,Y,50"))
    }

    // MARK: - Serial Number Tests

    func testSerialNumberRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            SerialNumber("001", at: .inches(0.25, 0.25))
                .increment(1)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^SN001,1,Y"))
    }

    func testSerialNumberDecrement() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            SerialNumber("100", at: .inches(0.25, 0.25))
                .increment(-1)
                .leadingZeros(false)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^SN100,-1,N"))
    }

    // MARK: - Baseline Positioning Tests

    func testTextBaseline() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Baseline", at: .inches(0.5, 0.5))
                .baseline()
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FT"))  // Uses ^FT instead of ^FO
        XCTAssertFalse(zpl.contains("^FO"))
    }

    func testTextBlockBaseline() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Baseline block", at: .inches(0.25, 0.5), width: .inches(2.0))
                .baseline()
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FT"))
        XCTAssertFalse(zpl.contains("^FO"))
    }
}
