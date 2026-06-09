import Foundation
import Testing
@testable import ZPLKitRenderer

// MARK: - Pure barcode-encoding logic tests
//
// These tests pin the *current* behaviour of the renderer's pure 1D-barcode
// encoders (EANPatterns, Code39Patterns, Interleaved2of5Patterns). Expected bit
// patterns are derived directly from the L/G/R code tables in
// Sources/ZPLKitRenderer/Barcodes/EANPatterns.swift (and the corresponding tables
// for Code 39 / I2of5) rather than from memory, so the assertions track the source.
//
// Conventions used below (copied from the source so the tests are self-contained):
//   EAN/UPC: quiet zone = 9 false modules; start/end guard = [1,0,1] (3);
//            center guard = [0,1,0,1,0] (5); each digit = 7 modules;
//            UPC-E end guard = [0,1,0,1,0,1] (6).
//   Code 39: each char = 5 bars + 4 spaces; narrow = 1 module, wide = 3 modules;
//            inter-character gap = 1 space module; framed by `*` start/stop.
//   I2of5:   start guard = [bar,space,bar,space]; stop guard = bar,bar,bar,space,bar.

// Local mirrors of the private code tables in EANPatterns, used to compute
// expected full encodings. These are transcribed verbatim from the source file;
// if the source tables change, these tests should be updated to match.
private enum EANTables {
    static let l: [Character: [Bool]] = [
        "0": [false, false, false, true, true, false, true],
        "1": [false, false, true, true, false, false, true],
        "2": [false, false, true, false, false, true, true],
        "3": [false, true, true, true, true, false, true],
        "4": [false, true, false, false, false, true, true],
        "5": [false, true, true, false, false, false, true],
        "6": [false, true, false, true, true, true, true],
        "7": [false, true, true, true, false, true, true],
        "8": [false, true, true, false, true, true, true],
        "9": [false, false, false, true, false, true, true]
    ]
    static let g: [Character: [Bool]] = [
        "0": [false, true, false, false, true, true, true],
        "1": [false, true, true, false, false, true, true],
        "2": [false, false, true, true, false, true, true],
        "3": [false, true, false, false, false, false, true],
        "4": [false, false, true, true, true, false, true],
        "5": [false, true, true, true, false, false, true],
        "6": [false, false, false, false, true, false, true],
        "7": [false, false, true, false, false, false, true],
        "8": [false, false, false, true, false, false, true],
        "9": [false, false, true, false, true, true, true]
    ]
    static let r: [Character: [Bool]] = [
        "0": [true, true, true, false, false, true, false],
        "1": [true, true, false, false, true, true, false],
        "2": [true, true, false, true, true, false, false],
        "3": [true, false, false, false, false, true, false],
        "4": [true, false, true, true, true, false, false],
        "5": [true, false, false, true, true, true, false],
        "6": [true, false, true, false, false, false, false],
        "7": [true, false, false, false, true, false, false],
        "8": [true, false, false, true, false, false, false],
        "9": [true, true, true, false, true, false, false]
    ]
    static let firstDigit: [Character: String] = [
        "0": "LLLLLL", "1": "LLGLGG", "2": "LLGGLG", "3": "LLGGGL", "4": "LGLLGG",
        "5": "LGGLLG", "6": "LGGGLL", "7": "LGLGLG", "8": "LGLGGL", "9": "LGGLGL"
    ]
    static let upceParity: [Character: String] = [
        "0": "EEEOOO", "1": "EEOEOO", "2": "EEOOEO", "3": "EEOOOE", "4": "EOEEOO",
        "5": "EOOEEO", "6": "EOOOEE", "7": "EOEOEO", "8": "EOEOOE", "9": "EOOEOE"
    ]
    static let quiet: [Bool] = Array(repeating: false, count: 9)
    static let guardSE: [Bool] = [true, false, true]
    static let center: [Bool] = [false, true, false, true, false]
    static let upceEnd: [Bool] = [false, true, false, true, false, true]
}

// MARK: - EAN-13

@Suite("EANPatterns: EAN-13")
struct EAN13Tests {

