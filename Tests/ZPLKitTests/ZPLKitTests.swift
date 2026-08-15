import Testing
@testable import ZPLKit

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Basic Label & Text

@Suite("Basic Label Rendering")
struct BasicLabelTests {

    @Test("Basic label renders core ZPL framing and field data")
    func basicLabelRenders() {
        let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
            Text("Hello World", at: .inches(0.25, 0.25))
        }

        let zpl = label.render()
        #expect(zpl.contains("^XA"))
        #expect(zpl.contains("^XZ"))
        #expect(zpl.contains("^FDHello World^FS"))
    }

    @Test("Label dimensions convert to dots")
    func labelDimensionsCorrect() {
        let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
            Text("Test", at: .dots(0, 0))
        }

        let zpl = label.render()
        // 4 inches * 203 DPI = 812 dots
        #expect(zpl.contains("^PW812"))
        // 6 inches * 203 DPI = 1218 dots
        #expect(zpl.contains("^LL1218"))
    }

    @Test("Text with font emits ^A0N with height/width")
    func textWithFont() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Styled", at: .inches(0.5, 0.5))
                .font(.default, height: .dots(50), width: .dots(40))
        }

        #expect(label.render().contains("^A0N,50,40"))
    }

    @Test("Text rotation emits ^A0R")
    func textRotation() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Rotated", at: .inches(0.5, 0.5))
                .rotated(.rotated90)
        }

        #expect(label.render().contains("^A0R"))
    }

    @Test("Pretty print adds newlines, compact does not")
    func prettyPrintAddsNewlines() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }

        let compact = label.render(prettyPrint: false)
        let pretty = label.render(prettyPrint: true)

        #expect(!compact.contains("\n"))
        #expect(pretty.contains("\n"))
    }

    @Test("Empty string text renders empty field data")
    func emptyStringText() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("", at: .inches(0.25, 0.25))
        }

        #expect(label.render().contains("^FD^FS"))
    }
}

// MARK: - Dimension & Position Conversions

@Suite("Dimension & Position Conversions")
struct ConversionTests {

    @Test("Dimension conversions resolve to dots")
    func dimensionConversions() {
        let dpi = DPI.dpi203

        // 1 inch = 203 dots
        #expect(ZPLKit.Dimension.inches(1.0).resolve(dpi: dpi) == 203)
        // 25.4 mm = 1 inch = 203 dots
        #expect(ZPLKit.Dimension.mm(25.4).resolve(dpi: dpi) == 203)
        // Integer literal becomes dots
        let dim: ZPLKit.Dimension = 100
        #expect(dim.resolve(dpi: dpi) == 100)
    }

    @Test("Position conversions resolve x/y to dots")
    func positionConversions() {
        let dpi = DPI.dpi203

        let dotsPos = Position.dots(100, 200).resolve(dpi: dpi)
        #expect(dotsPos.x == 100)
        #expect(dotsPos.y == 200)

        let inchesPos = Position.inches(1.0, 2.0).resolve(dpi: dpi)
        #expect(inchesPos.x == 203)
        #expect(inchesPos.y == 406)
    }
}

// MARK: - DPI Variations

@Suite("DPI Variations")
struct DPITests {

    /// (dpi, expectedPW, expectedLL, expectedFO) for a 4x2 label with text at 1.0,1.0 inch.
    @Test(arguments: [
        (DPI.dpi152, "^PW608", "^LL304", "^FO152,152"),
        (DPI.dpi200, "^PW800", "^LL400", "^FO200,200"),
        (DPI.dpi203, "^PW812", "^LL406", "^FO203,203"),
        (DPI.dpi300, "^PW1200", "^LL600", "^FO300,300"),
        (DPI.dpi600, "^PW2400", "^LL1200", "^FO600,600")
    ])
    func dpiConversion(dpi: DPI, expectedPW: String, expectedLL: String, expectedFO: String) {
        let label = ZPLLabel(width: 4, height: 2, dpi: dpi) {
            Text("Test", at: .inches(1.0, 1.0))
        }
        let zpl = label.render()
        #expect(zpl.contains(expectedPW))
        #expect(zpl.contains(expectedLL))
        #expect(zpl.contains(expectedFO))
    }

    @Test("Millimeter conversion respects DPI")
    func dpiMillimeterConversion() {
        // 25.4mm = 1 inch
        let label152 = ZPLLabel(width: 4, height: 2, dpi: .dpi152) {
            Box(at: .mm(25.4, 25.4), width: .mm(25.4), height: .mm(25.4))
        }
        let label300 = ZPLLabel(width: 4, height: 2, dpi: .dpi300) {
            Box(at: .mm(25.4, 25.4), width: .mm(25.4), height: .mm(25.4))
        }

        #expect(label152.render().contains("^FO152,152"))
        #expect(label152.render().contains("^GB152,152,"))
        #expect(label300.render().contains("^FO300,300"))
        #expect(label300.render().contains("^GB300,300,"))
    }

    @Test("Dots are unaffected by DPI")
    func dpiDotsUnaffected() {
        let label152 = ZPLLabel(width: 4, height: 2, dpi: .dpi152) {
            Box(at: .dots(100, 100), width: .dots(200), height: .dots(150))
        }
        let label600 = ZPLLabel(width: 4, height: 2, dpi: .dpi600) {
            Box(at: .dots(100, 100), width: .dots(200), height: .dots(150))
        }

        #expect(label152.render().contains("^FO100,100"))
        #expect(label152.render().contains("^GB200,150,"))
        #expect(label600.render().contains("^FO100,100"))
        #expect(label600.render().contains("^GB200,150,"))
    }

    @Test("All barcode types render at each DPI", arguments: [DPI.dpi152, .dpi200, .dpi203, .dpi300, .dpi600])
    func dpiAllBarcodeTypes(dpi: DPI) {
        let label = ZPLLabel(width: 4, height: 4, dpi: dpi) {
            Barcode128("TEST", at: .inches(0.5, 0.5))
            QRCode("TEST", at: .inches(0.5, 1.5))
        }
        let zpl = label.render()
        #expect(zpl.contains("^BC"))
        #expect(zpl.contains("^BQ"))
    }

    @Test("All shapes render at each DPI", arguments: [DPI.dpi152, .dpi200, .dpi203, .dpi300, .dpi600])
    func dpiShapesAtAllResolutions(dpi: DPI) {
        let label = ZPLLabel(width: 4, height: 4, dpi: dpi) {
            Box(at: .inches(0.25, 0.25), width: .inches(0.5), height: .inches(0.5))
            Circle(at: .inches(1.0, 0.25), diameter: .inches(0.5))
            Ellipse(at: .inches(1.75, 0.25), width: .inches(0.75), height: .inches(0.5))
        }
        let zpl = label.render()
        #expect(zpl.contains("^GB"))
        #expect(zpl.contains("^GC"))
        #expect(zpl.contains("^GE"))
    }
}

// MARK: - Barcode Validity Matrices

@Suite("Barcode Validity")
struct BarcodeValidityTests {

    // Barcode128: valid ASCII (incl. empty), invalid for non-ASCII control chars.
    @Test(arguments: [
        ("ABC123", true),
        ("", true),
        ("ABC\u{0080}123", false)
    ])
    func barcode128Validity(input: String, expectedValid: Bool) {
        #expect((Barcode128(input, at: .inches(0.5, 0.5)) != nil) == expectedValid)
    }

    // Code39: A-Z, 0-9, -.$/+% and space allowed; lowercase tolerated (uppercased);
    // empty valid; '@' and other symbols invalid.
    @Test(arguments: [
        ("HELLO-123", true),
        ("", true),
        ("HELLO-123 $50.00", true),
        ("hello@world", false),
        ("TEST@EMAIL", false)
    ])
    func code39Validity(input: String, expectedValid: Bool) {
        #expect((Code39(input, at: .inches(0.5, 0.5)) != nil) == expectedValid)
    }

