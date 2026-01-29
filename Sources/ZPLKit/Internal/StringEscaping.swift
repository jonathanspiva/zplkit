/// Escapes a string for use in ZPL field data.
/// Uses ^FH (field hex) mode with _XX hex encoding for special characters.
func escapeZPLFieldData(_ string: String) -> (needsHexMode: Bool, escaped: String) {
    var needsHexMode = false
    var result = ""

    for char in string {
        guard let ascii = char.asciiValue else {
            // Non-ASCII: hex encode
            needsHexMode = true
            for byte in char.utf8 {
                result += String(format: "_%02X", byte)
            }
            continue
        }

        switch ascii {
        case 0x5E: // ^ (caret) - ZPL command prefix
            needsHexMode = true
            result += "_5E"
        case 0x7E: // ~ (tilde) - ZPL command prefix
            needsHexMode = true
            result += "_7E"
        case 0x5F: // _ (underscore) - hex escape prefix, must be escaped
            needsHexMode = true
            result += "_5F"
        default:
            result.append(char)
        }
    }

    return (needsHexMode, result)
}