    /// Full known-good encoding of "5901234123457" (a canonical EAN-13).
    /// Expected built from EANTables so it pins the source's exact output.
    @Test("EAN-13 full encoding matches table-derived pattern")
    func ean13FullEncoding() {
        let digits = "5901234123457"
        var expected: [Bool] = []
        expected += EANTables.quiet
        expected += EANTables.guardSE
        let first = digits.first!
        let pattern = EANTables.firstDigit[first]!
        let left = Array(digits.dropFirst().prefix(6))
        for (i, d) in left.enumerated() {
            let useG = Array(pattern)[i] == "G"
            expected += (useG ? EANTables.g : EANTables.l)[d]!
        }
        expected += EANTables.center
        for d in digits.dropFirst(7).prefix(6) {
            expected += EANTables.r[d]!
        }
        expected += EANTables.guardSE
        expected += EANTables.quiet

        let actual = EANPatterns.encodeEAN13(digits)
        #expect(actual == expected)
    }

    /// Structural invariants: 9+3 + 6*7 + 5 + 6*7 + 3+9 = 113 modules.
    @Test("EAN-13 has 113 total modules and correct guards")
    func ean13Structure() {
        let result = EANPatterns.encodeEAN13("5901234123457")
        #expect(result.count == 9 + 3 + 42 + 5 + 42 + 3 + 9)
        // Left quiet zone
        #expect(Array(result.prefix(9)) == EANTables.quiet)
        // Start guard follows quiet zone
        #expect(Array(result[9..<12]) == EANTables.guardSE)
        // Center guard at offset 9+3+42 = 54
        #expect(Array(result[54..<59]) == EANTables.center)
        // End guard before trailing quiet zone
        #expect(Array(result[(result.count - 12)..<(result.count - 9)]) == EANTables.guardSE)
        // Trailing quiet zone
        #expect(Array(result.suffix(9)) == EANTables.quiet)
    }

    /// A 12-digit input must auto-append the check digit, producing the same
    /// 113-module output as the equivalent 13-digit input.
    @Test("EAN-13 12-digit input auto-appends check digit")
    func ean13AutoCheckDigit() {
        let twelve = EANPatterns.encodeEAN13("590123412345")
        let thirteen = EANPatterns.encodeEAN13("5901234123457")
        #expect(twelve == thirteen)
        #expect(twelve.count == 113)
    }

    @Test(arguments: [
        ("400638133393", Character("1")),   // EAN-13 check digit (from task brief)
        ("590123412345", Character("7")),   // -> 5901234123457
        ("000000000000", Character("0"))
    ])
    func ean13CheckDigitMath(_ payload: String, _ expected: Character) {
        #expect(EANPatterns.calculateEAN13CheckDigit(payload) == expected)
    }

    @Test(arguments: ["", "123", "12345678901", "abcdefghijkl", "5O9I23"])
    func ean13RejectsInvalidLengths(_ input: String) {
        // Fewer than 12 numeric digits -> empty result, no trap.
        #expect(EANPatterns.encodeEAN13(input).isEmpty)
    }
}

// MARK: - EAN-8

@Suite("EANPatterns: EAN-8")
struct EAN8Tests {

    /// Full encoding of "96385074" (canonical EAN-8, last digit is the check digit).
    @Test("EAN-8 full encoding matches table-derived pattern")
    func ean8FullEncoding() {
        let digits = "96385074"
        var expected: [Bool] = []
        expected += EANTables.quiet
        expected += EANTables.guardSE
        for d in digits.prefix(4) { expected += EANTables.l[d]! }
        expected += EANTables.center
        for d in digits.dropFirst(4).prefix(4) { expected += EANTables.r[d]! }
        expected += EANTables.guardSE
        expected += EANTables.quiet

        #expect(EANPatterns.encodeEAN8(digits) == expected)
    }

    /// 9+3 + 4*7 + 5 + 4*7 + 3+9 = 85 modules.
    @Test("EAN-8 has 85 total modules and correct guards")
    func ean8Structure() {
        let result = EANPatterns.encodeEAN8("96385074")
        #expect(result.count == 9 + 3 + 28 + 5 + 28 + 3 + 9)
        #expect(Array(result[9..<12]) == EANTables.guardSE)
        // Center guard at 9+3+28 = 40
        #expect(Array(result[40..<45]) == EANTables.center)
    }

    @Test("EAN-8 7-digit input auto-appends check digit")
    func ean8AutoCheckDigit() {
        let seven = EANPatterns.encodeEAN8("9638507")
        let eight = EANPatterns.encodeEAN8("96385074")
        #expect(seven == eight)
        #expect(seven.count == 85)
    }