    // Interleaved 2 of 5: digits only; empty valid; spaces/letters invalid.
    @Test(arguments: [
        ("1234567890", true),
        ("", true),
        ("123ABC", false),
        ("123 456", false)
    ])
    func interleaved2of5Validity(input: String, expectedValid: Bool) {
        #expect((Interleaved2of5(input, at: .inches(0.5, 0.5)) != nil) == expectedValid)
    }

    // EAN-13: 12 or 13 digits.
    @Test(arguments: [
        ("590123412345", true),     // 12 digits
        ("123456789012", true),     // 12 digits
        ("1234567890128", true),    // 13 digits, correct check digit (8)
        ("1234567890123", false),   // 13 digits, wrong check digit
        ("000000000000", true),     // leading zeros, 12 digits
        ("12345", false),           // too short
        ("12345678901234", false),  // 14, too long
        ("59012341234A", false)     // non-numeric
    ])
    func ean13Validity(input: String, expectedValid: Bool) {
        #expect((EAN13(input, at: .inches(0.5, 0.5)) != nil) == expectedValid)
    }

    // EAN-8: 7 or 8 digits.
    @Test(arguments: [
        ("1234567", true),   // 7 digits
        ("12345670", true),  // 8 digits (incl. check)
        ("12345", false),    // too short
        ("123456A", false)   // non-numeric
    ])
    func ean8Validity(input: String, expectedValid: Bool) {
        #expect((EAN8(input, at: .inches(0.5, 0.5)) != nil) == expectedValid)
    }

    // UPC-A: 11 or 12 digits.
    @Test(arguments: [
        ("01234567890", true),   // 11 digits
        ("12345678901", true),   // 11 digits
        ("1234567890", false),   // 10, too short
        ("12345", false),        // too short
        ("0123456789A", false)   // non-numeric
    ])
    func upcaValidity(input: String, expectedValid: Bool) {
        #expect((UPCA(input, at: .inches(0.5, 0.5)) != nil) == expectedValid)
    }

    // UPC-E: 6 digits, or 7 with an explicit check digit (^B9 field data).
    @Test(arguments: [
        ("123456", true),     // 6 digits
        ("1234567", true),    // 7 digits (explicit check digit)
        ("01234565", false),  // 8 digits - not encodable verbatim by ^B9
        ("12345", false),     // too short
        ("123456789", false), // too long
        ("12345A", false)     // non-numeric
    ])
    func upceValidity(input: String, expectedValid: Bool) {
        #expect((UPCE(input, at: .inches(0.5, 0.5)) != nil) == expectedValid)
    }

    // Intelligent Mail: valid lengths are exactly 20, 25, 29, 31 digits.
    @Test(arguments: [
        ("01234567890123456789", true),                   // 20
        ("0123456789012345678901234", true),              // 25
        ("01234567890123456789012345678", true),          // 29
        ("0123456789012345678901234567890", true),        // 31
        ("123456789", false),                             // 9
        ("1234567890123456789", false),                   // 19
        ("123456789012345678901", false),                 // 21
        ("12345678901234567890123", false),               // 23
        ("012345678901234567890123", false),              // 24
        ("1234567890123456789012345678901234", false),    // 34
        ("0123456789012345678A", false),                  // non-numeric (20 chars)
        ("05234567890123456789", false)                   // 20, Barcode-ID 2nd digit 5 (> 4)
    ])
    func intelligentMailValidity(input: String, expectedValid: Bool) {
        #expect((IntelligentMail(input, at: .inches(0.5, 0.5)) != nil) == expectedValid)
    }

    @Test("IntelligentMail emits ^BZ with postal type 3 and the data verbatim")
    func intelligentMailGeneratesBZ() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            IntelligentMail("01234567094987654321", at: .dots(10, 10))
        }
        let zpl = label.render()
        // The 5th ^BZ param must be 3 (Intelligent Mail); 0 would print POSTNET.
        #expect(zpl.contains("^BZN,"))
        #expect(zpl.contains(",N,N,3"))
        #expect(zpl.contains("^FD01234567094987654321^FS"))
    }
}

// MARK: - 1D Barcode Rendering

@Suite("1D Barcode Rendering")
struct OneDBarcodeRenderTests {

    @Test("Code39 uppercases field data")
    func code39Uppercases() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Code39("abc123", at: .inches(0.5, 0.5))
        }
        #expect(label.render().contains("^FDABC123^FS"))
    }

    @Test("Code39 lowercase converted to uppercase")
    func code39LowercaseConverted() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Code39("hello", at: .inches(0.25, 0.25))
        }
        #expect(label.render().contains("^FDHELLO^FS"))
    }

    @Test("Interleaved 2 of 5 renders ^B2 with field data")
    func interleaved2of5Renders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Interleaved2of5("123456", at: .inches(0.25, 0.25))?
                .height(.dots(80))
        }
        let zpl = label.render()
        #expect(zpl.contains("^B2"))
        #expect(zpl.contains("^FD123456^FS"))
    }

    @Test("Interleaved 2 of 5 check digit flag")
    func interleaved2of5WithCheckDigit() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Interleaved2of5("12345", at: .inches(0.25, 0.25))?
                .checkDigit(true)
        }
        #expect(label.render().contains(",Y^FD"))  // Check digit flag = Y
    }

    @Test("EAN-13 renders ^BE with field data")
    func ean13Renders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            EAN13("590123412345", at: .inches(0.25, 0.25))?
                .height(.dots(80))
        }
        let zpl = label.render()
        #expect(zpl.contains("^BE"))
        #expect(zpl.contains("^FD590123412345^FS"))
    }

    @Test("EAN-8 renders ^B8 with field data")
    func ean8Renders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            EAN8("1234567", at: .inches(0.25, 0.25))?
                .height(.dots(80))
        }
        let zpl = label.render()
        #expect(zpl.contains("^B8"))
        #expect(zpl.contains("^FD1234567^FS"))
    }

    @Test("EAN-8 text above flag")
    func ean8TextAbove() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            EAN8("1234567", at: .inches(0.25, 0.25))?
                .textAbove()
        }
        #expect(label.render().contains("^B8N,100,Y,Y"))  // Last Y = text above
    }

    @Test("UPC-A renders ^BU with field data")
    func upcaRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            UPCA("01234567890", at: .inches(0.25, 0.25))?
                .height(.dots(80))
        }
        let zpl = label.render()
        #expect(zpl.contains("^BU"))
        #expect(zpl.contains("^FD01234567890^FS"))
    }

    @Test("UPC-E renders ^B9 with field data")
    func upceRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            UPCE("123456", at: .inches(0.25, 0.25))?
                .height(.dots(80))
        }
        let zpl = label.render()
        #expect(zpl.contains("^B9"))
        #expect(zpl.contains("^FD123456^FS"))
    }

    @Test("UPC-E with options")
    func upceWithOptions() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            UPCE("123456", at: .inches(0.25, 0.25))?
                .showText(false)
                .checkDigit(false)
        }
        #expect(label.render().contains("^B9N,100,N,N,N"))
    }

    @Test("Intelligent Mail renders ^BZ with field data")
    func intelligentMailRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            IntelligentMail("01234567890123456789", at: .inches(0.25, 0.25))?
                .height(.dots(30))
        }
        let zpl = label.render()
        // The 5th ^BZ parameter must be 3 (USPS Intelligent Mail); it defaults
        // to 0 = POSTNET on real printers when omitted.
        #expect(zpl.contains("^BZN,30,N,N,3"))
        #expect(zpl.contains("^FD01234567890123456789^FS"))
    }

    @Test("Intelligent Mail rotated")
    func intelligentMailRotated() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            IntelligentMail("01234567890123456789", at: .inches(0.25, 0.25))?
                .rotated(.rotated90)
        }
        #expect(label.render().contains("^BZR,"))  // R = rotated 90
    }
}

