import Testing
import Foundation
@testable import ZPLKitRenderer

/// Regression tests for parser and renderer defects found in the 2026-07-10
/// code-review pass. Each test pins spec-correct behavior that was previously
/// wrong (parameter-slot shifting, `^FS` handling, `^FH` gating, etc.).
@Suite("Parser Regression Tests")
struct ParserRegressionTests {

    // MARK: - Empty parameter slots

    @Test("^BC with omitted middle params keeps later slots aligned")
    func code128EmptyParams() throws {
        // ^BCo,h,f,g,e with h omitted, f=Y: the interpretation line must be ON.
        let parsed = try ZPLParser.parse("^XA^FO10,10^BCN,,Y,N,N^FDABC^FS^XZ")
        guard case .barcode(let barcode) = parsed.elements.first else {
            Issue.record("expected a barcode element")
            return
        }
        #expect(barcode.showText == true)
        #expect(barcode.textAbove == false)
        #expect(barcode.height == 100)  // default preserved
    }

    @Test("^GB with omitted height does not shift thickness into height")
    func boxEmptyParams() throws {
        let parsed = try ZPLParser.parse("^XA^FO10,10^GB100,,2^FS^XZ")
        guard case .box(let box) = parsed.elements.first else {
            Issue.record("expected a box element")
            return
        }
        #expect(box.width == 100)
        #expect(box.height == 0)      // omitted, not "2"
        #expect(box.thickness == 2)   // stayed in its own slot
    }

    @Test("^CF with omitted height follows the supplied width")
    func cfEmptyParams() throws {
        // ^CFf,h,w with h omitted, w=20: both dimensions become 20. Verified
        // against Labelary — `^CF0,50` then `^CF0,,20` renders at 20, so the
        // omitted height follows the width rather than keeping the previous
        // value. This previously asserted 30, pinning a hardcoded fallback that
        // matched no printer behaviour.
        let parsed = try ZPLParser.parse("^XA^CF0,50^CF0,,20^FO10,10^FDX^FS^XZ")
        guard case .text(let text) = parsed.elements.first else {
            Issue.record("expected a text element")
            return
        }
        #expect(text.fontHeight == 20)
        #expect(text.fontWidth == 20)
    }

    // MARK: - ^FS field separation

    @Test("^FS ends a barcode field so it cannot capture a later ^FD")
    func fieldSeparatorClearsPendingBarcode() throws {
        let parsed = try ZPLParser.parse("^XA^BCN,100,N,N,N^FS^FO50,50^A0N,30,30^FDHello^FS^XZ")
        #expect(parsed.elements.count == 1)
        guard case .text(let text) = parsed.elements.first else {
            Issue.record("expected the ^FD to become a text element, not barcode data")
            return
        }
        #expect(text.text == "Hello")
    }

    @Test("^FR does not leak past ^FS to the next field")
    func fieldReverseScopedToField() throws {
        let parsed = try ZPLParser.parse("^XA^FO10,10^FR^GB50,50,50^FS^FO100,100^A0N,30,30^FDHello^FS^XZ")
        guard case .text(let text) = parsed.elements.last else {
            Issue.record("expected a text element")
            return
        }
        #expect(text.isReversed == false)
    }

    // MARK: - ^FH hex escapes

    @Test("_XX is field data unless ^FH enables hex escapes")
    func hexEscapesRequireFH() throws {
        let parsed = try ZPLParser.parse("^XA^FO10,10^A0N,30,30^FD2_50 off^FS^XZ")
        guard case .text(let text) = parsed.elements.first else {
            Issue.record("expected a text element")
            return
        }
        #expect(text.text == "2_50 off")
    }

    @Test("^FH multi-byte UTF-8 escapes reassemble correctly")
    func hexEscapesDecodeUTF8() throws {
        let parsed = try ZPLParser.parse("^XA^FO10,10^A0N,30,30^FH^FDcaf_C3_A9^FS^XZ")
        guard case .text(let text) = parsed.elements.first else {
            Issue.record("expected a text element")
            return
        }
        #expect(text.text == "café")
    }

