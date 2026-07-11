import Foundation

/// EAN/UPC barcode pattern encoder
enum EANPatterns {
    // L-codes (left side, odd parity) - start with space (0)
    private static let lCodes: [Character: [Bool]] = [
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

    // G-codes (left side, even parity - reverse of R-codes)
    private static let gCodes: [Character: [Bool]] = [
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

    // R-codes (right side) - start with bar (1)
    private static let rCodes: [Character: [Bool]] = [
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

    // First digit encoding pattern for EAN-13 (which L/G codes to use for positions 2-7)
    private static let firstDigitPatterns: [Character: String] = [
        "0": "LLLLLL",
        "1": "LLGLGG",
        "2": "LLGGLG",
        "3": "LLGGGL",
        "4": "LGLLGG",
        "5": "LGGLLG",
        "6": "LGGGLL",
        "7": "LGLGLG",
        "8": "LGLGGL",
        "9": "LGGLGL"
    ]

    // UPC-E parity patterns based on check digit (for number system 0)
    private static let upceParityPatterns: [Character: String] = [
        "0": "EEEOOO",
        "1": "EEOEOO",
        "2": "EEOOEO",
        "3": "EEOOOE",
        "4": "EOEEOO",
        "5": "EOOEEO",
        "6": "EOOOEE",
        "7": "EOEOEO",
        "8": "EOEOOE",
        "9": "EOOEOE"
    ]

    // Start/end guards: 101
    private static let startEnd: [Bool] = [true, false, true]

    // Center guard: 01010
    private static let center: [Bool] = [false, true, false, true, false]

    // UPC-E end guard: 010101
    private static let upceEnd: [Bool] = [false, true, false, true, false, true]

    // Quiet zones: EAN-13 requires 11 modules on the left and 7 on the right;
    // EAN-8/UPC uses 9 on both sides (>= the 7/9-module minimums).
    private static let quietZone: [Bool] = Array(repeating: false, count: 9)
    private static let quietZoneLeft11: [Bool] = Array(repeating: false, count: 11)
    private static let quietZoneRight7: [Bool] = Array(repeating: false, count: 7)

    // MARK: - Check Digit Calculation

    /// Calculate EAN-13/UPC-A check digit using mod-10 algorithm
    static func calculateEAN13CheckDigit(_ digits: String) -> Character {
        let chars = Array(digits.filter { $0.isNumber })
        guard chars.count >= 12 else { return "0" }

        var sum = 0
        for (i, c) in chars.prefix(12).enumerated() {
            let digit = Int(String(c)) ?? 0
            sum += digit * (i % 2 == 0 ? 1 : 3)
        }
        let check = (10 - (sum % 10)) % 10
        return Character(String(check))
    }

    /// Calculate EAN-8 check digit
    static func calculateEAN8CheckDigit(_ digits: String) -> Character {
        let chars = Array(digits.filter { $0.isNumber })
        guard chars.count >= 7 else { return "0" }

        var sum = 0
        for (i, c) in chars.prefix(7).enumerated() {
            let digit = Int(String(c)) ?? 0
            sum += digit * (i % 2 == 0 ? 3 : 1)
        }
        let check = (10 - (sum % 10)) % 10
        return Character(String(check))
    }

    /// Calculate UPC-A check digit (same as EAN-13 but for 11 digits, result applied at position 12)
    static func calculateUPCACheckDigit(_ digits: String) -> Character {
        // Pad to 12 digits with leading 0 if needed, then calculate EAN-13 style
        let paddedDigits = String(repeating: "0", count: max(0, 11 - digits.count)) + digits
        return calculateEAN13CheckDigit("0" + paddedDigits)
    }

    // MARK: - Encoding Functions

    /// Encodes EAN-13 barcode with quiet zones
    static func encodeEAN13(_ data: String) -> [Bool] {
        var digits = data.filter { $0.isNumber }
        guard digits.count >= 12 else { return [] }

        // Calculate and append check digit if only 12 digits provided
        if digits.count == 12 {
            digits.append(calculateEAN13CheckDigit(String(digits)))
        }

        var result: [Bool] = []

        // Left quiet zone (11 modules per the EAN-13 spec)
        result.append(contentsOf: quietZoneLeft11)

        // Start guard
        result.append(contentsOf: startEnd)

        // First digit determines encoding pattern for left side
        let firstDigit = digits[digits.startIndex]
        let pattern = firstDigitPatterns[firstDigit] ?? "LLLLLL"

        // Left side (digits 2-7, using L or G codes based on first digit pattern)
        let leftDigits = digits.dropFirst().prefix(6)
        for (index, digit) in leftDigits.enumerated() {
            let useG = pattern[pattern.index(pattern.startIndex, offsetBy: index)] == "G"
            let codes = useG ? gCodes : lCodes
            if let code = codes[digit] {
                result.append(contentsOf: code)
            }
        }

        // Center guard
        result.append(contentsOf: center)

        // Right side (digits 8-13, using R codes)
        let rightDigits = digits.dropFirst(7).prefix(6)
        for digit in rightDigits {
            if let code = rCodes[digit] {
                result.append(contentsOf: code)
            }
        }

        // End guard
        result.append(contentsOf: startEnd)

        // Right quiet zone (7 modules per the EAN-13 spec)
        result.append(contentsOf: quietZoneRight7)

        return result
    }

    /// Encodes EAN-8 barcode with quiet zones
    static func encodeEAN8(_ data: String) -> [Bool] {
        var digits = data.filter { $0.isNumber }
        guard digits.count >= 7 else { return [] }

        // Calculate and append check digit if only 7 digits provided
        if digits.count == 7 {
            digits.append(calculateEAN8CheckDigit(String(digits)))
        }

        var result: [Bool] = []

        // Left quiet zone
        result.append(contentsOf: quietZone)

        // Start guard
        result.append(contentsOf: startEnd)

        // Left side (4 digits, all L codes)
        for digit in digits.prefix(4) {
            if let code = lCodes[digit] {
                result.append(contentsOf: code)
            }
        }

        // Center guard
        result.append(contentsOf: center)

        // Right side (4 digits, all R codes)
        for digit in digits.dropFirst(4).prefix(4) {
            if let code = rCodes[digit] {
                result.append(contentsOf: code)
            }
        }

        // End guard
        result.append(contentsOf: startEnd)

        // Right quiet zone
        result.append(contentsOf: quietZone)

        return result
    }

    /// Encodes UPC-A barcode with quiet zones
    static func encodeUPCA(_ data: String) -> [Bool] {
        var digits = data.filter { $0.isNumber }
        guard digits.count >= 11 else { return [] }

        // Calculate and append check digit if only 11 digits provided
        if digits.count == 11 {
            digits.append(calculateUPCACheckDigit(String(digits)))
        }

        var result: [Bool] = []

        // Left quiet zone (9 modules for UPC-A)
        result.append(contentsOf: quietZone)

        // Start guard
        result.append(contentsOf: startEnd)

        // Left side (6 digits, all L codes)
        for digit in digits.prefix(6) {
            if let code = lCodes[digit] {
                result.append(contentsOf: code)
            }
        }

        // Center guard
        result.append(contentsOf: center)

        // Right side (6 digits, all R codes)
        for digit in digits.dropFirst(6).prefix(6) {
            if let code = rCodes[digit] {
                result.append(contentsOf: code)
            }
        }

        // End guard
        result.append(contentsOf: startEnd)

        // Right quiet zone
        result.append(contentsOf: quietZone)

        return result
    }

    /// Encodes UPC-E barcode with proper parity patterns
    static func encodeUPCE(_ data: String) -> [Bool] {
        let inputDigits = data.filter { $0.isNumber }
        guard inputDigits.count >= 6 else { return [] }

        // Get the 6-digit code (without number system or check digit)
        let sixDigits: String
        if inputDigits.count == 6 {
            sixDigits = String(inputDigits)
        } else if inputDigits.count == 7 {
            // First digit is number system, skip it
            sixDigits = String(inputDigits.dropFirst())
        } else {
            // 8 digits: first is number system, last is check digit
            sixDigits = String(inputDigits.dropFirst().dropLast())
        }

        // For 9+ input digits the branches above yield a string with more than 6
        // characters, but `parityPattern` is always 6 chars; the enumeration loop
        // below indexes `parityPattern` by digit position and would trap on the
        // 7th character. Reject anything that did not reduce to exactly 6 digits
        // (render nothing), consistent with the empty-array return for < 6 digits.
        guard sixDigits.count == 6 else { return [] }

        // Expand UPC-E to UPC-A to calculate check digit
        let upcA = expandUPCEtoUPCA(sixDigits)
        let checkDigit = calculateUPCACheckDigit(upcA)

        // Get parity pattern based on check digit (for number system 0)
        let parityPattern = upceParityPatterns[checkDigit] ?? "EEEOOO"

        var result: [Bool] = []

        // Left quiet zone
        result.append(contentsOf: quietZone)

        // Start guard: 101
        result.append(contentsOf: startEnd)

        // 6 digits using O (odd/L) or E (even/G) codes based on parity pattern
        for (index, digit) in sixDigits.enumerated() {
            let patternChar = parityPattern[parityPattern.index(parityPattern.startIndex, offsetBy: index)]
            let codes = (patternChar == "O") ? lCodes : gCodes
            if let code = codes[digit] {
                result.append(contentsOf: code)
            }
        }

        // End guard: 010101
        result.append(contentsOf: upceEnd)

        // Right quiet zone
        result.append(contentsOf: quietZone)

        return result
    }

    /// Expand 6-digit UPC-E to 11-digit UPC-A (without check digit)
    private static func expandUPCEtoUPCA(_ upce: String) -> String {
        guard upce.count == 6 else { return upce }

        let chars = Array(upce)
        let lastDigit = chars[5]

        // UPC-E compression rules (assuming number system 0)
        switch lastDigit {
        case "0", "1", "2":
            // Manufacturer: X1X200, Product: 00X3X4X5
            return "0\(chars[0])\(chars[1])\(lastDigit)0000\(chars[2])\(chars[3])\(chars[4])"
        case "3":
            // Manufacturer: X1X2X300, Product: 000X4X5
            return "0\(chars[0])\(chars[1])\(chars[2])00000\(chars[3])\(chars[4])"
        case "4":
            // Manufacturer: X1X2X3X400, Product: 0000X5
            return "0\(chars[0])\(chars[1])\(chars[2])\(chars[3])00000\(chars[4])"
        default: // 5-9
            // Manufacturer: X1X2X3X4X5, Product: 0000X6
            return "0\(chars[0])\(chars[1])\(chars[2])\(chars[3])\(chars[4])0000\(lastDigit)"
        }
    }
}