// MARK: - 2D Barcode Rendering

@Suite("2D Barcode Rendering")
struct TwoDBarcodeRenderTests {

    @Test("QR code renders ^BQN with magnification")
    func qrCodeRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("https://example.com", at: .inches(0.5, 0.5))
                .magnification(5)
        }
        #expect(label.render().contains("^BQN,2,5"))
    }

    @Test("DataMatrix renders ^BXN with size")
    func dataMatrixRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DataMatrix("SERIAL123", at: .inches(0.5, 0.5))
                .moduleSize(5)
        }
        #expect(label.render().contains("^BXN,5"))
    }

    @Test("PDF417 renders ^B7 with field data")
    func pdf417Renders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            PDF417("SHIPPING-MANIFEST-12345", at: .inches(0.25, 0.25))
                .rowHeight(.dots(8))
        }
        let zpl = label.render()
        #expect(zpl.contains("^B7"))
        #expect(zpl.contains("^FDSHIPPING-MANIFEST-12345^FS"))
    }

    @Test("PDF417 with options")
    func pdf417WithOptions() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            PDF417("ID-CARD-DATA", at: .inches(0.25, 0.25))
                .securityLevel(3)
                .columns(5)
                .truncated()
        }
        #expect(label.render().contains("^B7N,10,3,5,0,Y"))
    }

    @Test("Aztec renders ^B0 with field data")
    func aztecRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Aztec("TICKET-DATA-12345", at: .inches(0.5, 0.5))
                .magnification(5)
        }
        let zpl = label.render()
        #expect(zpl.contains("^B0"))
        #expect(zpl.contains("^FDTICKET-DATA-12345^FS"))
    }

    @Test("Aztec with options")
    func aztecWithOptions() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Aztec("SECURE-DATA", at: .inches(0.5, 0.5))
                .magnification(4)
                .errorCorrection(50)
                .extendedChannel(true)
        }
        #expect(label.render().contains("^B0N,4,Y,50"))
    }

    @Test("DataMatrix columns/rows clamped to ^BX range 9-49")
    func dataMatrixColumnsRowsClamped() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            DataMatrix("DATA", at: .inches(0.5, 0.5))
                .columns(1000)
                .rows(0)
        }
        #expect(label.render().contains(",49,9^FD"))
    }
}

// MARK: - Clamping

@Suite("Value Clamping")
struct ClampingTests {

    // Barcode128 ^BY module width: clamped to 1...10.
    @Test(arguments: [
        (0, "^BY1"),    // below min
        (1, "^BY1"),    // boundary min
        (10, "^BY10"),  // boundary max
        (20, "^BY10")   // above max
    ])
    func barcode128ModuleWidthClamp(input: Int, expected: String) {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("TEST", at: .inches(0.25, 0.25))?
                .moduleWidth(input)
        }
        #expect(label.render().contains(expected))
    }

    // QR code magnification: clamped to 1...10.
    @Test(arguments: [
        (0, "^BQN,2,1"),
        (20, "^BQN,2,10")
    ])
    func qrCodeMagnificationClamp(input: Int, expected: String) {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("TEST", at: .inches(0.5, 0.5))
                .magnification(input)
        }
        #expect(label.render().contains(expected))
    }

    // DataMatrix size: clamped to 1...10.
    @Test(arguments: [
        (0, "^BXN,1"),
        (20, "^BXN,10")
    ])
    func dataMatrixSizeClamp(input: Int, expected: String) {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DataMatrix("TEST", at: .inches(0.5, 0.5))
                .moduleSize(input)
        }
        #expect(label.render().contains(expected))
    }

    // Aztec magnification: clamped to 1...10.
    @Test(arguments: [
        (0, "^B0N,1"),
        (20, "^B0N,10")
    ])
    func aztecMagnificationClamp(input: Int, expected: String) {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Aztec("TEST", at: .inches(0.5, 0.5))
                .magnification(input)
        }
        #expect(label.render().contains(expected))
    }

    // Label print darkness ^MD: clamped to 0...30.
    @Test(arguments: [
        (-10, "^MD0"),
        (0, "^MD0"),
        (15, "^MD15"),
        (30, "^MD30"),
        (50, "^MD30")
    ])
    func printDarknessClamp(input: Int, expected: String) {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printDarkness(input)
        #expect(label.render().contains(expected))
    }

    @Test("Print darkness over max does not leak raw value")
    func printDarknessOverMaxNoLeak() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printDarkness(50)
        #expect(!label.render().contains("^MD50"))
    }

    // Box corner radius: clamped to 0...8. Rendered as trailing ",N^FS".
    @Test(arguments: [
        (-5, ",0^FS"),
        (0, ",0^FS"),
        (8, ",8^FS"),
        (15, ",8^FS")
    ])
    func boxCornerRadiusClamp(input: Int, expected: String) {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .cornerRadius(input)
        }
        #expect(label.render().contains(expected))
    }
}

// MARK: - Shapes

@Suite("Shapes")
struct ShapeTests {

    @Test("Box renders ^GB")
    func boxRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .inches(0.25, 0.25), width: .inches(1.0), height: .inches(0.5))
                .thickness(3)
        }
        #expect(label.render().contains("^GB"))
    }

    @Test("Filled box has thickness equal to min(width, height)")
    func filledBoxRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .inches(0.25, 0.25), width: .dots(100), height: .dots(50))
                .filled()
        }
        #expect(label.render().contains("^GB100,50,50"))
    }

    // Zero/negative dimensions are clamped to 1 dot: out-of-range ^GB
    // parameters have firmware-dependent handling.
    @Test(arguments: [
        (0, 100, "^GB1,100,"),
        (100, 0, "^GB100,1,"),
        (0, 0, "^GB1,1,")
    ])
    func boxZeroDimensions(width: Int, height: Int, expected: String) {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(width), height: .dots(height))
        }
        #expect(label.render().contains(expected))
    }

    @Test("Box white color")
    func boxWhiteColor() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .white()
        }
        #expect(label.render().contains(",W,"))
    }

    @Test("Circle renders ^GC")
    func circleRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Circle(at: .inches(0.5, 0.5), diameter: .inches(1.0))
                .thickness(3)
        }
        #expect(label.render().contains("^GC"))
    }

    @Test("Filled circle has thickness equal to diameter")
    func filledCircleRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Circle(at: .inches(0.5, 0.5), diameter: .dots(100))
                .filled()
        }
        #expect(label.render().contains("^GC100,100,B"))
    }

    @Test("Circle zero diameter is clamped to 1 dot")
    func circleZeroDiameter() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Circle(at: .dots(50, 50), diameter: .dots(0))
        }
        #expect(label.render().contains("^GC1,"))
    }

    @Test("Circle white color")
    func circleWhiteColor() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Circle(at: .dots(50, 50), diameter: .dots(100))
                .white()
        }
        #expect(label.render().contains(",W^FS"))
    }

    @Test("Ellipse renders ^GE")
    func ellipseRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .inches(0.5, 0.5), width: .inches(1.0), height: .inches(0.5))
                .thickness(2)
        }
        #expect(label.render().contains("^GE"))
    }

    @Test("Filled ellipse has thickness = min(width, height)")
    func filledEllipseRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .dots(50, 50), width: .dots(200), height: .dots(100))
                .filled()
        }
        #expect(label.render().contains("^GE200,100,100"))
    }

    // Zero/negative dimensions are clamped to 1 dot.
    @Test(arguments: [
        (0, 100, "^GE1,100,"),
        (100, 0, "^GE100,1,")
    ])
    func ellipseZeroDimensions(width: Int, height: Int, expected: String) {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .dots(50, 50), width: .dots(width), height: .dots(height))
        }
        #expect(label.render().contains(expected))
    }

    @Test("Ellipse white color")
    func ellipseWhiteColor() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Ellipse(at: .dots(50, 50), width: .dots(200), height: .dots(100))
                .white()
        }
        #expect(label.render().contains(",W^FS"))
    }

    @Test("Diagonal line renders ^GD")
    func diagonalLineRenders() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DiagonalLine(at: .inches(0.25, 0.25), width: .inches(1.0), height: .inches(1.0))
                .thickness(3)
        }
        #expect(label.render().contains("^GD"))
    }

    @Test("Diagonal line left-leaning direction")
    func diagonalLineDirections() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DiagonalLine(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .direction(.leftLeaning)
        }
        #expect(label.render().contains(",L^FS"))
    }

    @Test("Diagonal line zero dimensions are clamped to 1 dot")
    func diagonalLineZeroDimensions() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DiagonalLine(at: .dots(50, 50), width: .dots(0), height: .dots(0))
        }
        #expect(label.render().contains("^GD1,1,"))
    }

    @Test("Diagonal line white color")
    func diagonalLineWhiteColor() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            DiagonalLine(at: .dots(50, 50), width: .dots(100), height: .dots(100))
                .white()
        }
        #expect(label.render().contains(",W,"))
    }
}

