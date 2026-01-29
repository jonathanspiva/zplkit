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
}
