import Foundation
import Testing
@testable import ZPLKit

// Tests for the platform-independent core: the checksum and character-validation
// helpers in `Internal/`, and the `Types/` enums that encode directly into ZPL.
//
// Everything here is deliberately free of CoreGraphics so it runs on Linux as
// well as Apple platforms. Do not add image/rendering cases to this file; those
// belong with the `Graphic` suite, which is `#if canImport(CoreGraphics)`.

// MARK: - GTIN check digit

@Suite("GTIN Check Digit")
struct GTINCheckDigitTests {

    // Real-world barcodes. The last digit of each is the published check digit,
    // so computing it from the leading digits must reproduce it exactly.
    @Test(arguments: [
        ("400638133393", 1),   // EAN-13, Faber-Castell
        ("590123412345", 7),   // EAN-13
        ("03600029145", 2),    // UPC-A, Coca-Cola
        ("04210000526", 4),    // UPC-A
        ("9638507", 4),        // EAN-8
        ("7351353", 7)         // EAN-8
    ])
    func computesPublishedCheckDigit(dataDigits: String, expected: Int) {
        let digits = dataDigits.map { $0.wholeNumberValue! }
        #expect(gtinCheckDigit(digits) == expected)
    }

    @Test("All-zero data yields a zero check digit")
    func allZeros() {
        #expect(gtinCheckDigit(Array(repeating: 0, count: 11)) == 0)
        #expect(gtinCheckDigit(Array(repeating: 0, count: 12)) == 0)
    }

    // The weighting runs 3,1,3,1,... from the RIGHTMOST data digit. The clean
    // way to pin that direction: padding on the LEFT must not change the
    // result (the added zero lands on a weight but contributes nothing and
    // shifts nothing), while appending on the RIGHT must change it (every
    // existing digit moves to the other weight). A left-to-right
    // implementation gets this backwards.
    @Test("Weighting is anchored at the right, not the left")
    func weightingDirection() {
        let base = gtinCheckDigit([1, 2, 3])
        #expect(gtinCheckDigit([0, 1, 2, 3]) == base, "a leading zero must not change the check digit")
        #expect(gtinCheckDigit([1, 2, 3, 0]) != base, "appending shifts every weight")
    }

    @Test(arguments: [
        "4006381333931",   // EAN-13
        "5901234123457",   // EAN-13
        "036000291452",    // UPC-A
        "042100005264",    // UPC-A
        "96385074",        // EAN-8
        "73513537"         // EAN-8
    ])
    func acceptsCorrectlyCheckedStrings(full: String) {
        #expect(hasValidGTINCheckDigit(full))
    }

    // Flipping the final digit must invalidate the string.
    @Test(arguments: [
        "4006381333930",
        "5901234123456",
        "036000291453",
        "96385075"
    ])
    func rejectsWrongCheckDigit(full: String) {
        #expect(!hasValidGTINCheckDigit(full))
    }

    @Test("Strings shorter than two digits have no check digit to validate")
    func rejectsTooShort() {
        #expect(!hasValidGTINCheckDigit(""))
        #expect(!hasValidGTINCheckDigit("5"))
    }

    @Test("Non-digit characters invalidate the string")
    func rejectsNonDigits() {
        #expect(!hasValidGTINCheckDigit("40063813339A"))
        #expect(!hasValidGTINCheckDigit("9638 5074"))
    }
}

// MARK: - ASCII digit validation

@Suite("ASCII Digit Validation")
struct ASCIIDigitTests {

    @Test(arguments: Array("0123456789"))
    func acceptsASCIIDigits(c: Character) {
        #expect(c.isASCIIDigit)
    }