    @Test("^FH is scoped to one field")
    func hexEscapeScope() throws {
        let parsed = try ZPLParser.parse("^XA^FO10,10^FH^FD_41^FS^FO10,50^FD_41^FS^XZ")
        guard parsed.elements.count == 2,
              case .text(let first) = parsed.elements[0],
              case .text(let second) = parsed.elements[1] else {
            Issue.record("expected two text elements")
            return
        }
        #expect(first.text == "A")     // decoded under ^FH
        #expect(second.text == "_41")  // literal without ^FH
    }

    // MARK: - Field data whitespace

    @Test("leading and trailing spaces in ^FD survive parsing")
    func fieldDataSpacesPreserved() throws {
        let parsed = try ZPLParser.parse("^XA^FO10,10^A0N,30,30^FD   indented  ^FS^XZ")
        guard case .text(let text) = parsed.elements.first else {
            Issue.record("expected a text element")
            return
        }
        #expect(text.text == "   indented  ")
    }

    // MARK: - Fonts

    @Test("^AB-^AZ font commands keep their size and rotation")
    func letterFontCommands() throws {
        let parsed = try ZPLParser.parse("^XA^FO10,10^ABR,60,40^FDBig^FS^XZ")
        guard case .text(let text) = parsed.elements.first else {
            Issue.record("expected a text element")
            return
        }
        #expect(text.font == "B")
        #expect(text.rotation == "R")
        #expect(text.fontHeight == 60)
        #expect(text.fontWidth == 40)
    }

    @Test("^CF font designator selects the font")
    func cfFontDesignator() throws {
        let parsed = try ZPLParser.parse("^XA^CFA,25^FO10,10^FDX^FS^XZ")
        guard case .text(let text) = parsed.elements.first else {
            Issue.record("expected a text element")
            return
        }
        #expect(text.font == "A")
        #expect(text.fontHeight == 25)
    }

    // MARK: - ^B3 parameter order

    @Test("^B3 check-digit flag comes before height per spec")
    func code39ParamOrder() throws {
        // ^B3o,e,h,f,g: e=N (no check digit), h=50, f=Y (line on).
        let parsed = try ZPLParser.parse("^XA^FO10,10^B3N,N,50,Y,N^FD123^FS^XZ")
        guard case .barcode(let barcode) = parsed.elements.first else {
            Issue.record("expected a barcode element")
            return
        }
        #expect(barcode.height == 50)
        #expect(barcode.showText == true)
    }

    // MARK: - ^BY default height

    @Test("^BY third parameter sets the default bar height")
    func byDefaultHeight() throws {
        let parsed = try ZPLParser.parse("^XA^BY3,2,200^FO10,10^BCN^FDX^FS^XZ")
        guard case .barcode(let barcode) = parsed.elements.first else {
            Issue.record("expected a barcode element")
            return
        }
        #expect(barcode.height == 200)
        #expect(barcode.moduleWidth == 3)
    }

    // MARK: - ^FT baseline

    @Test("^FT marks barcodes for bottom-left anchoring")
    func ftBarcodeBaseline() throws {
        let parsed = try ZPLParser.parse("^XA^FT10,200^BCN,100,N,N,N^FDX^FS^XZ")
        guard case .barcode(let barcode) = parsed.elements.first else {
            Issue.record("expected a barcode element")
            return
        }
        #expect(barcode.useBaseline == true)
    }

    // MARK: - Barcode field-data prefixes

    @Test("^BQ field-data header selects EC level and is stripped from payload")
    func qrFieldDataHeader() {
        let (ec, payload) = CoreGraphicsRenderer.qrFieldData("MA,HELLO")
        #expect(ec == "M")
        #expect(payload == "HELLO")

        let (ecH, payloadH) = CoreGraphicsRenderer.qrFieldData("HM,DATA,WITH,COMMAS")
        #expect(ecH == "H")
        #expect(payloadH == "DATA,WITH,COMMAS")

        // No header: everything is payload, default EC level M.
        let (ecNone, payloadNone) = CoreGraphicsRenderer.qrFieldData("PLAIN")
        #expect(ecNone == "M")
        #expect(payloadNone == "PLAIN")
    }