// MARK: - Lines

@Suite("Lines")
struct LineTests {

    @Test("Horizontal line renders ^GB")
    func horizontalLineRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .inches(0.25, 0.5), length: .inches(2.0))
        }
        #expect(label.render().contains("^GB"))
    }

    @Test("Horizontal line custom thickness ^GB[length],[thickness],[thickness]")
    func horizontalLineWithCustomThickness() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .dots(50, 50), length: .dots(200), thickness: .dots(5))
        }
        #expect(label.render().contains("^GB200,5,5"))
    }

    @Test("Horizontal line in inches resolves position and dimensions")
    func horizontalLineInInches() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .inches(0.25, 0.25), length: .inches(2.0), thickness: .inches(0.02))
        }
        let zpl = label.render()
        // 0.25 * 203 = 50.75 -> 51
        #expect(zpl.contains("^FO51,51"))
        // 2.0 * 203 = 406, 0.02 * 203 = 4.06 -> 4
        #expect(zpl.contains("^GB406,4,4"))
    }

    @Test("Horizontal line in millimeters renders")
    func horizontalLineInMillimeters() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .mm(5, 5), length: .mm(50))
        }
        #expect(label.render().contains("^GB"))
    }

    @Test("Horizontal line zero length clamps to >= 1 dot")
    func horizontalLineZeroLength() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .dots(50, 50), length: .dots(0))
        }
        // Length clamps to 1; a ^GB0 dimension is out-of-range on real firmware.
        #expect(label.render().contains("^GB1,2,2"))
    }

    @Test("Horizontal line default thickness is 2 dots")
    func horizontalLineDefaultThickness() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            HorizontalLine(at: .dots(0, 0), length: .dots(100))
        }
        #expect(label.render().contains("^GB100,2,2"))
    }

    @Test("Vertical line renders ^GB")
    func verticalLineRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .inches(0.5, 0.25), length: .inches(1.0))
        }
        #expect(label.render().contains("^GB"))
    }

    @Test("Vertical line custom thickness ^GB[thickness],[length],[thickness]")
    func verticalLineWithCustomThickness() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .dots(50, 50), length: .dots(200), thickness: .dots(5))
        }
        #expect(label.render().contains("^GB5,200,5"))
    }

    @Test("Vertical line in dots resolves position and default thickness")
    func verticalLineInDots() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .dots(100, 100), length: .dots(150))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FO100,100"))
        #expect(zpl.contains("^GB2,150,2"))  // Default thickness = 2
    }

    @Test("Vertical line in inches resolves position")
    func verticalLineInInches() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .inches(0.5, 0.5), length: .inches(1.0), thickness: .inches(0.05))
        }
        // 0.5 inches * 203 DPI = 101.5 -> 102 dots
        #expect(label.render().contains("^FO102,102"))
    }

    @Test("Vertical line in millimeters renders")
    func verticalLineInMillimeters() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .mm(10, 10), length: .mm(25.4))  // 25.4mm = 1 inch
        }
        #expect(label.render().contains("^GB"))
    }

    @Test("Vertical line zero length clamps to >= 1 dot")
    func verticalLineZeroLength() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .dots(50, 50), length: .dots(0))
        }
        // Length clamps to 1; a ^GB0 dimension is out-of-range on real firmware.
        #expect(label.render().contains("^GB2,1,2"))
    }

    @Test("Vertical line default thickness is 2 dots")
    func verticalLineDefaultThickness() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            VerticalLine(at: .dots(0, 0), length: .dots(100))
        }
        #expect(label.render().contains("^GB2,100,2"))
    }
}

// MARK: - TextBlock

@Suite("TextBlock")
struct TextBlockTests {

    @Test("TextBlock renders ^FB with center alignment")
    func textBlockRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("This is a long text that should wrap", at: .inches(0.25, 0.25), width: .inches(2.0))
                .maxLines(3)
                .alignment(.center)
        }
        let zpl = label.render()
        #expect(zpl.contains("^FB"))
        #expect(zpl.contains(",C,"))
    }

    @Test("TextBlock baseline uses ^FT instead of ^FO")
    func textBlockBaseline() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Baseline block", at: .inches(0.25, 0.5), width: .inches(2.0))
                .baseline()
        }
        let zpl = label.render()
        #expect(zpl.contains("^FT"))
        #expect(!zpl.contains("^FO"))
    }

    @Test("TextBlock rotated emits ^A0R")
    func textBlockRotated() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Rotated", at: .inches(0.25, 0.5), width: .inches(2.0))
                .rotated(.rotated90)
        }
        #expect(label.render().contains("^A0R,"))  // R = rotated 90
    }

    @Test("TextBlock reversed emits ^FR")
    func textBlockReversed() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Reversed", at: .inches(0.25, 0.5), width: .inches(2.0))
                .reversed()
        }
        #expect(label.render().contains("^FR"))  // Reverse field
    }

    @Test("TextBlock converts newlines to ZPL line breaks")
    func textBlockWithNewlines() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Line 1\nLine 2\nLine 3", at: .inches(0.25, 0.25), width: .inches(2.0))
                .maxLines(3)
        }
        #expect(label.render().contains("Line 1\\&Line 2\\&Line 3"))
    }

    @Test("TextBlock combined options")
    func textBlockCombinedOptions() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Important\nMessage", at: .inches(0.25, 0.25), width: .inches(2.0))
                .font(.default, height: .dots(40))
                .alignment(.center)
                .lineSpacing(.dots(5))
                .reversed()
                .maxLines(2)
        }
        let zpl = label.render()
        #expect(zpl.contains("^FR"))
        #expect(zpl.contains("^FB"))
        #expect(zpl.contains(",C,"))  // Center alignment
        #expect(zpl.contains("\\&"))  // Line break
    }

    @Test("TextBlock unlimited maxLines emits 9999, not 0")
    func textBlockUnlimitedMaxLines() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            // Default maxLines is 0 (unlimited).
            TextBlock("Wrapping text", at: .inches(0.25, 0.25), width: .inches(2.0))
        }
        let dots = DPI.dpi203.dots(fromInches: 2.0)
        let zpl = label.render()
        #expect(zpl.contains("^FB\(dots),9999,"))
        #expect(!zpl.contains("^FB\(dots),0,"))
    }

    @Test("TextBlock clamps maxLines to 9999")
    func textBlockClampsMaxLines() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            TextBlock("Wrapping text", at: .inches(0.25, 0.25), width: .inches(2.0))
                .maxLines(100000)
        }
        #expect(label.render().contains(",9999,"))
    }
}