    // `isNumber`/`isWholeNumber` accept non-ASCII numerics. Those must NOT pass,
    // because they would be emitted into ^FD as raw multibyte UTF-8 and the
    // printer would encode something other than the intended digits.
    @Test(arguments: [
        "\u{FF11}",   // FULLWIDTH DIGIT ONE
        "\u{0661}",   // ARABIC-INDIC DIGIT ONE
        "\u{0967}",   // DEVANAGARI DIGIT ONE
        "\u{2081}",   // SUBSCRIPT ONE
        "\u{00B9}",   // SUPERSCRIPT ONE
        "\u{1D7D9}"   // MATHEMATICAL DOUBLE-STRUCK DIGIT ONE
    ] as [Character])
    func rejectsNonASCIINumerics(c: Character) {
        #expect(c.isWholeNumber, "fixture should be a whole number, else the test proves nothing")
        #expect(!c.isASCIIDigit)
    }

    @Test(arguments: ["A", " ", "-", "+", ".", "\u{00BD}"] as [Character])
    func rejectsNonDigits(c: Character) {
        #expect(!c.isASCIIDigit)
    }
}

// MARK: - Non-ASCII digits must not reach the printer

@Suite("Non-ASCII Digit Rejection")
struct NonASCIIDigitRejectionTests {

    // Fullwidth digits, which carry a `wholeNumberValue` and so survive
    // `hasValidGTINCheckDigit`, but must be rejected by every numeric element.
    static let fullwidth = "\u{FF11}\u{FF12}\u{FF13}\u{FF14}\u{FF15}\u{FF16}\u{FF17}\u{FF18}\u{FF19}\u{FF10}\u{FF11}\u{FF12}"

    @Test("Every numeric barcode rejects fullwidth digits at its own valid length")
    func numericBarcodesRejectFullwidth() {
        let pos = Position.dots(0, 0)
        let f = Self.fullwidth
        #expect(EAN13(String(f.prefix(12)), at: pos) == nil)
        #expect(EAN8(String(f.prefix(7)), at: pos) == nil)
        #expect(UPCA(String(f.prefix(11)), at: pos) == nil)
        #expect(UPCE(String(f.prefix(6)), at: pos) == nil)
        #expect(Interleaved2of5(String(f.prefix(10)), at: pos) == nil)
        // IMb needs 20 digits and a second digit in 0-4.
        let imb = String(repeating: "\u{FF10}", count: 20)
        #expect(IntelligentMail(imb, at: pos) == nil)
    }

    // The ordering of the two guards inside the element initializers is
    // load-bearing. `hasValidGTINCheckDigit` uses `wholeNumberValue`, which
    // happily reads fullwidth digits, so it returns TRUE for this string. Only
    // the `isASCIIDigit` guard that runs BEFORE it keeps the value out. If the
    // guards were ever reordered, this input would be accepted and the printer
    // would receive raw multibyte UTF-8 in ^FD.
    @Test("The ASCII guard, not the checksum, is what rejects fullwidth digits")
    func asciiGuardPrecedesChecksum() {
        // Fullwidth "1234567890128", whose ASCII twin is a valid EAN-13.
        let fullwidthValid = "\u{FF11}\u{FF12}\u{FF13}\u{FF14}\u{FF15}\u{FF16}\u{FF17}\u{FF18}\u{FF19}\u{FF10}\u{FF11}\u{FF12}\u{FF18}"
        #expect(fullwidthValid.count == 13)
        // The ASCII equivalent really is valid, so the fixture is meaningful.
        #expect(hasValidGTINCheckDigit("1234567890128"))
        // The internal helper is permissive and accepts the fullwidth form...
        #expect(hasValidGTINCheckDigit(fullwidthValid))
        // ...but the element must still reject it.
        #expect(EAN13(fullwidthValid, at: .dots(0, 0)) == nil)
    }
}

// MARK: - Rotation

@Suite("Rotation Codes")
struct RotationTests {

    // These raw values are the ZPL orientation characters and are part of the
    // emitted command, so they are not free to change.
    @Test("Raw values are the ZPL orientation characters")
    func rawValues() {
        #expect(Rotation.normal.rawValue == "N")
        #expect(Rotation.rotated90.rawValue == "R")
        #expect(Rotation.inverted.rawValue == "I")
        #expect(Rotation.rotated270.rawValue == "B")
    }