    @Test("Code 128 invocation codes are stripped, >0 escapes a literal >")
    func code128InvocationCodes() {
        #expect(CoreGraphicsRenderer.code128Payload(">;382436") == "382436")
        #expect(CoreGraphicsRenderer.code128Payload(">:ABC>064") == "ABC>64")
        #expect(CoreGraphicsRenderer.code128Payload("PLAIN") == "PLAIN")
    }

    // MARK: - ^GFA with Z64/B64 payloads

    @Test("^GFA with a B64 payload routes to the compressed decoder")
    func gfaWithB64Payload() throws {
        // 8 bytes of 0xFF, base64-encoded, with a valid CRC-16/XMODEM suffix.
        let bytes = [UInt8](repeating: 0xFF, count: 8)
        let b64 = Data(bytes).base64EncodedString()
        let crc = String(format: "%04X", GraphicParser.crc16XModem(Array(b64.utf8)))
        let parsed = try ZPLParser.parse("^XA^FO0,0^GFA,8,8,1,:B64:\(b64):\(crc)^FS^XZ")
        guard case .graphic(let graphic) = parsed.elements.first else {
            Issue.record("expected a graphic element")
            return
        }
        #expect(graphic.data == bytes)
    }

    @Test("Z64/B64 payload with a wrong CRC is rejected")
    func compressedPayloadBadCRC() throws {
        let b64 = Data([UInt8](repeating: 0xFF, count: 8)).base64EncodedString()
        let parsed = try ZPLParser.parse("^XA^FO0,0^GFA,8,8,1,:B64:\(b64):0000^FS^XZ")
        #expect(parsed.elements.isEmpty)
    }
}

// MARK: - Field-scoping and default-orientation regressions
//
// Every expectation below was verified against Labelary before being pinned.

@Suite("Field scoping and defaults")
struct FieldScopingRegressionTests {

    @Test("^FO with a single coordinate defaults y to 0 instead of inheriting")
    func singleCoordinateFieldOrigin() throws {
        let parsed = try ZPLParser.parse("^XA^FO50,80^FDref^FS^FO150^FDy^FS^XZ")
        guard parsed.elements.count == 2,
              case .text(let second) = parsed.elements[1] else {
            Issue.record("expected two text elements"); return
        }
        #expect(second.x == 150)
        #expect(second.y == 0, "omitted y must reset to 0, not inherit 80")
    }

    @Test("^FB does not survive ^FS into the next field")
    func textBlockDiesWithItsField() throws {
        // The ^FB field closes with no ^FD, so the following plain field must
        // render as ordinary text rather than inheriting the centered block.
        let parsed = try ZPLParser.parse("^XA^FO0,100^FB300,3,0,C^FS^FO0,100^FDplain^FS^XZ")
        guard case .text = parsed.elements.first else {
            Issue.record("expected plain text, got \(String(describing: parsed.elements.first))")
            return
        }
    }

    @Test("A font rotation does not leak into a barcode that omits its orientation")
    func fontRotationDoesNotLeakIntoBarcode() throws {
        let parsed = try ZPLParser.parse("^XA^A0R,30,30^FO10,10^FDt^FS^FO100,50^BC,80,Y,N,N^FDX^FS^XZ")
        let barcode = parsed.elements.compactMap { element -> ParsedBarcode? in
            if case .barcode(let b) = element { return b }
            return nil
        }.first
        let found = try #require(barcode)
        #expect(found.rotation == "N", "a barcode's default orientation comes from ^FW, not the last ^A")
    }