// MARK: - Baseline Positioning (Text)

@Suite("Baseline Positioning")
struct BaselineTests {

    @Test("Text baseline uses ^FT instead of ^FO")
    func textBaseline() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Baseline", at: .inches(0.5, 0.5))
                .baseline()
        }
        let zpl = label.render()
        #expect(zpl.contains("^FT"))
        #expect(!zpl.contains("^FO"))
    }
}

// MARK: - Serial Numbers

@Suite("Serial Numbers")
struct SerialNumberTests {

    @Test("Serial number increment renders ^SN")
    func serialNumberRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            SerialNumber("001", at: .inches(0.25, 0.25))
                .increment(1)
        }
        #expect(label.render().contains("^SN001,1,Y"))
    }

    @Test("Serial number decrement without leading zeros")
    func serialNumberDecrement() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            SerialNumber("100", at: .inches(0.25, 0.25))
                .increment(-1)
                .leadingZeros(false)
        }
        #expect(label.render().contains("^SN100,-1,N"))
    }

    @Test("Serial number strips commas and escapes caret/tilde")
    func serialNumberInjectionRejected() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            SerialNumber("1,2^XZ~JA", at: .inches(0.25, 0.25))
        }
        let zpl = label.render()
        // Comma stripped (would otherwise corrupt ^SN parameters); ^ and ~
        // hex-escaped via ^FH so they are inert literal data.
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains("^SN12_5EXZ_7EJA,1,Y"))
        // No live injected commands survive.
        #expect(zpl.components(separatedBy: "^XZ").count == 2)
        #expect(!zpl.contains("~JA"))
    }
}

// MARK: - Print Configuration (label-level)

@Suite("Print Configuration")
struct PrintConfigTests {

    @Test("Print quantity emits ^PQ")
    func printQuantity() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printQuantity(5)
        #expect(label.render().contains("^PQ5"))
    }

    // Print speed ^PR with optional slew/backfeed.
    @Test(arguments: [
        ("^PR6", false, false),       // speed only
        ("^PR6,8", true, false),      // speed + slew
        ("^PR6,8,4", true, true),     // speed + slew + backfeed
        ("^PR6,,4", false, true)      // speed + backfeed only
    ])
    func printSpeedVariants(expected: String, withSlew: Bool, withBackfeed: Bool) {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }
        let configured: ZPLLabel
        switch (withSlew, withBackfeed) {
        case (false, false): configured = label.printSpeed(6)
        case (true, false): configured = label.printSpeed(6, slew: 8)
        case (true, true): configured = label.printSpeed(6, slew: 8, backfeed: 4)
        case (false, true): configured = label.printSpeed(6, backfeed: 4)
        }
        #expect(configured.render().contains(expected))
    }

    @Test("Default font emits ^CF0 with height")
    func defaultFont() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.defaultFont(.default, height: 40)
        #expect(label.render().contains("^CF0,40"))
    }

    @Test("Default font with font A emits ^CFA")
    func defaultFontWithDifferentFonts() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.defaultFont(.a, height: 50)
        #expect(label.render().contains("^CFA,50"))
    }

    @Test("Label home emits ^LH")
    func labelHome() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.labelHome(100, 50)
        #expect(label.render().contains("^LH100,50"))
    }

    @Test("Label home at origin emits ^LH0,0")
    func labelHomeAtOrigin() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.labelHome(0, 0)
        #expect(label.render().contains("^LH0,0"))
    }

    @Test("Print darkness emits ^MD")
    func printDarkness() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }.printDarkness(15)
        #expect(label.render().contains("^MD15"))
    }

    @Test("Combined label config emits all commands")
    func combinedLabelConfig() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }
        .labelHome(50, 25)
        .defaultFont(.default, height: 35)
        .printDarkness(20)
        .reversePrint()

        let zpl = label.render()
        #expect(zpl.contains("^LH50,25"))
        #expect(zpl.contains("^CF0,35"))
        #expect(zpl.contains("^MD20"))
        #expect(zpl.contains("^LRY"))
    }

    @Test("Config command order: ^LH before ^PW")
    func labelConfigOrder() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }
        .labelHome(10, 20)
        .printDarkness(15)

        let zpl = label.render()
        let lhIndex = try! #require(zpl.range(of: "^LH")).lowerBound
        let pwIndex = try! #require(zpl.range(of: "^PW")).lowerBound
        #expect(lhIndex < pwIndex)
    }

    // Config commands absent by default.
    @Test(arguments: ["^CF", "^LH", "^MD"])
    func configCommandsNotPresentByDefault(command: String) {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Test", at: .inches(0.25, 0.25))
        }
        #expect(!label.render().contains(command))
    }
}

// MARK: - Reverse Print

@Suite("Reverse Print")
struct ReversePrintTests {

    // Label-wide reverse ^LRY: present only when enabled.
    @Test(arguments: [
        (true, true),    // .reversePrint() -> present
        (false, false)   // .reversePrint(false) -> absent
    ])
    func reversePrintToggle(enabled: Bool, expectedPresent: Bool) {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("X", at: .inches(0.25, 0.25))
        }.reversePrint(enabled)
        #expect(label.render().contains("^LRY") == expectedPresent)
    }

    @Test("Reverse print absent by default")
    func reversePrintDefault() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Normal", at: .inches(0.25, 0.25))
        }
        #expect(!label.render().contains("^LRY"))
    }
}

// MARK: - Comments

@Suite("Comments")
struct CommentTests {

    @Test("Comment renders ^FX")
    func commentRenders() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Comment("This is a debugging note")
            Text("Hello", at: .inches(0.25, 0.25))
        }
        #expect(label.render().contains("^FX This is a debugging note ^FS"))
    }

    @Test("Multiple comments and content all render")
    func commentNotPrinted() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Comment("Section 1: Header")
            Text("Title", at: .inches(0.25, 0.25))
            Comment("Section 2: Content")
            Text("Body", at: .inches(0.25, 0.5))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FX Section 1: Header ^FS"))
        #expect(zpl.contains("^FX Section 2: Content ^FS"))
        #expect(zpl.contains("^FDTitle^FS"))
        #expect(zpl.contains("^FDBody^FS"))
    }

    @Test("Empty comment still renders ^FX")
    func commentEmpty() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Comment("")
            Text("Test", at: .inches(0.25, 0.25))
        }
        #expect(label.render().contains("^FX  ^FS"))
    }

    @Test("Comment strips caret and tilde to prevent breakout")
    func commentStripsControlChars() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Comment("evil ^XZ ~JA stuff")
            Text("Safe", at: .inches(0.25, 0.25))
        }
        let zpl = label.render()
        // The injected ^XZ / ~JA must not survive inside the comment body.
        #expect(zpl.contains("^FX evil  XZ  JA stuff ^FS"))
        // Only the legitimate label-end ^XZ should remain in the stream.
        #expect(zpl.components(separatedBy: "^XZ").count == 2)
        #expect(!zpl.contains("~JA"))
    }
}

// MARK: - ZPLTemplate

@Suite("ZPLTemplate")
struct ZPLTemplateTests {

