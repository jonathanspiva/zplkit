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

    func testPrintSpeed() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printSpeed(6)

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^PR6"))
    }

    func testPrintSpeedWithSlew() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printSpeed(6, slew: 8)

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^PR6,8"))
    }

    func testPrintSpeedWithAllOptions() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printSpeed(6, slew: 8, backfeed: 4)

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^PR6,8,4"))
    }

    func testPrintSpeedWithBackfeedOnly() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printSpeed(6, backfeed: 4)

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^PR6,,4"))
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

    func testTextBlockRotated() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Rotated", at: .inches(0.25, 0.5), width: .inches(2.0))
                .rotated(.rotated90)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^A0R,"))  // R = rotated 90
    }

    func testTextBlockReversed() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Reversed", at: .inches(0.25, 0.5), width: .inches(2.0))
                .reversed()
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FR"))  // Reverse field
    }

    func testTextBlockWithNewlines() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Line 1\nLine 2\nLine 3", at: .inches(0.25, 0.25), width: .inches(2.0))
                .maxLines(3)
        }

        let zpl = label.render()
        // \n should be converted to ZPL's \& line break
        XCTAssertTrue(zpl.contains("Line 1\\&Line 2\\&Line 3"))
    }

    func testTextBlockCombinedOptions() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Important\nMessage", at: .inches(0.25, 0.25), width: .inches(2.0))
                .font(.default, height: .dots(40))
                .alignment(.center)
                .lineSpacing(.dots(5))
                .reversed()
                .maxLines(2)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FR"))
        XCTAssertTrue(zpl.contains("^FB"))
        XCTAssertTrue(zpl.contains(",C,"))  // Center alignment
        XCTAssertTrue(zpl.contains("\\&"))  // Line break
    }

    // MARK: - EAN-8 Tests

    func testEAN8Valid() {
        let barcode = EAN8("1234567", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testEAN8With8Digits() {
        // 8 digits includes check digit
        let barcode = EAN8("12345670", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testEAN8InvalidLength() {
        // Should fail with wrong length
        let barcode = EAN8("12345", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testEAN8InvalidChars() {
        // Should fail with non-numeric characters
        let barcode = EAN8("123456A", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testEAN8Renders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            EAN8("1234567", at: .inches(0.25, 0.25))?
                .height(.dots(80))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B8"))
        XCTAssertTrue(zpl.contains("^FD1234567^FS"))
    }

    func testEAN8TextAbove() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            EAN8("1234567", at: .inches(0.25, 0.25))?
                .textAbove()
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B8N,100,Y,Y"))  // Last Y = text above
    }

    // MARK: - UPC-E Tests

    func testUPCEValid() {
        let barcode = UPCE("123456", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testUPCEWith8Digits() {
        // 8 digits = number system + data + check
        let barcode = UPCE("01234565", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testUPCEInvalidLength() {
        // Should fail with wrong length (too short)
        let barcode = UPCE("12345", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)

        // Should fail with wrong length (too long)
        let barcode2 = UPCE("123456789", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode2)
    }

    func testUPCEInvalidChars() {
        // Should fail with non-numeric characters
        let barcode = UPCE("12345A", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testUPCERenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            UPCE("123456", at: .inches(0.25, 0.25))?
                .height(.dots(80))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B9"))
        XCTAssertTrue(zpl.contains("^FD123456^FS"))
    }

    func testUPCEWithOptions() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            UPCE("123456", at: .inches(0.25, 0.25))?
                .showText(false)
                .checkDigit(false)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B9N,100,N,N,N"))
    }

    // MARK: - Intelligent Mail Tests

    func testIntelligentMailValid20() {
        // 20 digits = tracking code only
        let barcode = IntelligentMail("01234567890123456789", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testIntelligentMailValid25() {
        // 25 digits = tracking + 5-digit ZIP
        let barcode = IntelligentMail("0123456789012345678901234", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testIntelligentMailValid29() {
        // 29 digits = tracking + 9-digit ZIP
        let barcode = IntelligentMail("01234567890123456789012345678", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testIntelligentMailValid31() {
        // 31 digits = tracking + 11-digit delivery point
        let barcode = IntelligentMail("0123456789012345678901234567890", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testIntelligentMailInvalidLength() {
        // Should fail with invalid lengths
        let barcode1 = IntelligentMail("123456789", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode1)

        let barcode2 = IntelligentMail("012345678901234567890123", at: .inches(0.5, 0.5))  // 24 digits
        XCTAssertNil(barcode2)
    }

    func testIntelligentMailInvalidChars() {
        // Should fail with non-numeric characters
        let barcode = IntelligentMail("0123456789012345678A", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testIntelligentMailRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            IntelligentMail("01234567890123456789", at: .inches(0.25, 0.25))?
                .height(.dots(30))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BZ"))
        XCTAssertTrue(zpl.contains("^FD01234567890123456789^FS"))
    }

    func testIntelligentMailRotated() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            IntelligentMail("01234567890123456789", at: .inches(0.25, 0.25))?
                .rotated(.rotated90)
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BZR,"))  // R = rotated 90
    }

    // MARK: - Template Substitution Tests

    func testTemplateSubstitution() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Order: {{orderNumber}}", at: .inches(0.25, 0.25))
        }

        let zpl = label.render(substituting: ["orderNumber": "12345"])
        XCTAssertTrue(zpl.contains("^FDOrder: 12345^FS"))
        XCTAssertFalse(zpl.contains("{{orderNumber}}"))
    }

    func testTemplateSubstitutionMultiple() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("{{name}}", at: .inches(0.25, 0.25))
            Text("{{address}}", at: .inches(0.25, 0.5))
            Barcode128("{{tracking}}", at: .inches(0.25, 1))?
                .height(.dots(80))
        }

        let zpl = label.render(substituting: [
            "name": "John Smith",
            "address": "123 Main St",
            "tracking": "1Z999AA1"
        ])

        XCTAssertTrue(zpl.contains("^FDJohn Smith^FS"))
        XCTAssertTrue(zpl.contains("^FD123 Main St^FS"))
        XCTAssertTrue(zpl.contains("^FD1Z999AA1^FS"))
    }

    func testTemplateSubstitutionWithQRCode() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("{{url}}", at: .inches(0.5, 0.5))
                .magnification(5)
        }

        let zpl = label.render(substituting: ["url": "https://example.com/order/12345"])
        // QR codes prepend error correction + "A," prefix
        XCTAssertTrue(zpl.contains("MA,https://example.com/order/12345^FS"))
        XCTAssertFalse(zpl.contains("{{url}}"))
    }

    func testTemplateUnsubstitutedVariablesRemain() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("{{name}} - {{missing}}", at: .inches(0.25, 0.25))
        }

        let zpl = label.render(substituting: ["name": "Test"])
        XCTAssertTrue(zpl.contains("Test"))
        XCTAssertTrue(zpl.contains("{{missing}}"))  // Unsubstituted variable remains
    }

    // MARK: - Reverse Print Tests

    func testReversePrint() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Inverted", at: .inches(0.25, 0.25))
        }.reversePrint()

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^LRY"))  // Label-wide reverse
    }

    func testReversePrintDisabled() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Normal", at: .inches(0.25, 0.25))
        }.reversePrint(false)

        let zpl = label.render()
        XCTAssertFalse(zpl.contains("^LRY"))
    }

    func testReversePrintDefault() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Normal", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertFalse(zpl.contains("^LRY"))  // Should not be present by default
    }

    // MARK: - Comment Tests

    func testCommentRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Comment("This is a debugging note")
            Text("Hello", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FX This is a debugging note ^FS"))
    }

    func testCommentNotPrinted() {
        // Comments should be in ZPL output but use ^FX which is ignored by printer
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Comment("Section 1: Header")
            Text("Title", at: .inches(0.25, 0.25))
            Comment("Section 2: Content")
            Text("Body", at: .inches(0.25, 0.5))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FX Section 1: Header ^FS"))
        XCTAssertTrue(zpl.contains("^FX Section 2: Content ^FS"))
        XCTAssertTrue(zpl.contains("^FDTitle^FS"))
        XCTAssertTrue(zpl.contains("^FDBody^FS"))
    }

    func testCommentEmpty() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Comment("")
            Text("Test", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FX  ^FS"))  // Empty comment still renders
    }

    // MARK: - Graphic Tests

    // MARK: - VerticalLine Tests

    func testVerticalLineRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .inches(0.5, 0.25), length: .inches(1.0))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GB"))
        // Vertical line: width = thickness, height = length
        // Default thickness is 2 dots
    }

    func testVerticalLineWithCustomThickness() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .dots(50, 50), length: .dots(200), thickness: .dots(5))
        }

        let zpl = label.render()
        // Vertical line: ^GB[thickness],[length],[thickness]
        XCTAssertTrue(zpl.contains("^GB5,200,5"))
    }

    func testVerticalLineInDots() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .dots(100, 100), length: .dots(150))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FO100,100"))
        XCTAssertTrue(zpl.contains("^GB2,150,2"))  // Default thickness = 2
    }

    func testVerticalLineInInches() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .inches(0.5, 0.5), length: .inches(1.0), thickness: .inches(0.05))
        }

        let zpl = label.render()
        // 0.5 inches * 203 DPI = 101.5, rounded = 102 dots
        // 1.0 inches * 203 DPI = 203 dots
        // 0.05 inches * 203 DPI = 10.15, rounded = 10 dots
        XCTAssertTrue(zpl.contains("^FO102,102"))
    }

    func testVerticalLineInMillimeters() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .mm(10, 10), length: .mm(25.4))  // 25.4mm = 1 inch
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GB"))
        // Just verify it renders without error
    }

    func testVerticalLineZeroLength() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .dots(50, 50), length: .dots(0))
        }

        let zpl = label.render()
        // Should still render (degenerate case)
        XCTAssertTrue(zpl.contains("^GB2,0,2"))
    }

    // MARK: - HorizontalLine Edge Cases

    func testHorizontalLineWithCustomThickness() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .dots(50, 50), length: .dots(200), thickness: .dots(5))
        }

        let zpl = label.render()
        // Horizontal line: ^GB[length],[thickness],[thickness]
        XCTAssertTrue(zpl.contains("^GB200,5,5"))
    }

    func testHorizontalLineInInches() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .inches(0.25, 0.25), length: .inches(2.0), thickness: .inches(0.02))
        }

        let zpl = label.render()
        // 0.25 * 203 = 50.75, rounded = 51
        XCTAssertTrue(zpl.contains("^FO51,51"))
        // 2.0 * 203 = 406, 0.02 * 203 = 4.06, rounded = 4
        XCTAssertTrue(zpl.contains("^GB406,4,4"))
    }

    func testHorizontalLineInMillimeters() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .mm(5, 5), length: .mm(50))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GB"))
    }

    func testHorizontalLineZeroLength() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .dots(50, 50), length: .dots(0))
        }

        let zpl = label.render()
        // Should still render (degenerate case)
        XCTAssertTrue(zpl.contains("^GB0,2,2"))
    }

    func testHorizontalLineDefaultThickness() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .dots(0, 0), length: .dots(100))
        }

        let zpl = label.render()
        // Default thickness is 2 dots
        XCTAssertTrue(zpl.contains("^GB100,2,2"))
    }

    func testVerticalLineDefaultThickness() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .dots(0, 0), length: .dots(100))
        }

        let zpl = label.render()
        // Default thickness is 2 dots
        XCTAssertTrue(zpl.contains("^GB2,100,2"))
    }

    // MARK: - Label Configuration Tests

    func testDefaultFont() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.defaultFont(.default, height: 40)

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^CF0,40"))
    }

    func testDefaultFontWithDifferentFonts() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.defaultFont(.a, height: 50)

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^CFA,50"))
    }

    func testLabelHome() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.labelHome(100, 50)

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^LH100,50"))
    }

    func testLabelHomeAtOrigin() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.labelHome(0, 0)

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^LH0,0"))
    }

    func testPrintDarkness() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printDarkness(15)

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^MD15"))
    }

    func testPrintDarknessClampedToMax() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printDarkness(50)  // Over max of 30

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^MD30"))  // Clamped to 30
        XCTAssertFalse(zpl.contains("^MD50"))
    }

    func testPrintDarknessClampedToMin() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printDarkness(-10)  // Under min of 0

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^MD0"))  // Clamped to 0
    }

    func testPrintDarknessAtBoundaries() {
        let labelMin = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printDarkness(0)

        let labelMax = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printDarkness(30)

        XCTAssertTrue(labelMin.render().contains("^MD0"))
        XCTAssertTrue(labelMax.render().contains("^MD30"))
    }

    func testCombinedLabelConfig() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }
        .labelHome(50, 25)
        .defaultFont(.default, height: 35)
        .printDarkness(20)
        .reversePrint()

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^LH50,25"))
        XCTAssertTrue(zpl.contains("^CF0,35"))
        XCTAssertTrue(zpl.contains("^MD20"))
        XCTAssertTrue(zpl.contains("^LRY"))
    }

    func testLabelConfigOrder() {
        // Config commands should appear in consistent order after ^XA
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }
        .labelHome(10, 20)
        .printDarkness(15)

        let zpl = label.render()

        // ^LH should come before ^PW
        let lhIndex = zpl.range(of: "^LH")!.lowerBound
        let pwIndex = zpl.range(of: "^PW")!.lowerBound
        XCTAssertTrue(lhIndex < pwIndex)
    }

    func testDefaultFontNotPresentByDefault() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertFalse(zpl.contains("^CF"))
    }

    func testLabelHomeNotPresentByDefault() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertFalse(zpl.contains("^LH"))
    }

    func testPrintDarknessNotPresentByDefault() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertFalse(zpl.contains("^MD"))
    }

    // MARK: - String Escaping Tests

    func testEmptyStringText() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FD^FS"))
    }

    func testCaretEscaping() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("A^B", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FH"))  // Hex mode enabled
        XCTAssertTrue(zpl.contains("_5E"))  // ^ escaped
    }

    func testTildeEscaping() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("A~B", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FH"))
        XCTAssertTrue(zpl.contains("_7E"))  // ~ escaped
    }

    func testUnderscoreEscaping() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("A_B", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FH"))
        XCTAssertTrue(zpl.contains("_5F"))  // _ escaped
    }

    func testMultipleSpecialCharsEscaping() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("^~_", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FH"))
        XCTAssertTrue(zpl.contains("_5E"))  // ^
        XCTAssertTrue(zpl.contains("_7E"))  // ~
        XCTAssertTrue(zpl.contains("_5F"))  // _
    }

    func testNoSpecialCharsNoHexMode() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Hello World 123", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertFalse(zpl.contains("^FH"))  // No hex mode needed
        XCTAssertTrue(zpl.contains("^FDHello World 123^FS"))
    }

    func testNonASCIICharacterEscaping() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Café", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FH"))  // Hex mode for non-ASCII
    }

    func testUTF8MultibyteEscaping() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("日本語", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FH"))  // Hex mode for multibyte
        // Each Japanese character is 3 bytes in UTF-8
    }

    func testMixedASCIIAndSpecialChars() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Item^1: $10.00", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FH"))
        XCTAssertTrue(zpl.contains("Item"))
        XCTAssertTrue(zpl.contains("_5E"))
        XCTAssertTrue(zpl.contains(": $10.00"))
    }

    func testEmojiEscaping() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Hello 👋", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FH"))  // Hex mode for emoji (4-byte UTF-8)
    }

    // MARK: - Barcode Validation Edge Cases

    func testBarcode128EmptyString() {
        let barcode = Barcode128("", at: .inches(0.5, 0.5))
        // Empty string is valid ASCII
        XCTAssertNotNil(barcode)
    }

    func testBarcode128ModuleWidthClampedToMin() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("TEST", at: .inches(0.25, 0.25))?
                .moduleWidth(0)  // Below min of 1
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BY1"))  // Clamped to 1
    }

    func testBarcode128ModuleWidthClampedToMax() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("TEST", at: .inches(0.25, 0.25))?
                .moduleWidth(20)  // Above max of 10
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BY10"))  // Clamped to 10
    }

    func testBarcode128ModuleWidthBoundaries() {
        let label1 = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("TEST", at: .inches(0.25, 0.25))?
                .moduleWidth(1)
        }
        let label10 = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("TEST", at: .inches(0.25, 0.25))?
                .moduleWidth(10)
        }

        XCTAssertTrue(label1.render().contains("^BY1"))
        XCTAssertTrue(label10.render().contains("^BY10"))
    }

    func testCode39EmptyString() {
        let barcode = Code39("", at: .inches(0.5, 0.5))
        // Empty string technically has no invalid chars
        XCTAssertNotNil(barcode)
    }

    func testCode39LowercaseConverted() {
        // Code39 should convert to uppercase
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Code39("hello", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FDHELLO^FS"))
    }

    func testCode39SpecialCharsValid() {
        // Code39 allows: A-Z, 0-9, -.$/+% and space
        let barcode = Code39("HELLO-123 $50.00", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testCode39AtSymbolInvalid() {
        let barcode = Code39("TEST@EMAIL", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)
    }

    func testInterleaved2of5EmptyString() {
        let barcode = Interleaved2of5("", at: .inches(0.5, 0.5))
        // Empty is technically valid (no non-numeric chars)
        XCTAssertNotNil(barcode)
    }

    func testInterleaved2of5WithSpacesInvalid() {
        let barcode = Interleaved2of5("123 456", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)  // Spaces not allowed
    }

    func testEAN13TooShort() {
        let barcode = EAN13("12345", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)  // Must be 12 or 13 digits
    }

    func testEAN13TooLong() {
        let barcode = EAN13("12345678901234", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)  // 14 digits, too long
    }

    func testEAN13Exactly12Digits() {
        let barcode = EAN13("123456789012", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)  // 12 digits valid
    }

    func testEAN13Exactly13Digits() {
        let barcode = EAN13("1234567890123", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)  // 13 digits valid (includes check)
    }

    func testEAN13WithLeadingZeros() {
        let barcode = EAN13("000000000000", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testEAN8TooShort() {
        let barcode = EAN8("12345", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)  // Must be 7 or 8 digits
    }

    func testEAN8Exactly7Digits() {
        let barcode = EAN8("1234567", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testUPCATooShort() {
        let barcode = UPCA("1234567890", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)  // 10 digits, needs 11 or 12
    }

    func testUPCAExactly11Digits() {
        let barcode = UPCA("12345678901", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testUPCETooShort() {
        let barcode = UPCE("12345", at: .inches(0.5, 0.5))
        XCTAssertNil(barcode)  // 5 digits, needs 6-8
    }

    func testUPCEExactly6Digits() {
        let barcode = UPCE("123456", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testUPCEExactly7Digits() {
        let barcode = UPCE("1234567", at: .inches(0.5, 0.5))
        XCTAssertNotNil(barcode)
    }

    func testIntelligentMailInvalidLengths() {
        // Valid lengths: 20, 25, 29, 31
        XCTAssertNil(IntelligentMail("1234567890123456789", at: .inches(0.5, 0.5)))  // 19
        XCTAssertNil(IntelligentMail("123456789012345678901", at: .inches(0.5, 0.5)))  // 21
        XCTAssertNil(IntelligentMail("12345678901234567890123", at: .inches(0.5, 0.5)))  // 23
        XCTAssertNil(IntelligentMail("1234567890123456789012345678901234", at: .inches(0.5, 0.5)))  // 34
    }

    func testQRCodeMagnificationClampedToMin() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("TEST", at: .inches(0.5, 0.5))
                .magnification(0)  // Below min of 1
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BQN,2,1"))  // Clamped to 1
    }

    func testQRCodeMagnificationClampedToMax() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("TEST", at: .inches(0.5, 0.5))
                .magnification(20)  // Above max of 10
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BQN,2,10"))  // Clamped to 10
    }

    func testDataMatrixSizeClampedToMin() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DataMatrix("TEST", at: .inches(0.5, 0.5))
                .size(0)  // Below min of 1
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BXN,1"))  // Clamped to 1
    }

    func testDataMatrixSizeClampedToMax() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DataMatrix("TEST", at: .inches(0.5, 0.5))
                .size(20)  // Above max of 10
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BXN,10"))  // Clamped to 10
    }

    func testAztecMagnificationClampedToMin() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Aztec("TEST", at: .inches(0.5, 0.5))
                .magnification(0)  // Below min of 1
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B0N,1"))  // Clamped to 1
    }

    func testAztecMagnificationClampedToMax() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Aztec("TEST", at: .inches(0.5, 0.5))
                .magnification(20)  // Above max of 10
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^B0N,10"))  // Clamped to 10
    }

    // MARK: - Shape Edge Cases

    func testBoxZeroWidth() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(0), height: .dots(100))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GB0,100,"))  // Degenerate box
    }

    func testBoxZeroHeight() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(100), height: .dots(0))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GB100,0,"))  // Degenerate box
    }

    func testBoxZeroDimensions() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(0), height: .dots(0))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GB0,0,"))
    }

    func testBoxCornerRadiusClampedToMin() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .cornerRadius(-5)  // Below min of 0
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains(",0^FS"))  // Clamped to 0
    }

    func testBoxCornerRadiusClampedToMax() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .cornerRadius(15)  // Above max of 8
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains(",8^FS"))  // Clamped to 8
    }

    func testBoxCornerRadiusBoundaries() {
        let label0 = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .cornerRadius(0)
        }
        let label8 = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .cornerRadius(8)
        }

        XCTAssertTrue(label0.render().contains(",0^FS"))
        XCTAssertTrue(label8.render().contains(",8^FS"))
    }

    func testBoxWhiteColor() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .white()
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains(",W,"))  // White color
    }

    func testCircleZeroDiameter() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Circle(at: .dots(50, 50), diameter: .dots(0))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GC0,"))  // Degenerate circle
    }

    func testCircleWhiteColor() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Circle(at: .dots(50, 50), diameter: .dots(100))
                .white()
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains(",W^FS"))
    }

    func testEllipseZeroWidth() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .dots(50, 50), width: .dots(0), height: .dots(100))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GE0,100,"))
    }

    func testEllipseZeroHeight() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .dots(50, 50), width: .dots(100), height: .dots(0))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GE100,0,"))
    }

    func testEllipseWhiteColor() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .dots(50, 50), width: .dots(200), height: .dots(100))
                .white()
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains(",W^FS"))
    }

    func testDiagonalLineZeroDimensions() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DiagonalLine(at: .dots(50, 50), width: .dots(0), height: .dots(0))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GD0,0,"))
    }

    func testDiagonalLineWhiteColor() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DiagonalLine(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .white()
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains(",W,"))
    }

    // MARK: - DPI Variation Tests

    func testDPI152Conversion() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi152) {
            Text("Test", at: .inches(1.0, 1.0))
        }

        let zpl = label.render()
        // 4 inches * 152 DPI = 608 dots
        XCTAssertTrue(zpl.contains("^PW608"))
        // 2 inches * 152 DPI = 304 dots
        XCTAssertTrue(zpl.contains("^LL304"))
        // Position: 1 inch * 152 = 152 dots
        XCTAssertTrue(zpl.contains("^FO152,152"))
    }

    func testDPI203Conversion() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(1.0, 1.0))
        }

        let zpl = label.render()
        // 4 inches * 203 DPI = 812 dots
        XCTAssertTrue(zpl.contains("^PW812"))
        // 2 inches * 203 DPI = 406 dots
        XCTAssertTrue(zpl.contains("^LL406"))
        // Position: 1 inch * 203 = 203 dots
        XCTAssertTrue(zpl.contains("^FO203,203"))
    }

    func testDPI300Conversion() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi300) {
            Text("Test", at: .inches(1.0, 1.0))
        }

        let zpl = label.render()
        // 4 inches * 300 DPI = 1200 dots
        XCTAssertTrue(zpl.contains("^PW1200"))
        // 2 inches * 300 DPI = 600 dots
        XCTAssertTrue(zpl.contains("^LL600"))
        // Position: 1 inch * 300 = 300 dots
        XCTAssertTrue(zpl.contains("^FO300,300"))
    }

    func testDPI600Conversion() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi600) {
            Text("Test", at: .inches(1.0, 1.0))
        }

        let zpl = label.render()
        // 4 inches * 600 DPI = 2400 dots
        XCTAssertTrue(zpl.contains("^PW2400"))
        // 2 inches * 600 DPI = 1200 dots
        XCTAssertTrue(zpl.contains("^LL1200"))
        // Position: 1 inch * 600 = 600 dots
        XCTAssertTrue(zpl.contains("^FO600,600"))
    }

    func testDPIMillimeterConversion() {
        // 25.4mm = 1 inch
        let label152 = ZPLLabel(width: 4, height: 2, dpi: .dpi152) {
            Box(at: .mm(25.4, 25.4), width: .mm(25.4), height: .mm(25.4))
        }
        let label300 = ZPLLabel(width: 4, height: 2, dpi: .dpi300) {
            Box(at: .mm(25.4, 25.4), width: .mm(25.4), height: .mm(25.4))
        }

        // 152 DPI: 1 inch = 152 dots
        XCTAssertTrue(label152.render().contains("^FO152,152"))
        XCTAssertTrue(label152.render().contains("^GB152,152,"))

        // 300 DPI: 1 inch = 300 dots
        XCTAssertTrue(label300.render().contains("^FO300,300"))
        XCTAssertTrue(label300.render().contains("^GB300,300,"))
    }

    func testDPIDotsUnaffected() {
        // Dots should be the same regardless of DPI
        let label152 = ZPLLabel(width: 4, height: 2, dpi: .dpi152) {
            Box(at: .dots(100, 100), width: .dots(200), height: .dots(150))
        }
        let label600 = ZPLLabel(width: 4, height: 2, dpi: .dpi600) {
            Box(at: .dots(100, 100), width: .dots(200), height: .dots(150))
        }

        // Both should have same position and dimensions in dots
        XCTAssertTrue(label152.render().contains("^FO100,100"))
        XCTAssertTrue(label152.render().contains("^GB200,150,"))
        XCTAssertTrue(label600.render().contains("^FO100,100"))
        XCTAssertTrue(label600.render().contains("^GB200,150,"))
    }

    func testDPIAllBarcodeTypes() {
        // Test that barcodes render at different DPIs
        for dpi in [DPI.dpi152, .dpi203, .dpi300, .dpi600] {
            let label = ZPLLabel(width: 4, height: 4, dpi: dpi) {
                Barcode128("TEST", at: .inches(0.5, 0.5))
                QRCode("TEST", at: .inches(0.5, 1.5))
            }
            let zpl = label.render()
            XCTAssertTrue(zpl.contains("^BC"))
            XCTAssertTrue(zpl.contains("^BQ"))
        }
    }

    func testDPIShapesAtAllResolutions() {
        for dpi in [DPI.dpi152, .dpi203, .dpi300, .dpi600] {
            let label = ZPLLabel(width: 4, height: 4, dpi: dpi) {
                Box(at: .inches(0.25, 0.25), width: .inches(0.5), height: .inches(0.5))
                Circle(at: .inches(1.0, 0.25), diameter: .inches(0.5))
                Ellipse(at: .inches(1.75, 0.25), width: .inches(0.75), height: .inches(0.5))
            }
            let zpl = label.render()
            XCTAssertTrue(zpl.contains("^GB"))
            XCTAssertTrue(zpl.contains("^GC"))
            XCTAssertTrue(zpl.contains("^GE"))
        }
    }

    // MARK: - Complex Layout Tests

    func testMultipleOverlappingElements() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            // Background box
            Box(at: .dots(50, 50), width: .dots(300), height: .dots(200))
                .filled()
            // Overlapping text (white on black)
            Text("OVERLAPPING", at: .dots(100, 100))
                .font(.default, height: .dots(40))
                .reversed()
            // Another shape on top
            Circle(at: .dots(200, 100), diameter: .dots(80))
                .white()
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GB300,200,"))  // Filled box
        XCTAssertTrue(zpl.contains("^FR"))  // Reversed text
        XCTAssertTrue(zpl.contains("^GC80,"))  // Circle
    }

    func testManyElementsLabel() {
        let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
            // Header
            Text("SHIPPING LABEL", at: .dots(50, 30))
                .font(.default, height: .dots(40))
            HorizontalLine(at: .dots(50, 80), length: .dots(700), thickness: .dots(3))

            // Address block
            TextBlock("John Doe\n123 Main Street\nAnytown, ST 12345", at: .dots(50, 100), width: .dots(400))
                .maxLines(4)

            // Barcode section
            Barcode128("1Z999AA10123456784", at: .dots(50, 300))?
                .height(.dots(100))
                .moduleWidth(2)

            // QR code
            QRCode("https://track.example.com/1Z999AA10123456784", at: .dots(500, 100))
                .magnification(4)

            // Footer
            HorizontalLine(at: .dots(50, 500), length: .dots(700), thickness: .dots(2))
            Text("Thank you for your order!", at: .dots(50, 520))
        }

        let zpl = label.render()
        // Verify all elements are present
        XCTAssertTrue(zpl.contains("^FDSHIPPING LABEL"))
        XCTAssertTrue(zpl.contains("^FB"))  // TextBlock
        XCTAssertTrue(zpl.contains("^BC"))  // Barcode128
        XCTAssertTrue(zpl.contains("^BQ"))  // QRCode
        XCTAssertTrue(zpl.contains("Thank you"))
    }

    func testConditionalBuilderLogic() {
        let showBarcode = true
        let showQR = false

        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Product", at: .dots(50, 50))

            if showBarcode {
                Barcode128("ABC123", at: .dots(50, 100))
            }

            if showQR {
                QRCode("https://example.com", at: .dots(300, 50))
            }
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^BC"))  // Barcode should be present
        XCTAssertFalse(zpl.contains("^BQ"))  // QR should not be present
    }

    func testLoopBuilderLogic() {
        let items = ["Apple", "Banana", "Cherry"]

        let label = ZPLLabel(width: 4, height: 3, dpi: .dpi203) {
            for (index, item) in items.enumerated() {
                Text(item, at: .dots(50, 50 + index * 60))
            }
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FDApple"))
        XCTAssertTrue(zpl.contains("^FDBanana"))
        XCTAssertTrue(zpl.contains("^FDCherry"))
    }

    func testOptionalElementsInBuilder() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Always present", at: .dots(50, 50))

            // Failable barcode that succeeds
            Barcode128("VALID123", at: .dots(50, 100))

            // Failable barcode that fails (non-ASCII)
            Barcode128("INVALID\u{0080}", at: .dots(50, 200))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FDVALID123"))
        XCTAssertFalse(zpl.contains("INVALID"))  // Invalid barcode should not appear
    }

    func testMixedElementTypesLabel() {
        let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
            // Text elements
            Text("Title", at: .dots(50, 30))
            TextBlock("Description here", at: .dots(50, 70), width: .dots(300))

            // Shapes
            Box(at: .dots(400, 30), width: .dots(100), height: .dots(80))
            Circle(at: .dots(550, 50), diameter: .dots(60))
            Ellipse(at: .dots(650, 30), width: .dots(100), height: .dots(60))
            HorizontalLine(at: .dots(50, 150), length: .dots(700))
            VerticalLine(at: .dots(400, 200), length: .dots(300))
            DiagonalLine(at: .dots(450, 200), width: .dots(100), height: .dots(100))

            // 1D Barcodes
            Barcode128("BC128", at: .dots(50, 200))
            Code39("CODE39", at: .dots(50, 350))

            // 2D Barcodes
            QRCode("QR", at: .dots(50, 500))
            DataMatrix("DM", at: .dots(200, 500))

            // Comment (non-printing)
            Comment("End of label")
        }

        let zpl = label.render()

        // Verify all element types present
        XCTAssertTrue(zpl.contains("^FDTitle"))
        XCTAssertTrue(zpl.contains("^FB"))
        XCTAssertTrue(zpl.contains("^GB"))  // Box and lines
        XCTAssertTrue(zpl.contains("^GC"))  // Circle
        XCTAssertTrue(zpl.contains("^GE"))  // Ellipse
        XCTAssertTrue(zpl.contains("^GD"))  // Diagonal
        XCTAssertTrue(zpl.contains("^BC"))  // Code128
        XCTAssertTrue(zpl.contains("^B3"))  // Code39
        XCTAssertTrue(zpl.contains("^BQ"))  // QR
        XCTAssertTrue(zpl.contains("^BX"))  // DataMatrix
        XCTAssertTrue(zpl.contains("^FX"))  // Comment
    }

    func testLargeNumberOfElements() {
        // Test with 50 text elements
        let label = ZPLLabel(width: 10, height: 10, dpi: .dpi203) {
            for i in 0..<50 {
                Text("Item \(i)", at: .dots(50, 20 + i * 40))
            }
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^FDItem 0"))
        XCTAssertTrue(zpl.contains("^FDItem 49"))

        // Count field separators to verify all elements rendered
        let fsCount = zpl.components(separatedBy: "^FS").count - 1
        XCTAssertEqual(fsCount, 50)
    }

    func testNestedBoxLayout() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            // Outer border
            Box(at: .dots(20, 20), width: .dots(760), height: .dots(760))
                .thickness(.dots(4))

            // Inner border
            Box(at: .dots(40, 40), width: .dots(720), height: .dots(720))
                .thickness(.dots(2))

            // Content area
            Box(at: .dots(60, 60), width: .dots(680), height: .dots(680))
                .thickness(.dots(1))

            // Center content
            Text("CENTERED", at: .dots(300, 380))
        }

        let zpl = label.render()
        // Should have 3 boxes with different thicknesses
        XCTAssertTrue(zpl.contains("^GB760,760,4"))
        XCTAssertTrue(zpl.contains("^GB720,720,2"))
        XCTAssertTrue(zpl.contains("^GB680,680,1"))
    }

    #if canImport(CoreGraphics)
    func testGraphicBasic() {
        // Create a simple 8x8 test pattern (checkerboard)
        let width = 8
        let height = 8
        let bytesPerRow = width
        var pixelData = [UInt8](repeating: 0, count: width * height)

        // Create checkerboard: black pixels where (x+y) is even
        for y in 0..<height {
            for x in 0..<width {
                pixelData[y * width + x] = ((x + y) % 2 == 0) ? 0 : 255
            }
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.linearGray)!
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!

        let cgImage = context.makeImage()!

        let label = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(cgImage, at: .dots(10, 10), width: .dots(8))
        }

        let zpl = label.render()
        XCTAssertTrue(zpl.contains("^GFA,"))  // ASCII format
        XCTAssertTrue(zpl.contains("^FO10,10"))  // Position
    }

    func testGraphicWithInvert() {
        // Create a simple black square
        let width = 8
        let height = 8
        var pixelData = [UInt8](repeating: 0, count: width * height)  // All black

        let colorSpace = CGColorSpace(name: CGColorSpace.linearGray)!
        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!

        let cgImage = context.makeImage()!

        let labelNormal = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(cgImage, at: .dots(10, 10), width: .dots(8), invert: false)
        }

        let labelInverted = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(cgImage, at: .dots(10, 10), width: .dots(8), invert: true)
        }

        let zplNormal = labelNormal.render()
        let zplInverted = labelInverted.render()

        // The hex data should be different when inverted
        XCTAssertNotEqual(zplNormal, zplInverted)
    }
    #endif
}