    @Test(arguments: [
        ("9638507", Character("4")),
        ("0000000", Character("0"))
    ])
    func ean8CheckDigitMath(_ payload: String, _ expected: Character) {
        #expect(EANPatterns.calculateEAN8CheckDigit(payload) == expected)
    }

    @Test(arguments: ["", "12", "123456", "abcdef"])
    func ean8RejectsInvalidLengths(_ input: String) {
        #expect(EANPatterns.encodeEAN8(input).isEmpty)
    }
}

// MARK: - UPC-A

@Suite("EANPatterns: UPC-A")
struct UPCATests {

    /// Full encoding of "012345678905" (canonical UPC-A). UPC-A uses all L codes
    /// on the left (no parity selection) and all R codes on the right.
    @Test("UPC-A full encoding matches table-derived pattern")
    func upcaFullEncoding() {
        let digits = "012345678905"
        var expected: [Bool] = []
        expected += EANTables.quiet
        expected += EANTables.guardSE
        for d in digits.prefix(6) { expected += EANTables.l[d]! }
        expected += EANTables.center
        for d in digits.dropFirst(6).prefix(6) { expected += EANTables.r[d]! }
        expected += EANTables.guardSE
        expected += EANTables.quiet

        #expect(EANPatterns.encodeUPCA(digits) == expected)
    }

    /// 9+3 + 6*7 + 5 + 6*7 + 3+9 = 113 modules (same length as EAN-13).
    @Test("UPC-A has 113 total modules")
    func upcaStructure() {
        let result = EANPatterns.encodeUPCA("012345678905")
        #expect(result.count == 113)
        #expect(Array(result[54..<59]) == EANTables.center)
    }

    @Test("UPC-A 11-digit input auto-appends check digit")
    func upcaAutoCheckDigit() {
        let eleven = EANPatterns.encodeUPCA("01234567890")
        let twelve = EANPatterns.encodeUPCA("012345678905")
        #expect(eleven == twelve)
    }

    @Test(arguments: [
        ("03600029145", Character("2")),   // from task brief
        ("01234567890", Character("5")),   // -> 012345678905
        ("00000000000", Character("0"))
    ])
    func upcaCheckDigitMath(_ payload: String, _ expected: Character) {
        #expect(EANPatterns.calculateUPCACheckDigit(payload) == expected)
    }

    @Test(arguments: ["", "123", "1234567890", "abcdefghijk"])
    func upcaRejectsInvalidLengths(_ input: String) {
        #expect(EANPatterns.encodeUPCA(input).isEmpty)
    }
}

// MARK: - UPC-E

@Suite("EANPatterns: UPC-E")
struct UPCETests {

    /// Recompute the expected UPC-E encoding for a 6-digit input by mirroring the
    /// source: expand to UPC-A, compute check digit, look up parity, then encode
    /// each digit with L (for "O") or G (for "E").
    private func expectedUPCE(sixDigits: String, checkDigit: Character) -> [Bool] {
        let parity = EANTables.upceParity[checkDigit]!
        var expected: [Bool] = []
        expected += EANTables.quiet
        expected += EANTables.guardSE
        for (i, d) in sixDigits.enumerated() {
            let isOdd = Array(parity)[i] == "O"
            expected += (isOdd ? EANTables.l : EANTables.g)[d]!
        }
        expected += EANTables.upceEnd
        expected += EANTables.quiet
        return expected
    }

    /// Full encoding of "123456". The check digit drives parity selection, so we
    /// recompute it the same way the source does and assert the exact bit array.
    @Test("UPC-E full encoding matches parity-driven table pattern")
    func upceFullEncoding() {
        let six = "123456"
        // The source expands 123456 (last digit 6 -> default branch) to UPC-A,
        // then takes its check digit. Mirror that here.
        let upcA = "0123450000" + "6"   // 0 + X1..X5 + 0000 + X6 (default branch)
        let check = EANPatterns.calculateUPCACheckDigit(upcA)
        let expected = expectedUPCE(sixDigits: six, checkDigit: check)
        #expect(EANPatterns.encodeUPCE(six) == expected)
    }

    /// Structural invariant: 9 + 3 + 6*7 + 6 + 9 = 69 modules.
    @Test("UPC-E has 69 total modules with correct guards")
    func upceStructure() {
        let result = EANPatterns.encodeUPCE("123456")
        #expect(result.count == 9 + 3 + 42 + 6 + 9)
        #expect(Array(result[9..<12]) == EANTables.guardSE)
        // End guard (6 modules) before trailing quiet zone
        #expect(Array(result[(result.count - 15)..<(result.count - 9)]) == EANTables.upceEnd)
        #expect(Array(result.suffix(9)) == EANTables.quiet)
    }

