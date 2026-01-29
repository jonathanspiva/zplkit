import Foundation

/// Code 39 barcode pattern encoder
enum Code39Patterns {
    // Code 39 character to bar pattern mapping
    // Each character is represented as: narrow bar, narrow space, narrow bar, etc.
    // Pattern: BSBSBSBSB (5 bars, 4 spaces) where B=bar, S=space
    // N=narrow, W=wide
    private static let patterns: [Character: String] = [
        "0": "NNNWWNWNN",
        "1": "WNNWNNNNW",
        "2": "NNWWNNNNW",
        "3": "WNWWNNNNN",
        "4": "NNNWWNNNW",
        "5": "WNNWWNNNN",
        "6": "NNWWWNNNN",
        "7": "NNNWNNWNW",
        "8": "WNNWNNWNN",
        "9": "NNWWNNWNN",
        "A": "WNNNNWNNW",
        "B": "NNWNNWNNW",
        "C": "WNWNNWNNN",
        "D": "NNNNWWNNW",
        "E": "WNNNWWNNN",
        "F": "NNWNWWNNN",
        "G": "NNNNNWWNW",
        "H": "WNNNNWWNN",
        "I": "NNWNNWWNN",
        "J": "NNNNWWWNN",
        "K": "WNNNNNNWW",
        "L": "NNWNNNNWW",
        "M": "WNWNNNNWN",
        "N": "NNNNWNNWW",
        "O": "WNNNWNNWN",
        "P": "NNWNWNNWN",
        "Q": "NNNNNNWWW",
        "R": "WNNNNNWWN",
        "S": "NNWNNNWWN",
        "T": "NNNNWNWWN",
        "U": "WWNNNNNNW",
        "V": "NWWNNNNNW",
        "W": "WWWNNNNNN",
        "X": "NWNNWNNNW",
        "Y": "WWNNWNNNN",
        "Z": "NWWNWNNNN",
        "-": "NWNNNNWNW",
        ".": "WWNNNNWNN",
        " ": "NWWNNNWNN",
        "$": "NWNWNWNNN",
        "/": "NWNWNNNWN",
        "+": "NWNNNWNWN",
        "%": "NNNWNWNWN",
        "*": "NWNNWNWNN"  // Start/stop character
    ]

    /// Encodes a string into Code 39 bar patterns
    /// Returns array of bools where true = bar, false = space
    static func encode(_ data: String) -> [Bool] {
        var result: [Bool] = []
        let uppercased = data.uppercased()

        // Start character
        result.append(contentsOf: encodeCharacter("*"))
        result.append(false)  // Inter-character gap

        // Data characters
        for char in uppercased {
            if patterns[char] != nil {
                result.append(contentsOf: encodeCharacter(char))
                result.append(false)  // Inter-character gap
            }
        }

        // Stop character
        result.append(contentsOf: encodeCharacter("*"))

        return result
    }

    private static func encodeCharacter(_ char: Character) -> [Bool] {
        guard let pattern = patterns[char] else { return [] }

        var result: [Bool] = []
        var isBar = true

        for width in pattern {
            let count = width == "W" ? 3 : 1  // Wide = 3 units, Narrow = 1 unit
            for _ in 0..<count {
                result.append(isBar)
            }
            isBar.toggle()
        }

        return result
    }
}
