import Foundation

/// Interleaved 2 of 5 barcode pattern encoder
enum Interleaved2of5Patterns {
    // Digit width patterns. Each Bool encodes an element WIDTH: true = wide, false =
    // narrow (N = narrow, W = wide in the comments). These five widths are applied
    // alternately to bars (from the first digit of a pair) and spaces (from the
    // second) by `encode`; the booleans here do NOT encode bar-vs-space.
    private static let digitPatterns: [Character: [Bool]] = [
        "0": [false, false, true, true, false],  // NNWWN
        "1": [true, false, false, false, true],  // WNNNW
        "2": [false, true, false, false, true],  // NWNNW
        "3": [true, true, false, false, false],  // WWNNN
        "4": [false, false, true, false, true],  // NNWNW
        "5": [true, false, true, false, false],  // WNWNN
        "6": [false, true, true, false, false],  // NWWNN
        "7": [false, false, false, true, true],  // NNNWW
        "8": [true, false, false, true, false],  // WNNWN
        "9": [false, true, false, true, false]   // NWNWN
    ]

    // Start/stop guards. Unlike `digitPatterns`, these Bools are appended straight
    // into the output where true = BAR (black) and false = SPACE (white); all guard
    // elements are a single (narrow) module wide.
    // Start guard: bar, space, bar, space.
    private static let startPattern: [Bool] = [true, false, true, false]

    // Stop guard: bar, bar, bar, space, bar (the leading wide bar is encoded here as
    // two adjacent bar modules followed by the usual narrow bar/space/bar).
    private static let stopPattern: [Bool] = [true, true, true, false, true]

    /// Encodes a numeric string into Interleaved 2 of 5 bar patterns
    static func encode(_ data: String) -> [Bool] {
        var digits = data.filter { $0.isNumber }

        // I2of5 requires even number of digits
        if digits.count % 2 != 0 {
            digits = "0" + digits
        }

        guard !digits.isEmpty else { return [] }

        var result: [Bool] = []

        // Start pattern
        result.append(contentsOf: startPattern)

        // Encode digit pairs
        let chars = Array(digits)
        for i in stride(from: 0, to: chars.count, by: 2) {
            let d1 = chars[i]
            let d2 = chars[i + 1]

            guard let bars = digitPatterns[d1], let spaces = digitPatterns[d2] else {
                continue
            }

            // Interleave: bar width from d1, space width from d2
            for j in 0..<5 {
                let barWide = bars[j]
                let spaceWide = spaces[j]

                // Add bar(s)
                result.append(true)
                if barWide {
                    result.append(true)
                    result.append(true)
                }

                // Add space(s)
                result.append(false)
                if spaceWide {
                    result.append(false)
                    result.append(false)
                }
            }
        }

        // Stop pattern
        result.append(contentsOf: stopPattern)

        return result
    }
}
