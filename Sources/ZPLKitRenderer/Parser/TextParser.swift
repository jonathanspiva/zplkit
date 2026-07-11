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

        let parts = ZPLParser.splitParams(remaining)
        if parts.count >= 1, let h = Int(parts[0]) {
            height = h
        }
        if parts.count >= 2, let w = Int(parts[1]) {
            width = w
        } else {
            width = height
        }
    }

    /// Decodes `^FD` field data.
    ///
    /// When `hexIndicator` is non-nil the field was preceded by `^FH` and
    /// `<indicator>XX` sequences encode raw bytes. Escaped bytes and literal
    /// characters are assembled into one byte buffer and decoded as UTF-8, so
    /// multi-byte escapes like `_C3_A9` ("é") reassemble correctly. Without
    /// `^FH`, underscores are ordinary field data and pass through untouched.
    static func decodeFieldData(_ data: String, hexIndicator: Character? = nil) -> String {
        guard let indicator = hexIndicator else { return data }

        let chars = Array(data)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(data.utf8.count)

        var i = 0
        while i < chars.count {
            if chars[i] == indicator, i + 2 < chars.count,
               let byte = UInt8(String(chars[(i + 1)...(i + 2)]), radix: 16) {
                bytes.append(byte)
                i += 3
            } else {
                bytes.append(contentsOf: String(chars[i]).utf8)
                i += 1
            }
        }

        return String(decoding: bytes, as: UTF8.self)
    }
}