    /// 7-digit input: first digit is the number system and is dropped, so the
    /// trailing 6 digits encode identically to the 6-digit form.
    @Test("UPC-E 7-digit input drops number-system digit")
    func upce7DigitDropsNumberSystem() {
        #expect(EANPatterns.encodeUPCE("0123456") == EANPatterns.encodeUPCE("123456"))
    }

    /// 8-digit input: first is number system, last is check digit; middle 6 encode.
    @Test("UPC-E 8-digit input drops number-system and check digit")
    func upce8DigitDropsEnds() {
        #expect(EANPatterns.encodeUPCE("01234565") == EANPatterns.encodeUPCE("123456"))
    }

    /// Different 6-digit inputs whose check digits differ must select different
    /// parity patterns and therefore produce different encodings.
    @Test("UPC-E parity selection varies the encoding by check digit")
    func upceParityVaries() {
        let a = EANPatterns.encodeUPCE("123450")  // last digit 0 -> different expansion branch
        let b = EANPatterns.encodeUPCE("123456")
        #expect(a != b)
        #expect(!a.isEmpty)
        #expect(!b.isEmpty)
    }

    /// The just-fixed crash cases: 9 and 10 input digits must return [] (not trap).
    @Test(arguments: ["123456789", "1234567890"])
    func upceRejects9And10Digits(_ input: String) {
        #expect(EANPatterns.encodeUPCE(input).isEmpty)
    }

    @Test(arguments: ["", "1", "12345"])
    func upceRejectsTooShort(_ input: String) {
        #expect(EANPatterns.encodeUPCE(input).isEmpty)
    }

    /// Valid 6/7/8-digit inputs still encode (non-empty), guarding the fix.
    @Test(arguments: ["123456", "0123456", "01234565"])
    func upceValidStillEncodes(_ input: String) {
        #expect(!EANPatterns.encodeUPCE(input).isEmpty)
    }

    /// expandUPCEtoUPCA is private; exercise its branches indirectly by checking
    /// that each last-digit family (0-2, 3, 4, 5-9) produces a valid 69-module
    /// encoding. This confirms the expansion + check-digit path runs for each branch.
    @Test(arguments: ["100002", "120003", "123404", "123459"])
    func upceExpansionBranchesEncode(_ input: String) {
        let result = EANPatterns.encodeUPCE(input)
        #expect(result.count == 69)
    }
}

// MARK: - Code 39

@Suite("Code39Patterns")
struct Code39Tests {

    // Mirror of the private patterns table (subset needed for assertions),
    // plus the helper to expand a width string to modules. Each char is framed
    // by the encoder with an inter-character gap (single space) but NOT after the
    // stop char.
    private static let widthPatterns: [Character: String] = [
        "*": "NWNNWNWNN",
        "A": "WNNNNWNNW",
        "1": "WNNWNNNNW",
        "2": "NNWWNNNNW",
        "3": "WNWWNNNNN"
    ]

    private func modules(_ widths: String) -> [Bool] {
        var out: [Bool] = []
        var isBar = true
        for w in widths {
            let count = w == "W" ? 3 : 1
            out += Array(repeating: isBar, count: count)
            isBar.toggle()
        }
        return out
    }

    /// Full encoding of "A" -> *A* with inter-character gaps after start and after A.
    @Test("Code 39 'A' encodes as star-A-star with gaps")
    func code39SingleChar() {
        var expected: [Bool] = []
        expected += modules(Self.widthPatterns["*"]!)
        expected.append(false)  // gap after start
        expected += modules(Self.widthPatterns["A"]!)
        expected.append(false)  // gap after data char
        expected += modules(Self.widthPatterns["*"]!)  // stop, no trailing gap

        #expect(Code39Patterns.encode("A") == expected)
    }

    /// Start/stop framing: output must begin and end with the `*` module pattern.
    @Test("Code 39 frames output with start/stop star pattern")
    func code39Framing() {
        let star = modules(Self.widthPatterns["*"]!)  // 13 modules (3 wide -> 9+ ...)
        let result = Code39Patterns.encode("123")
        #expect(Array(result.prefix(star.count)) == star)
        #expect(Array(result.suffix(star.count)) == star)
    }

