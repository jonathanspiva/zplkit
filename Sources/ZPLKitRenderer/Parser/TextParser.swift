import Foundation

/// Internal parsers for text and font commands (^A, ^CF, ^FD)
enum TextParser {

    static func parseFontCommand(_ params: String, rotation: inout String, height: inout Int, width: inout Int) {
        // Format: ^A0N,height,width or ^A0R,height,width etc.
        var remaining = params

        // First char might be rotation
        if let first = remaining.first, "NRIB".contains(first) {
            rotation = String(first)
            remaining = String(remaining.dropFirst())
        }

        // Remove leading comma if present
        if remaining.hasPrefix(",") {
            remaining = String(remaining.dropFirst())
        }

        let parts = remaining.split(separator: ",")
        if parts.count >= 1, let h = Int(parts[0]) {
            height = h
        }
        if parts.count >= 2, let w = Int(parts[1]) {
            width = w
        } else {
            width = height
        }
    }

    static func decodeFieldData(_ data: String) -> String {
        // Handle hex encoding (_XX)
        var result = data
        // Remove trailing ^FS if present
        if result.hasSuffix("^FS") {
            result = String(result.dropLast(3))
        }

        // Decode hex escapes
        let hexPattern = #"_([0-9A-Fa-f]{2})"#
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            var decoded = result
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                if let hexRange = Range(match.range(at: 1), in: result),
                   let byte = UInt8(result[hexRange], radix: 16) {
                    let char = Character(UnicodeScalar(byte))
                    if let fullRange = Range(match.range, in: decoded) {
                        decoded.replaceSubrange(fullRange, with: String(char))
                    }
                }
            }
            result = decoded
        }

        return result
    }
}
