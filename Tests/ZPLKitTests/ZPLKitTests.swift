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
}
