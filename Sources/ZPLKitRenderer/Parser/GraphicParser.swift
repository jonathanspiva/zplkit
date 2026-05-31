import Foundation

#if canImport(Compression)
import Compression
#endif

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
        let parts = remaining.split(separator: ",", maxSplits: 3, omittingEmptySubsequences: false)
        guard parts.count >= 4 else { return nil }

        // `totalBytes` must be non-negative and `bytesPerRow` must be strictly
        // positive: the renderer divides `data.count / bytesPerRow`, so a value of
        // 0 (e.g. from a malformed `^GFA,0,0,0,FF`) would otherwise trap with an
        // integer divide-by-zero. Drop the element instead of crashing the render.
        guard let totalBytes = Int(parts[1]), totalBytes >= 0,
              let bytesPerRow = Int(parts[2]), bytesPerRow > 0 else { return nil }

        let rawData = String(parts[3])

        // Decode the data field to a flat 1-bit-per-pixel byte buffer.
        let data: [UInt8]
        switch format {
        case .ascii:
            // ^GFA carries hex-ASCII, optionally using Zebra's run-length
            // compression scheme (repeat-count letters, `,`, `!`, `:`).
            data = decodeAsciiHex(rawData, bytesPerRow: bytesPerRow, totalBytes: totalBytes)
        case .binary:
            // ^GFB carries raw binary bytes (one byte == 8 horizontal pixels).
            // Real binary `^GF` over a text channel is rare, but the decode is
            // trivial: the bytes are used as-is.
            data = decodeBinary(rawData, totalBytes: totalBytes)
        case .compressed:
            // ^GFC carries `:Z64:` (base64 + zlib) or `:B64:` (base64) payloads.
            data = decodeCompressed(rawData, totalBytes: totalBytes)
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

    // MARK: - ASCII hex (with Zebra run-length compression)

    /// Decodes the ASCII-hex data field of a `^GFA` command.
    ///
    /// Supports Zebra's ASCII run-length compression that real ZPL generators emit:
    /// - Repeat-count letters precede a hex nibble and repeat that nibble:
    ///   `G`-`Y` mean 1-19, `g`-`z` mean 20-400 in multiples of 20. Counts can be
    ///   combined (e.g. `hG` = 160 + 1 = 161 repeats of the following nibble).
    /// - `,` fills the remainder of the current row with `0x00` (white).
    /// - `!` fills the remainder of the current row with `0xFF` (black).
    /// - `:` repeats the entire previous row.
    ///
    /// Plain (uncompressed) hex still decodes byte-identically to the previous
    /// implementation, so existing `^GFA` fixtures are unaffected.
    private static func decodeAsciiHex(_ raw: String, bytesPerRow: Int, totalBytes: Int) -> [UInt8] {
        // Strip whitespace; uppercase only the hex nibbles, but preserve case of the
        // repeat-count letters (g-z are distinct from G-Y), so uppercase later.
        let cleaned = raw.unicodeScalars.filter { $0 != " " && $0 != "\n" && $0 != "\r" && $0 != "\t" }

        // Fast path: if there are no compression control characters, decode as plain
        // hex pairs. This keeps the common case identical to the old behavior.
        let hasCompression = cleaned.contains { scalar in
            let c = Character(scalar)
            if c == "," || c == "!" || c == ":" { return true }
            // Repeat-count letters are ASCII letters that are not hex digits A-F.
            if c.isLetter, !("0"..."9").contains(c), !("A"..."F").contains(c), !("a"..."f").contains(c) {
                return true
            }
            return false
        }

        if !hasCompression {
            return decodePlainHex(String(String.UnicodeScalarView(cleaned)))
        }

        var data: [UInt8] = []
        var nibbles: [UInt8] = []          // accumulated 4-bit values for the current run
        var rowStart = 0                   // index into `data` where the current row began
        var pendingRepeat = 0              // accumulated repeat count

        func flushNibblesToBytes() {
            // Combine accumulated nibbles into bytes (high nibble first).
            var i = 0
            while i + 1 < nibbles.count {
                data.append((nibbles[i] << 4) | nibbles[i + 1])
                i += 2
            }
            if i < nibbles.count {
                // Odd trailing nibble: pad low nibble with zero (matches printer behavior).
                data.append(nibbles[i] << 4)
            }
            nibbles.removeAll(keepingCapacity: true)
        }

        func fillRow(with byte: UInt8) {
            flushNibblesToBytes()
            let consumed = data.count - rowStart
            if consumed < bytesPerRow {
                data.append(contentsOf: repeatElement(byte, count: bytesPerRow - consumed))
            }
            rowStart = data.count
        }

        func repeatPreviousRow() {
            flushNibblesToBytes()
            // `:` is only meaningful at a row boundary. If mid-row, finish the row first
            // (printers treat the partial row as-is), then copy the prior full row.
            if data.count - rowStart != 0 {
                // Pad the current partial row out before duplicating the previous one.
                let consumed = data.count - rowStart
                if consumed < bytesPerRow {
                    data.append(contentsOf: repeatElement(0, count: bytesPerRow - consumed))
                }
                rowStart = data.count
            }
            guard rowStart >= bytesPerRow else { return }
            let prev = Array(data[(rowStart - bytesPerRow)..<rowStart])
            data.append(contentsOf: prev)
            rowStart = data.count
        }

        for scalar in cleaned {
            let ch = Character(scalar)

            if ch == "," {
                fillRow(with: 0x00)
                pendingRepeat = 0
                continue
            }
            if ch == "!" {
                fillRow(with: 0xFF)
                pendingRepeat = 0
                continue
            }
            if ch == ":" {
                repeatPreviousRow()
                pendingRepeat = 0
                continue
            }

            // Repeat-count letters: G-Y => 1-19, g-z => 20-400 (multiples of 20).
            if ("G"..."Y").contains(ch) {
                pendingRepeat += Int(ch.asciiValue! - Character("G").asciiValue!) + 1
                continue
            }
            if ("g"..."z").contains(ch) {
                pendingRepeat += (Int(ch.asciiValue! - Character("g").asciiValue!) + 1) * 20
                continue
            }

            // Hex nibble.
            if let nibble = hexNibble(ch) {
                let count = max(pendingRepeat, 1)
                nibbles.append(contentsOf: repeatElement(nibble, count: count))
                pendingRepeat = 0

                // Whenever the accumulated nibbles complete the current row, flush so
                // row tracking (for `,`/`!`/`:`) stays accurate.
                while nibbles.count >= 2 && (data.count - rowStart) + (nibbles.count / 2) >= bytesPerRow {
                    // Emit enough byte pairs to reach exactly the row boundary, then reset.
                    let bytesNeeded = bytesPerRow - (data.count - rowStart)
                    var emitted = 0
                    var i = 0
                    while emitted < bytesNeeded && i + 1 < nibbles.count {
                        data.append((nibbles[i] << 4) | nibbles[i + 1])
                        i += 2
                        emitted += 1
                    }
                    nibbles.removeFirst(i)
                    rowStart = data.count
                }
                continue
            }

            // Unknown character: ignore (matches lenient printer parsing).
            pendingRepeat = 0
        }

        flushNibblesToBytes()

        // If a final partial row remains, pad it to a full row of zeros so the
        // renderer sees a rectangular bitmap.
        let trailing = data.count - rowStart
        if trailing > 0 && trailing < bytesPerRow {
            data.append(contentsOf: repeatElement(0, count: bytesPerRow - trailing))
        }

        // Clamp to totalBytes if the data over-ran (defensive; should not normally happen).
        if totalBytes > 0 && data.count > totalBytes {
            data.removeLast(data.count - totalBytes)
        }

        return data
    }

    private static func decodePlainHex(_ hex: String) -> [UInt8] {
        var data: [UInt8] = []
        let chars = Array(hex.uppercased())
        data.reserveCapacity(chars.count / 2)

        var index = 0
        while index < chars.count {
            let hi = hexNibble(chars[index])
            guard let hiVal = hi else { index += 1; continue }
            if index + 1 < chars.count, let loVal = hexNibble(chars[index + 1]) {
                data.append((hiVal << 4) | loVal)
                index += 2
            } else {
                // Odd trailing nibble.
                data.append(hiVal << 4)
                index += 1
            }
        }
        return data
    }

    private static func hexNibble(_ ch: Character) -> UInt8? {
        switch ch {
        case "0"..."9": return UInt8(ch.asciiValue! - Character("0").asciiValue!)
        case "A"..."F": return UInt8(ch.asciiValue! - Character("A").asciiValue! + 10)
        case "a"..."f": return UInt8(ch.asciiValue! - Character("a").asciiValue! + 10)
        default: return nil
        }
    }

    // MARK: - Binary (^GFB)

    /// Decodes the raw-binary data field of a `^GFB` command. Each Unicode scalar in
    /// the field maps directly to its byte value (the field is raw bytes, one byte
    /// per 8 horizontal pixels). Scalars >= 256 are skipped defensively.
    private static func decodeBinary(_ raw: String, totalBytes: Int) -> [UInt8] {
        var data: [UInt8] = []
        data.reserveCapacity(raw.unicodeScalars.count)
        for scalar in raw.unicodeScalars where scalar.value < 256 {
            data.append(UInt8(scalar.value))
        }
        if totalBytes > 0 && data.count > totalBytes {
            data.removeLast(data.count - totalBytes)
        }
        return data
    }

    // MARK: - Compressed (^GFC : Z64 / B64)

    /// Decodes the `^GFC` data field. Zebra wraps compressed graphic data as
    /// `:Z64:<base64>:<crc>` (zlib-deflated, base64-encoded) or
    /// `:B64:<base64>:<crc>` (base64-encoded, uncompressed).
    ///
    /// - `:B64:` is fully supported via `Data(base64Encoded:)`.
    /// - `:Z64:` is supported via the `Compression` framework's zlib inflate when
    ///   available; if `Compression` is unavailable the payload is dropped gracefully.
    private static func decodeCompressed(_ raw: String, totalBytes: Int) -> [UInt8] {
        // Strip a trailing CRC (`:<4 hex>`) if present, and the leading marker.
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        func payload(after marker: String) -> String? {
            guard trimmed.hasPrefix(marker) else { return nil }
            var body = String(trimmed.dropFirst(marker.count))
            // Zebra appends `:<crc16-hex>` after the base64 body. Drop it if present.
            if let colonIndex = body.lastIndex(of: ":") {
                body = String(body[..<colonIndex])
            }
            return body
        }

        if let b64 = payload(after: ":B64:") {
            guard let decoded = Data(base64Encoded: b64) else { return [] }
            return clamp([UInt8](decoded), to: totalBytes)
        }

        if let z64 = payload(after: ":Z64:") {
            guard let deflated = Data(base64Encoded: z64) else { return [] }
            #if canImport(Compression)
            if let inflated = zlibInflate(deflated, expectedSize: totalBytes) {
                return clamp(inflated, to: totalBytes)
            }
            return []
            #else
            // TODO: zlib inflate requires the Compression framework, which is not
            // available on this platform. The compressed graphic is dropped.
            return []
            #endif
        }

        // Unknown / unmarked compressed payload: drop gracefully.
        // TODO: handle bare (unmarked) Z64/B64 payloads if a printer emits them.
        return []
    }

    private static func clamp(_ data: [UInt8], to totalBytes: Int) -> [UInt8] {
        guard totalBytes > 0, data.count > totalBytes else { return data }
        return Array(data.prefix(totalBytes))
    }

    #if canImport(Compression)
    /// Inflates raw zlib (`:Z64:`) data using the Compression framework. The Zebra
    /// `:Z64:` stream is a standard zlib stream (2-byte header + DEFLATE + Adler-32),
    /// so we strip the 2-byte zlib header and trailing checksum and feed the raw
    /// DEFLATE body to `COMPRESSION_ZLIB`.
    private static func zlibInflate(_ data: Data, expectedSize: Int) -> [UInt8]? {
        guard data.count > 6 else { return nil }
        // Strip 2-byte zlib header and 4-byte Adler-32 trailer to get raw DEFLATE.
        let rawDeflate = data.subdata(in: 2..<(data.count - 4))

        // Size the destination from totalBytes when known; otherwise use a generous
        // multiple of the compressed size.
        let capacity = expectedSize > 0 ? expectedSize : max(rawDeflate.count * 8, 1024)
        var destination = [UInt8](repeating: 0, count: capacity)

        let decodedCount = rawDeflate.withUnsafeBytes { srcRaw -> Int in
            guard let srcPtr = srcRaw.bindMemory(to: UInt8.self).baseAddress else { return 0 }
            return destination.withUnsafeMutableBufferPointer { dstBuf -> Int in
                compression_decode_buffer(
                    dstBuf.baseAddress!, capacity,
                    srcPtr, rawDeflate.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }

        guard decodedCount > 0 else { return nil }
        destination.removeLast(destination.count - decodedCount)
        return destination
    }
    #endif
}