    @Test("Template renders with variable substitution")
    func templateRendersWithSubstitution() {
        let template = ZPLTemplate(width: 4, height: 6, dpi: .dpi203) {
            Text("FROM: {{sender_name}}", at: .inches(0.2, 0.2))
                .font(.default, height: .inches(0.1))
            Barcode128("{{tracking_number}}", at: .inches(0.2, 1.7))?
                .height(.inches(0.7))
        }
        let zpl = template.render(substituting: [
            "sender_name": "ACME",
            "tracking_number": "1Z999"
        ])
        #expect(zpl.contains("FROM: ACME"))
        #expect(zpl.contains("1Z999"))
        #expect(!zpl.contains("{{"))
        #expect(zpl.hasPrefix("^XA"))
        #expect(zpl.hasSuffix("^XZ"))
    }

    @Test("Template escapes injected substitution values")
    func templateEscapesValues() {
        let template = ZPLTemplate(width: 4, height: 2, dpi: .dpi203) {
            Text("ID: {{id}}", at: .inches(0.2, 0.2))
        }
        let zpl = template.render(substituting: ["id": "a^XZb"])
        // Injected ^XZ is hex-escaped, so only the real label-end ^XZ remains.
        #expect(zpl.components(separatedBy: "^XZ").count == 2)
    }
}

// MARK: - String Escaping

@Suite("String Escaping")
struct StringEscapingTests {

    @Test("Special chars in text enable hex mode and escape caret/tilde/underscore")
    func specialCharactersEscaped() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Price: $5 (50% off) ^test~ _under", at: .inches(0.25, 0.25))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FH"))   // hex mode
        #expect(zpl.contains("_5E"))   // ^ escaped
        #expect(zpl.contains("_7E"))   // ~ escaped
        #expect(zpl.contains("_5F"))   // _ escaped
    }

    // Single special characters each enable hex mode and escape to their hex code.
    @Test(arguments: [
        ("A^B", "_5E"),  // caret
        ("A~B", "_7E"),  // tilde
        ("A_B", "_5F")   // underscore
    ])
    func singleSpecialCharEscaping(input: String, expectedHex: String) {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text(input, at: .inches(0.25, 0.25))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains(expectedHex))
    }

    @Test("All special chars together escape individually")
    func multipleSpecialCharsEscaping() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("^~_", at: .inches(0.25, 0.25))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains("_5E"))
        #expect(zpl.contains("_7E"))
        #expect(zpl.contains("_5F"))
    }

    @Test("No special chars means no hex mode")
    func noSpecialCharsNoHexMode() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Hello World 123", at: .inches(0.25, 0.25))
        }
        let zpl = label.render()
        #expect(!zpl.contains("^FH"))
        #expect(zpl.contains("^FDHello World 123^FS"))
    }

    // Non-ASCII / multibyte / emoji all enable hex mode.
    @Test(arguments: ["Café", "日本語", "Hello 👋"])
    func nonASCIIEnablesHexMode(input: String) {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text(input, at: .inches(0.25, 0.25))
        }
        #expect(label.render().contains("^FH"))
    }

    @Test("Mixed ASCII and special chars escape correctly")
    func mixedASCIIAndSpecialChars() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Item^1: $10.00", at: .inches(0.25, 0.25))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains("Item"))
        #expect(zpl.contains("_5E"))
        #expect(zpl.contains(": $10.00"))
    }
}

// MARK: - Barcode Field-Data Escaping

@Suite("Barcode Module Width (^BY)")
struct BarcodeModuleWidthTests {

    @Test("1D barcodes emit ^BY with the default module width")
    func oneDBarcodesEmitDefaultBY() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Code39("ABC", at: .dots(10, 10))
            EAN13("590123412345", at: .dots(10, 60))
            EAN8("1234567", at: .dots(10, 110))
            UPCA("01234567890", at: .dots(10, 160))
            UPCE("012345", at: .dots(10, 210))
        }
        let zpl = label.render()
        // Every 1D barcode now emits its own ^BY so nothing leaks in via stickiness.
        #expect(zpl.components(separatedBy: "^BY2").count - 1 == 5)
    }

    @Test("moduleWidth is emitted and clamped to 1...10")
    func moduleWidthClamped() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            EAN13("590123412345", at: .dots(10, 10))?.moduleWidth(4)
            Code39("ABC", at: .dots(10, 60))?.moduleWidth(99)   // clamps to 10
        }
        let zpl = label.render()
        #expect(zpl.contains("^BY4"))
        #expect(zpl.contains("^BY10"))
    }

    @Test("A preceding moduleWidth does not leak into a following 1D barcode")
    func moduleWidthDoesNotLeak() {
        // ^BY is sticky within a format: before the fix, Code39 would inherit
        // Barcode128's module width. Now each barcode resets it.
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("SKU-1", at: .dots(10, 10))?.moduleWidth(5)
            Code39("ABC", at: .dots(10, 60))
        }
        let zpl = label.render()
        #expect(zpl.contains("^BY5"))  // Barcode128's own width
        #expect(zpl.contains("^BY2"))  // Code39 resets to its default, not 5
    }
}

@Suite("Barcode Field-Data Escaping")
struct BarcodeEscapingTests {

    @Test("Barcode128 escapes special chars without leaking control sequence")
    func barcode128EscapesSpecialChars() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("A^B~C_D", at: .inches(0.25, 0.5))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains("^FDA_5EB_7EC_5FD^FS"))
        #expect(!zpl.contains("^FDA^B~C_D^FS"))
    }

    @Test("Barcode128 normal data unchanged, no hex mode")
    func barcode128NormalDataUnchanged() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("ABC123", at: .inches(0.25, 0.5))
        }
        let zpl = label.render()
        #expect(!zpl.contains("^FH"))
        #expect(zpl.contains("^FDABC123^FS"))
    }

    @Test("Barcode128 escapes literal > as >0 invocation code")
    func barcode128EscapesGreaterThan() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("PRICE>5", at: .inches(0.25, 0.5))
        }
        let zpl = label.render()
        // A raw `>` would be read as a subset/function switch; `>0` encodes a
        // literal `>`, so the printed payload matches "PRICE>5" verbatim.
        #expect(zpl.contains("^FDPRICE>05^FS"))
        #expect(!zpl.contains("^FDPRICE>5^FS"))
    }

    @Test("Barcode128 escapes > alongside hex-escaped chars")
    func barcode128EscapesGreaterThanWithHex() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("A>_B", at: .inches(0.25, 0.5))
        }
        let zpl = label.render()
        // `>` -> `>0` runs before hex escaping; `_` (0x5F) still becomes `_5F`.
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains("^FDA>0_5FB^FS"))
    }

    @Test("QR code escapes payload but keeps MA, prefix unescaped")
    func qrCodeEscapesSpecialCharsKeepingPrefix() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("a^b~c_d", at: .inches(0.5, 0.5))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains("^FDMA,a_5Eb_7Ec_5Fd^FS"))
    }

    @Test("QR code normal data unchanged, no hex mode")
    func qrCodeNormalDataUnchanged() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("https://example.com", at: .inches(0.5, 0.5))
        }
        let zpl = label.render()
        #expect(!zpl.contains("^FH"))
        #expect(zpl.contains("^FDMA,https://example.com^FS"))
    }

    @Test("PDF417 escapes special chars")
    func pdf417EscapesSpecialChars() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            PDF417("x^y~z_w", at: .inches(0.25, 0.25))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains("^FDx_5Ey_7Ez_5Fw^FS"))
    }

    @Test("PDF417 normal data unchanged, no hex mode")
    func pdf417NormalDataUnchanged() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            PDF417("SHIPPING-MANIFEST-12345", at: .inches(0.25, 0.25))
        }
        let zpl = label.render()
        #expect(!zpl.contains("^FH"))
        #expect(zpl.contains("^FDSHIPPING-MANIFEST-12345^FS"))
    }

    @Test("DataMatrix escapes special chars")
    func dataMatrixEscapesSpecialChars() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            DataMatrix("d^m~x_y", at: .inches(0.5, 0.5))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains("^FDd_5Em_7Ex_5Fy^FS"))
    }

    @Test("DataMatrix normal data unchanged, no hex mode")
    func dataMatrixNormalDataUnchanged() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            DataMatrix("SERIAL123", at: .inches(0.5, 0.5))
        }
        let zpl = label.render()
        #expect(!zpl.contains("^FH"))
        #expect(zpl.contains("^FDSERIAL123^FS"))
    }

    @Test("Aztec escapes special chars")
    func aztecEscapesSpecialChars() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Aztec("a^z~q_r", at: .inches(0.5, 0.5))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FH"))
        #expect(zpl.contains("^FDa_5Ez_7Eq_5Fr^FS"))
    }

    @Test("Aztec normal data unchanged, no hex mode")
    func aztecNormalDataUnchanged() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Aztec("TICKET-DATA-12345", at: .inches(0.5, 0.5))
        }
        let zpl = label.render()
        #expect(!zpl.contains("^FH"))
        #expect(zpl.contains("^FDTICKET-DATA-12345^FS"))
    }
}