    @Test("^FW sets the default orientation for a barcode that omits its own")
    func fieldDefaultOrientationAppliesToBarcode() throws {
        let parsed = try ZPLParser.parse("^XA^FWR^FO100,50^BC,80,Y,N,N^FDX^FS^XZ")
        let barcode = parsed.elements.compactMap { element -> ParsedBarcode? in
            if case .barcode(let b) = element { return b }
            return nil
        }.first
        let found = try #require(barcode)
        #expect(found.rotation == "R")
    }

    @Test("^LH offsets every subsequent field origin")
    func labelHomeOffsetsFields() throws {
        // Verified against Labelary: with ^LH60,40 a ^FO0,0 field renders at
        // (60, 40). Previously ^LH was ignored entirely.
        let parsed = try ZPLParser.parse("^XA^LH60,40^FO0,0^GB120,60,5^FS^FO0,80^FDshifted^FS^XZ")
        guard case .box(let box) = parsed.elements.first else {
            Issue.record("expected a box"); return
        }
        #expect(box.x == 60)
        #expect(box.y == 40)
        guard case .text(let text) = parsed.elements.last else {
            Issue.record("expected text"); return
        }
        #expect(text.x == 60)
        #expect(text.y == 120)
    }

    @Test("^POI marks the label for 180-degree rendering, ^PON does not")
    func printOrientationInvert() throws {
        let inverted = try ZPLParser.parse("^XA^POI^FO20,20^FDinv^FS^XZ")
        #expect(inverted.invertedOrientation == true)
        let normal = try ZPLParser.parse("^XA^PON^FO20,20^FDnorm^FS^XZ")
        #expect(normal.invertedOrientation == false)
        let unspecified = try ZPLParser.parse("^XA^FO20,20^FDnorm^FS^XZ")
        #expect(unspecified.invertedOrientation == false)
    }

    @Test("^GFA run-length repeats may span rows")
    func graphicRepeatSpansRows() throws {
        // V = 16 repeats of nibble F: an 8x8 solid square, not a single row.
        let parsed = try ZPLParser.parse("^XA^FO0,0^GFA,8,8,1,VF^FS^XZ")
        let graphic = parsed.elements.compactMap { element -> ParsedGraphic? in
            if case .graphic(let g) = element { return g }
            return nil
        }.first
        let found = try #require(graphic)
        #expect(found.data.count == 8, "expected 8 rows of 1 byte, got \(found.data.count)")
        #expect(found.data.allSatisfy { $0 == 0xFF }, "every row should be solid black")
    }
}

@Suite("Interpretation line")
struct InterpretationLineTests {

    @Test("EAN-13 caption includes the printer-computed check digit")
    func ean13CaptionCheckDigit() throws {
        let parsed = try ZPLParser.parse("^XA^FO30,30^BEN,80,Y,N^FD123456789012^FS^XZ")
        guard case .barcode(let barcode) = parsed.elements.first else {
            Issue.record("expected a barcode"); return
        }
        // Labelary renders this caption as "1 234567 890128".
        #expect(CoreGraphicsRenderer.interpretationLine(for: barcode) == "1234567890128")
    }

    @Test("A fully-specified value is left alone")
    func alreadyCompleteCaption() throws {
        let parsed = try ZPLParser.parse("^XA^FO30,30^BEN,80,Y,N^FD1234567890128^FS^XZ")
        guard case .barcode(let barcode) = parsed.elements.first else {
            Issue.record("expected a barcode"); return
        }
        #expect(CoreGraphicsRenderer.interpretationLine(for: barcode) == "1234567890128")
    }

    @Test("Non-GTIN symbologies are unchanged")
    func nonGtinCaption() throws {
        let parsed = try ZPLParser.parse("^XA^FO30,30^BCN,80,Y,N,N^FDABC123^FS^XZ")
        guard case .barcode(let barcode) = parsed.elements.first else {
            Issue.record("expected a barcode"); return
        }
        #expect(CoreGraphicsRenderer.interpretationLine(for: barcode) == "ABC123")
    }
}
