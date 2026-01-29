import Foundation

/// Internal parser for graphic commands (^GF)
enum GraphicParser {

    static func parseGraphic(_ params: String, x: Int, y: Int) -> ParsedGraphic? {
        // ^GF format: ^GFa,b,c,d,data
        // a = format (A=ASCII, B=Binary, C=Compressed)
        // b = binary byte count
        // c = graphic field count (total bytes)
        // d = bytes per row
        // data = the graphic data

        var remaining = params

        // Get format character
        guard let formatChar = remaining.first else { return nil }
        remaining = String(remaining.dropFirst())

        let format: ParsedGraphic.GraphicFormat
        switch formatChar {
        case "A": format = .ascii
        case "B": format = .binary
        case "C": format = .compressed
        default: format = .ascii
        }

        // Skip leading comma if present
        if remaining.hasPrefix(",") {
            remaining = String(remaining.dropFirst())
        }

        // Split the remaining parameters
        // Format: binaryByteCount,totalBytes,bytesPerRow,data
        let parts = remaining.split(separator: ",", maxSplits: 3)
        guard parts.count >= 4 else { return nil }

        guard let totalBytes = Int(parts[1]),
              let bytesPerRow = Int(parts[2]) else { return nil }

        let hexData = String(parts[3])

        // Decode ASCII hex data to bytes
        let data: [UInt8]
        switch format {
        case .ascii:
            data = decodeAsciiHex(hexData)
        case .binary, .compressed:
            // For now, only support ASCII format
            // Binary and compressed would need different handling
            data = []
        }

        guard !data.isEmpty else { return nil }

        return ParsedGraphic(
            x: x,
            y: y,
            format: format,
            bytesPerRow: bytesPerRow,
            totalBytes: totalBytes,
            data: data
        )
    }

    private static func decodeAsciiHex(_ hex: String) -> [UInt8] {
        var data: [UInt8] = []
        var chars = hex.uppercased()

        // Remove any whitespace
        chars = chars.replacingOccurrences(of: " ", with: "")
        chars = chars.replacingOccurrences(of: "\n", with: "")

        // Convert pairs of hex chars to bytes
        var index = chars.startIndex
        while index < chars.endIndex {
            let nextIndex = chars.index(index, offsetBy: 2, limitedBy: chars.endIndex) ?? chars.endIndex
            let hexPair = String(chars[index..<nextIndex])

            if let byte = UInt8(hexPair, radix: 16) {
                data.append(byte)
            }

            index = nextIndex
        }

        return data
    }
}