// MARK: - Template Substitution

@Suite("Template Substitution")
struct TemplateSubstitutionTests {

    @Test("Single variable substitution")
    func templateSubstitution() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Order: {{orderNumber}}", at: .inches(0.25, 0.25))
        }
        let zpl = label.render(substituting: ["orderNumber": "12345"])
        #expect(zpl.contains("^FDOrder: 12345^FS"))
        #expect(!zpl.contains("{{orderNumber}}"))
    }

    @Test("Multiple variable substitution across elements")
    func templateSubstitutionMultiple() {
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
        #expect(zpl.contains("^FDJohn Smith^FS"))
        #expect(zpl.contains("^FD123 Main St^FS"))
        #expect(zpl.contains("^FD1Z999AA1^FS"))
    }

    @Test("Substitution inside QR code keeps prefix")
    func templateSubstitutionWithQRCode() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("{{url}}", at: .inches(0.5, 0.5))
                .magnification(5)
        }
        let zpl = label.render(substituting: ["url": "https://example.com/order/12345"])
        #expect(zpl.contains("MA,https://example.com/order/12345^FS"))
        #expect(!zpl.contains("{{url}}"))
    }

    @Test("Unsubstituted variables remain")
    func templateUnsubstitutedVariablesRemain() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("{{name}} - {{missing}}", at: .inches(0.25, 0.25))
        }
        let zpl = label.render(substituting: ["name": "Test"])
        #expect(zpl.contains("Test"))
        #expect(zpl.contains("{{missing}}"))
    }

    @Test("Substitution value attempting ^XZ injection is neutralized")
    func substitutionEscapesInjectionValue() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("{{val}}", at: .inches(0.25, 0.25))
        }
        let zpl = label.render(substituting: ["val": "X^XZ"])
        #expect(!zpl.contains("X^XZ"))      // injection neutralized
        #expect(zpl.contains("X_5EXZ"))     // caret hex-escaped
        #expect(zpl.components(separatedBy: "^XZ").count - 1 == 1)
    }

    @Test("Normal substitution value unchanged")
    func substitutionNormalValueUnchanged() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Order: {{orderNumber}}", at: .inches(0.25, 0.25))
        }
        let zpl = label.render(substituting: ["orderNumber": "12345"])
        #expect(zpl.contains("^FDOrder: 12345^FS"))
    }

    @Test("Longer key wins over prefix key")
    func substitutionDeterministicWithPrefixKeys() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("{{itemCount}}", at: .inches(0.25, 0.25))
        }
        let zpl = label.render(substituting: ["item": "WRONG", "itemCount": "42"])
        #expect(zpl.contains("^FD42^FS"))
        #expect(!zpl.contains("WRONG"))
    }
}

// MARK: - Complex Layouts & Builder Logic

@Suite("Complex Layouts")
struct ComplexLayoutTests {

    @Test("Overlapping elements all render")
    func multipleOverlappingElements() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Box(at: .dots(50, 50), width: .dots(300), height: .dots(200))
                .filled()
            Text("OVERLAPPING", at: .dots(100, 100))
                .font(.default, height: .dots(40))
                .reversed()
            Circle(at: .dots(200, 100), diameter: .dots(80))
                .white()
        }
        let zpl = label.render()
        #expect(zpl.contains("^GB300,200,"))  // Filled box
        #expect(zpl.contains("^FR"))           // Reversed text
        #expect(zpl.contains("^GC80,"))        // Circle
    }

    @Test("Many element types render in a shipping label")
    func manyElementsLabel() {
        let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
            Text("SHIPPING LABEL", at: .dots(50, 30))
                .font(.default, height: .dots(40))
            HorizontalLine(at: .dots(50, 80), length: .dots(700), thickness: .dots(3))
            TextBlock("John Doe\n123 Main Street\nAnytown, ST 12345", at: .dots(50, 100), width: .dots(400))
                .maxLines(4)
            Barcode128("1Z999AA10123456784", at: .dots(50, 300))?
                .height(.dots(100))
                .moduleWidth(2)
            QRCode("https://track.example.com/1Z999AA10123456784", at: .dots(500, 100))
                .magnification(4)
            HorizontalLine(at: .dots(50, 500), length: .dots(700), thickness: .dots(2))
            Text("Thank you for your order!", at: .dots(50, 520))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FDSHIPPING LABEL"))
        #expect(zpl.contains("^FB"))
        #expect(zpl.contains("^BC"))
        #expect(zpl.contains("^BQ"))
        #expect(zpl.contains("Thank you"))
    }

    @Test("Conditional builder logic includes/excludes elements")
    func conditionalBuilderLogic() {
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
        #expect(zpl.contains("^BC"))
        #expect(!zpl.contains("^BQ"))
    }

    @Test("Loop builder logic renders each item")
    func loopBuilderLogic() {
        let items = ["Apple", "Banana", "Cherry"]
        let label = ZPLLabel(width: 4, height: 3, dpi: .dpi203) {
            for (index, item) in items.enumerated() {
                Text(item, at: .dots(50, 50 + index * 60))
            }
        }
        let zpl = label.render()
        #expect(zpl.contains("^FDApple"))
        #expect(zpl.contains("^FDBanana"))
        #expect(zpl.contains("^FDCherry"))
    }

    @Test("Failable barcode in builder: valid present, invalid dropped")
    func optionalElementsInBuilder() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Always present", at: .dots(50, 50))
            Barcode128("VALID123", at: .dots(50, 100))
            Barcode128("INVALID\u{0080}", at: .dots(50, 200))
        }
        let zpl = label.render()
        #expect(zpl.contains("^FDVALID123"))
        #expect(!zpl.contains("INVALID"))
    }

    @Test("Mixed element types all render")
    func mixedElementTypesLabel() {
        let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
            Text("Title", at: .dots(50, 30))
            TextBlock("Description here", at: .dots(50, 70), width: .dots(300))
            Box(at: .dots(400, 30), width: .dots(100), height: .dots(80))
            Circle(at: .dots(550, 50), diameter: .dots(60))
            Ellipse(at: .dots(650, 30), width: .dots(100), height: .dots(60))
            HorizontalLine(at: .dots(50, 150), length: .dots(700))
            VerticalLine(at: .dots(400, 200), length: .dots(300))
            DiagonalLine(at: .dots(450, 200), width: .dots(100), height: .dots(100))
            Barcode128("BC128", at: .dots(50, 200))
            Code39("CODE39", at: .dots(50, 350))
            QRCode("QR", at: .dots(50, 500))
            DataMatrix("DM", at: .dots(200, 500))
            Comment("End of label")
        }
        let zpl = label.render()
        #expect(zpl.contains("^FDTitle"))
        #expect(zpl.contains("^FB"))
        #expect(zpl.contains("^GB"))  // Box and lines
        #expect(zpl.contains("^GC"))  // Circle
        #expect(zpl.contains("^GE"))  // Ellipse
        #expect(zpl.contains("^GD"))  // Diagonal
        #expect(zpl.contains("^BC"))  // Code128
        #expect(zpl.contains("^B3"))  // Code39
        #expect(zpl.contains("^BQ"))  // QR
        #expect(zpl.contains("^BX"))  // DataMatrix
        #expect(zpl.contains("^FX"))  // Comment
    }

    @Test("Large number of elements all render with correct field separator count")
    func largeNumberOfElements() {
        let label = ZPLLabel(width: 10, height: 10, dpi: .dpi203) {
            for i in 0..<50 {
                Text("Item \(i)", at: .dots(50, 20 + i * 40))
            }
        }
        let zpl = label.render()
        #expect(zpl.contains("^FDItem 0"))
        #expect(zpl.contains("^FDItem 49"))
        let fsCount = zpl.components(separatedBy: "^FS").count - 1
        #expect(fsCount == 50)
    }

    @Test("Nested box layout with distinct thicknesses")
    func nestedBoxLayout() {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Box(at: .dots(20, 20), width: .dots(760), height: .dots(760))
                .thickness(.dots(4))
            Box(at: .dots(40, 40), width: .dots(720), height: .dots(720))
                .thickness(.dots(2))
            Box(at: .dots(60, 60), width: .dots(680), height: .dots(680))
                .thickness(.dots(1))
            Text("CENTERED", at: .dots(300, 380))
        }
        let zpl = label.render()
        #expect(zpl.contains("^GB760,760,4"))
        #expect(zpl.contains("^GB720,720,2"))
        #expect(zpl.contains("^GB680,680,1"))
    }
}