    /// Lowercase input is upper-cased before lookup, so "a" == "A".
    @Test("Code 39 upper-cases input before encoding")
    func code39UpperCases() {
        #expect(Code39Patterns.encode("a") == Code39Patterns.encode("A"))
    }

    /// Out-of-alphabet characters are silently dropped (per the source note), so
    /// the result equals encoding only the in-alphabet characters.
    @Test("Code 39 drops out-of-alphabet characters")
    func code39DropsUnsupported() {
        // '@' and '!' are not in the Code 39 set; "A@1!" reduces to "A1".
        #expect(Code39Patterns.encode("A@1!") == Code39Patterns.encode("A1"))
    }

    /// Empty input still produces a valid frame: just start + gap + stop.
    @Test("Code 39 empty input yields start+gap+stop only")
    func code39EmptyInput() {
        var expected: [Bool] = []
        expected += modules(Self.widthPatterns["*"]!)
        expected.append(false)
        expected += modules(Self.widthPatterns["*"]!)
        #expect(Code39Patterns.encode("") == expected)
    }

    /// A fully-unsupported input behaves like empty input (all chars dropped).
    @Test("Code 39 all-unsupported input equals empty input")
    func code39AllUnsupported() {
        #expect(Code39Patterns.encode("@#!") == Code39Patterns.encode(""))
    }
}

// MARK: - Interleaved 2 of 5

@Suite("Interleaved2of5Patterns")
struct Interleaved2of5Tests {

    private static let digitPatterns: [Character: [Bool]] = [
        "0": [false, false, true, true, false],
        "1": [true, false, false, false, true],
        "2": [false, true, false, false, true],
        "3": [true, true, false, false, false],
        "4": [false, false, true, false, true],
        "5": [true, false, true, false, false],
        "6": [false, true, true, false, false],
        "7": [false, false, false, true, true],
        "8": [true, false, false, true, false],
        "9": [false, true, false, true, false]
    ]
    private static let start: [Bool] = [true, false, true, false]
    private static let stop: [Bool] = [true, true, true, false, true]

    /// Build expected modules for a digit pair the same way the source interleaves:
    /// bar widths come from d1, space widths from d2, narrow = 1, wide = 3 modules.
    private func pairModules(_ d1: Character, _ d2: Character) -> [Bool] {
        let bars = Self.digitPatterns[d1]!
        let spaces = Self.digitPatterns[d2]!
        var out: [Bool] = []
        for j in 0..<5 {
            out.append(true)
            if bars[j] { out += [true, true] }
            out.append(false)
            if spaces[j] { out += [false, false] }
        }
        return out
    }

    /// Full encoding of "12": start + interleaved(1,2) + stop.
    @Test("I2of5 '12' encodes as start + pair + stop")
    func i2of5SinglePair() {
        var expected: [Bool] = []
        expected += Self.start
        expected += pairModules("1", "2")
        expected += Self.stop
        #expect(Interleaved2of5Patterns.encode("12") == expected)
    }

    /// Odd-length input is left-padded with a leading '0', so "1" -> pair(0,1).
    @Test("I2of5 odd-length input is left-padded with zero")
    func i2of5OddPadding() {
        var expected: [Bool] = []
        expected += Self.start
        expected += pairModules("0", "1")
        expected += Self.stop
        #expect(Interleaved2of5Patterns.encode("1") == expected)
    }

    /// Padded odd input must equal the explicit even form.
    @Test("I2of5 '123' equals '0123'")
    func i2of5OddEqualsPadded() {
        #expect(Interleaved2of5Patterns.encode("123") == Interleaved2of5Patterns.encode("0123"))
    }

    /// Start and stop guards must frame the output.
    @Test("I2of5 frames output with start/stop guards")
    func i2of5Framing() {
        let result = Interleaved2of5Patterns.encode("1234")
        #expect(Array(result.prefix(4)) == Self.start)
        #expect(Array(result.suffix(5)) == Self.stop)
    }

    /// Empty / non-numeric input returns [] (no digits to encode).
    @Test(arguments: ["", "abc", "!!!"])
    func i2of5EmptyForNoDigits(_ input: String) {
        #expect(Interleaved2of5Patterns.encode(input).isEmpty)
    }

    /// Non-digit characters are filtered out before pairing.
    @Test("I2of5 filters non-digits before encoding")
    func i2of5FiltersNonDigits() {
        #expect(Interleaved2of5Patterns.encode("1a2b") == Interleaved2of5Patterns.encode("12"))
    }
}