    @Test(arguments: [
        (Rotation.normal, "^A0N"),
        (Rotation.rotated90, "^A0R"),
        (Rotation.inverted, "^A0I"),
        (Rotation.rotated270, "^A0B")
    ])
    func textEmitsOrientation(rotation: Rotation, expected: String) {
        let zpl = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("X", at: .dots(0, 0)).rotated(rotation)
        }.render()
        #expect(zpl.contains(expected))
    }

    @Test(arguments: [
        (Rotation.normal, "^BCN"),
        (Rotation.rotated90, "^BCR"),
        (Rotation.inverted, "^BCI"),
        (Rotation.rotated270, "^BCB")
    ])
    func barcode128EmitsOrientation(rotation: Rotation, expected: String) {
        let zpl = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("AB", at: .dots(0, 0))!.rotated(rotation)
        }.render()
        #expect(zpl.contains(expected))
    }

    @Test(arguments: [
        (Rotation.normal, "^BEN"),
        (Rotation.rotated90, "^BER"),
        (Rotation.inverted, "^BEI"),
        (Rotation.rotated270, "^BEB")
    ])
    func ean13EmitsOrientation(rotation: Rotation, expected: String) {
        let zpl = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            EAN13("590123412345", at: .dots(0, 0))!.rotated(rotation)
        }.render()
        #expect(zpl.contains(expected))
    }

    @Test("Rotation round-trips through Codable")
    func codableRoundTrip() throws {
        for rotation in [Rotation.normal, .rotated90, .inverted, .rotated270] {
            let data = try JSONEncoder().encode(rotation)
            #expect(try JSONDecoder().decode(Rotation.self, from: data) == rotation)
        }
    }
}

// MARK: - Fonts

@Suite("ZPLFont Codes")
struct ZPLFontTests {

    @Test("Default font is Font 0")
    func defaultIsZero() {
        #expect(ZPLFont.default.rawValue == "0")
    }

    // Every bitmap font's raw value must be its own uppercase letter; a
    // mismatch would silently select a different printer font.
    @Test(arguments: [
        (ZPLFont.a, "A"), (.b, "B"), (.c, "C"), (.d, "D"), (.e, "E"),
        (.f, "F"), (.g, "G"), (.h, "H"), (.p, "P"), (.q, "Q"),
        (.r, "R"), (.s, "S"), (.t, "T"), (.u, "U"), (.v, "V")
    ])
    func bitmapFontRawValues(font: ZPLFont, expected: String) {
        #expect(font.rawValue == expected)
    }

    // The font code sits between ^A and the orientation character, so the
    // emitted command is ^A<font><orientation>.
    @Test(arguments: [
        (ZPLFont.default, "^A0N"),
        (ZPLFont.a, "^AAN"),
        (ZPLFont.v, "^AVN")
    ])
    func fontEmitsIntoTextCommand(font: ZPLFont, expected: String) {
        let zpl = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("X", at: .dots(0, 0)).font(font, height: .dots(30))
        }.render()
        #expect(zpl.contains(expected))
    }

    @Test("Every font case has a distinct raw value")
    func rawValuesAreDistinct() {
        let all: [ZPLFont] = [.default, .a, .b, .c, .d, .e, .f, .g, .h, .p, .q, .r, .s, .t, .u, .v]
        #expect(Set(all.map(\.rawValue)).count == all.count)
    }
}

// MARK: - UPC-E field data

@Suite("UPC-E Field Data")
struct UPCEFieldDataTests {

    @Test(arguments: ["123456", "000000", "999999", "0123456", "1123456"])
    func acceptsValidLengths(input: String) {
        #expect(UPCE(input, at: .dots(0, 0)) != nil)
    }

    @Test(arguments: ["", "12345", "12345678", "123456789"])
    func rejectsInvalidLengths(input: String) {
        #expect(UPCE(input, at: .dots(0, 0)) == nil)
    }