// MARK: - Printer Commands

@Suite("Printer Commands")
struct PrinterCommandTests {

    @Test("printNetworkConfig zpl and rawValue are ~WL")
    func printerCommandPrintNetworkConfig() {
        #expect(PrinterCommand.printNetworkConfig.zpl == "~WL")
        #expect(PrinterCommand.printNetworkConfig.rawValue == "~WL")
    }

    // Remaining commands: zpl matches expected control code.
    @Test(arguments: [
        (PrinterCommand.calibrate, "~JC"),
        (PrinterCommand.reset, "~JR"),
        (PrinterCommand.cancelJob, "~JA")
    ])
    func printerCommandZPL(command: PrinterCommand, expected: String) {
        #expect(command.zpl == expected)
    }
}

// MARK: - Graphics (CoreGraphics only)

#if canImport(CoreGraphics)
@Suite("Graphics")
struct GraphicTests {

    /// Helper: creates a grayscale gradient CGImage (left=black, right=white).
    private func makeGradientImage(width: Int, height: Int) -> CGImage {
        var pixelData = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                pixelData[y * width + x] = UInt8(x * 255 / max(width - 1, 1))
            }
        }
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
        return context.makeImage()!
    }

    @Test("Graphic basic checkerboard renders ^GFA and position")
    func graphicBasic() {
        let width = 8
        let height = 8
        var pixelData = [UInt8](repeating: 0, count: width * height)
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
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        )!
        let cgImage = context.makeImage()!

        let label = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(cgImage, at: .dots(10, 10), width: .dots(8))
        }
        let zpl = label.render()
        #expect(zpl.contains("^GFA,"))     // ASCII format
        #expect(zpl.contains("^FO10,10"))  // Position
    }

    @Test("Graphic invert produces different hex data")
    func graphicWithInvert() {
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
        #expect(labelNormal.render() != labelInverted.render())
    }

    @Test("Dither .none matches default (threshold)")
    func graphicDitherNoneMatchesDefault() {
        let gradient = makeGradientImage(width: 32, height: 32)
        let labelDefault = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(gradient, at: .dots(0, 0), width: .dots(32))
        }
        let labelNone = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(gradient, at: .dots(0, 0), width: .dots(32))
                .dither(.none)
        }
        #expect(labelDefault.render() == labelNone.render())
    }

    // Each non-default dither mode must differ from the default threshold rendering.
    @Test(arguments: [DitherMethod.floydSteinberg, .atkinson, .threshold(64)])
    func graphicDitherDiffersFromThreshold(mode: DitherMethod) {
        let gradient = makeGradientImage(width: 32, height: 32)
        let labelThreshold = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(gradient, at: .dots(0, 0), width: .dots(32))
        }
        let labelDithered = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(gradient, at: .dots(0, 0), width: .dots(32))
                .dither(mode)
        }
        #expect(labelThreshold.render() != labelDithered.render())
    }

    @Test("Aspect fill crops differently from stretch")
    func graphicAspectFillCrop() {
        let width = 32
        let height = 8
        var pixelData = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width {
                let isEdge = x < 8 || x >= 24
                pixelData[y * width + x] = isEdge ? 0 : 255
            }
        }
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
        let wideImage = context.makeImage()!

        let labelStretch = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(wideImage, at: .dots(0, 0), width: .dots(8), height: .dots(8))
        }
        let labelFill = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(wideImage, at: .dots(0, 0), width: .dots(8), height: .dots(8))
                .contentMode(.aspectFill)
        }
        #expect(labelStretch.render() != labelFill.render())
    }

    @Test("Content mode .stretch is the default")
    func graphicContentModeStretchIsDefault() {
        let gradient = makeGradientImage(width: 32, height: 16)
        let labelDefault = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(gradient, at: .dots(0, 0), width: .dots(16), height: .dots(16))
        }
        let labelStretch = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
            Graphic(gradient, at: .dots(0, 0), width: .dots(16), height: .dots(16))
                .contentMode(.stretch)
        }
        #expect(labelDefault.render() == labelStretch.render())
    }
}
#endif

// MARK: - Template substitution: Code 128 invocation-code escaping

@Suite("Template substitution escaping")
struct TemplateSubstitutionEscapingTests {

    @Test("A substituted value with '>' is invocation-escaped inside a Code 128 field")
    func substitutedGreaterThanEscapedInBarcode() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("{{sku}}", at: .inches(0.25, 0.25))
        }
        let zpl = label.render(substituting: ["sku": "PRICE>5"])
        // Raw ">" would be read as a subset/function switch and the symbol would
        // scan as "PRICE"; ">0" is the literal.
        #expect(zpl.contains("PRICE>05"), "expected invocation-escaped '>0', got: \(zpl)")
    }

    @Test("A substituted value with '>' is left alone in a plain text field")
    func substitutedGreaterThanUntouchedInText() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("{{note}}", at: .inches(0.25, 0.25))
        }
        let zpl = label.render(substituting: ["note": "A>B"])
        // Text fields print ">" literally, so escaping it would print "A>0B".
        #expect(zpl.contains("A>B"))
        #expect(!zpl.contains("A>0B"))
    }

    @Test("Field state resets at ^FS, so text after a barcode is not escaped")
    func code128StateResetsAtFieldSeparator() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("{{code}}", at: .inches(0.25, 0.25))
            Text("{{note}}", at: .inches(0.25, 1.0))
        }
        let zpl = label.render(substituting: ["code": "A>B", "note": "C>D"])
        #expect(zpl.contains("A>0B"), "barcode value should be escaped")
        #expect(zpl.contains("C>D"), "text value should not be")
        #expect(!zpl.contains("C>0D"))
    }
}
