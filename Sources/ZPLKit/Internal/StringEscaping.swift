/// Two-character uppercase hex strings for every byte value, so hot escape
/// paths never pay for a `String(format:)` parse per byte.
let hexByteTable: [String] = (0...255).map { byte in
    let digits = Array("0123456789ABCDEF")
    return String([digits[byte >> 4], digits[byte & 0x0F]])
}

/// Escapes a string for use in ZPL field data.
/// Uses ^FH (field hex) mode with _XX hex encoding for special characters.
///
/// Escaped characters:
/// - `^` and `~` (command prefixes) and `_` (the hex-escape indicator itself)
/// - ASCII control characters (0x00-0x1F, 0x7F): firmware strips raw CR/LF
///   from the format stream, so a literal `\n` inside `^FD` would silently
///   vanish from barcode data; `_0A`-style escapes preserve the byte.
/// - Non-ASCII characters, as their UTF-8 bytes. Note the printer only
///   reinterprets those bytes as UTF-8 under `^CI28`, which `ZPLLabel.render()`
///   emits when any field required it.
func escapeZPLFieldData(_ string: String) -> (needsHexMode: Bool, escaped: String) {
    var needsHexMode = false
    var result = ""

    for char in string {
        guard let ascii = char.asciiValue else {
            // Non-ASCII: hex encode the UTF-8 bytes
            needsHexMode = true
            for byte in char.utf8 {
                result += "_"
                result += hexByteTable[Int(byte)]
            }
            continue
        }

        switch ascii {
        case 0x5E, // ^ (caret) - ZPL command prefix
             0x7E, // ~ (tilde) - ZPL command prefix
             0x5F, // _ (underscore) - hex escape prefix, must be escaped
             0x00...0x1F, 0x7F: // ASCII control characters
            needsHexMode = true
            result += "_"
            result += hexByteTable[Int(ascii)]
        default:
            result.append(char)
        }
    }

    return (needsHexMode, result)
}

/// Replaces every non-overlapping occurrence of `target` with `replacement`.
///
/// This exists so the ZPL-generation core stays free of Foundation.
/// `String.replacingOccurrences(of:with:)` is a Foundation API, and several
/// files here used to reach it only because *another* file in the module
/// imported Foundation and the import leaked across the module. That made the
/// core unbuildable for WebAssembly, where the Foundation module in the Swift
/// SDK need not match the host compiler.
///
/// Semantics match the Foundation call for the literal, non-regex case: a scan
/// from the start taking the earliest match each time, so replacements never
/// overlap and the replacement text is never re-scanned. An empty `target`
/// returns the receiver unchanged rather than interleaving.
extension StringProtocol {
    func replacingAll(_ target: String, with replacement: String) -> String {
        guard !target.isEmpty else { return String(self) }
        var result = ""
        var rest = self[...]
        while let match = rest.firstRange(of: target) {
            result += rest[..<match.lowerBound]
            result += replacement
            rest = rest[match.upperBound...]
        }
        result += rest
        return result
    }
}