    // The data is emitted verbatim into ^FD; the printer derives the check
    // digit itself.
    @Test("Field data is emitted verbatim")
    func emitsVerbatim() {
        let zpl = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            UPCE("123456", at: .dots(0, 0))!
        }.render()
        #expect(zpl.contains("^B9N"))
        #expect(zpl.contains("^FD123456^FS"))
    }

    // Documented hazard: a 7th digit is a LEADING number system digit, not a
    // trailing check digit. "0123456" is therefore number system 0 plus item
    // code 123456, which is the same symbol as the bare "123456" - whereas
    // "1234565" would be number system 1 plus item code 234565, a different
    // product entirely. This pins that the library passes the digits through
    // rather than reinterpreting them.
    @Test("A 7th digit is carried through as a leading digit, not a check digit")
    func seventhDigitIsLeading() {
        func fieldData(_ input: String) -> String {
            ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
                UPCE(input, at: .dots(0, 0))!
            }.render()
        }
        #expect(fieldData("0123456").contains("^FD0123456^FS"))
        #expect(fieldData("1234565").contains("^FD1234565^FS"))
        // The two are different symbols; nothing normalizes one into the other.
        #expect(!fieldData("1234565").contains("^FD123456^FS"))
    }
}

// MARK: - Foundation-free string replacement

@Suite("replacingAll")
struct ReplacingAllTests {

    @Test(arguments: [
        // (receiver, target, replacement, expected)
        ("PRICE>5", ">", ">0", "PRICE>05"),
        ("a>b>c", ">", ">0", "a>0b>0c"),
        ("no matches here", "^", "_5E", "no matches here"),
        ("", ">", ">0", ""),
        (">", ">", ">0", ">0"),
        (">>", ">", ">0", ">0>0"),           // adjacent matches
        ("1,234,567", ",", "", "1234567"),   // deletion
        ("xax", "a", "bb", "xbbx"),
        ("aaa", "a", "aa", "aaaaaa"),        // replacement CONTAINS target: must not rescan
        ("\r\n\r\n", "\r\n", "\n", "\n\n"),  // multi-character target
        ("abcabc", "abc", "x", "xx"),
        ("start", "start", "end", "end"),    // whole receiver
    ])
    func replaces(input: String, target: String, replacement: String, expected: String) {
        #expect(input.replacingAll(target, with: replacement) == expected)
    }

    // An empty target would otherwise interleave the replacement between every
    // character, or loop forever. Foundation returns the receiver unchanged.
    @Test("An empty target returns the receiver unchanged")
    func emptyTarget() {
        #expect("abc".replacingAll("", with: "X") == "abc")
        #expect("".replacingAll("", with: "X") == "")
    }

    // The helper replaced Foundation's `replacingOccurrences(of:with:)`. The
    // test target may still import Foundation, so assert the two agree rather
    // than trusting that they do. If they ever diverge, the ZPL escaping paths
    // that depend on this are the first thing to break.
    @Test(arguments: [
        ("PRICE>5", ">", ">0"),
        ("a>b>c>", ">", ">0"),
        ("", ">", ">0"),
        (">>>", ">", ">0"),
        ("aaa", "a", "aa"),
        ("1,234,567", ",", ""),
        ("line\r\nbreak\nhere", "\r\n", "\n"),
        ("back\\slash", "\\", "\\\\"),
        ("nothing", "zzz", "!"),
        ("^~_", "^", "_5E"),
    ])
    func matchesFoundation(input: String, target: String, replacement: String) {
        #expect(
            input.replacingAll(target, with: replacement)
                == input.replacingOccurrences(of: target, with: replacement)
        )
    }

    // Works on Substring too, since the extension is on StringProtocol and the
    // template substitution path slices as it scans.
    @Test("Works on a Substring receiver")
    func substringReceiver() {
        let full = "keep>drop"
        let tail = full.dropFirst(4)   // ">drop"
        #expect(tail == ">drop", "fixture must still contain the target")
        #expect(tail.replacingAll(">", with: ">0") == ">0drop")
    }
}
