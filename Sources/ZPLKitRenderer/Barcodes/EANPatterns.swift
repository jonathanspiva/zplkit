import Foundation

/// EAN/UPC barcode pattern encoder
enum EANPatterns {
    // L-codes (left side, odd parity)
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

    // R-codes (right side)
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

    // First digit encoding pattern for EAN-13 (which L/G codes to use)
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

    // Start/end guards: 101
    private static let startEnd: [Bool] = [true, false, true]

    // Center guard: 01010
    private static let center: [Bool] = [false, true, false, true, false]

    /// Encodes EAN-13 barcode
    static func encodeEAN13(_ data: String) -> [Bool] {
        let digits = data.filter { $0.isNumber }
        guard digits.count >= 12 else { return [] }

        var result: [Bool] = []

        // Start guard
        result.append(contentsOf: startEnd)

        // First digit determines encoding pattern
        let firstDigit = digits[digits.startIndex]
        let pattern = firstDigitPatterns[firstDigit] ?? "LLLLLL"

        // Left side (6 digits, using L or G codes based on first digit)
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

        // Right side (6 digits, using R codes)
        let rightDigits = digits.dropFirst(7).prefix(6)
        for digit in rightDigits {
            if let code = rCodes[digit] {
                result.append(contentsOf: code)
            }
        }

        // End guard
        result.append(contentsOf: startEnd)

        return result
    }

    /// Encodes EAN-8 barcode
    static func encodeEAN8(_ data: String) -> [Bool] {
        let digits = data.filter { $0.isNumber }
        guard digits.count >= 7 else { return [] }

        var result: [Bool] = []

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

        return result
    }

    /// Encodes UPC-A barcode (subset of EAN-13)
    static func encodeUPCA(_ data: String) -> [Bool] {
        let digits = data.filter { $0.isNumber }
        guard digits.count >= 11 else { return [] }

        var result: [Bool] = []

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

        return result
    }

    /// Encodes UPC-E barcode
    static func encodeUPCE(_ data: String) -> [Bool] {
        let digits = data.filter { $0.isNumber }
        guard digits.count >= 6 else { return [] }

        var result: [Bool] = []

        // UPC-E start guard: 101
        result.append(contentsOf: startEnd)

        // 6 digits using L/G pattern (simplified - all L for now)
        for digit in digits.prefix(6) {
            if let code = lCodes[digit] {
                result.append(contentsOf: code)
            }
        }

        // UPC-E end guard: 010101
        result.append(contentsOf: [false, true, false, true, false, true])

        return result
    }
}
