import Foundation

/// Identification information returned from a Zebra printer via the `~HI` command.
///
/// Use `ZPLPrinter.queryInfo()` to retrieve this information from a connected printer.
///
/// ## Example
///
/// ```swift
/// let printer = ZPLPrinter(host: "192.168.1.100")
/// let info = try await printer.queryInfo()
///
/// print("Model: \(info.model)")
/// print("Firmware: \(info.firmwareVersion)")
/// print("Resolution: \(info.dpi) dpi")
/// ```
public struct PrinterInfo: Sendable, Equatable, Codable {
    /// The printer model name (e.g., "ZT410-203dpi", "ZM400-200dpi").
    public var model: String

    /// The firmware version string (e.g., "V53.17.14Z").
    public var firmwareVersion: String

    /// Dots per millimeter reported by the printer.
    ///
    /// Common values:
    /// - 6 = 152 dpi
    /// - 8 = 203 dpi
    /// - 12 = 300 dpi
    /// - 24 = 600 dpi
    public var dotsPerMillimeter: Int

    /// Print resolution in dots per inch.
    ///
    /// Standard Zebra resolutions are mapped exactly; other values fall back to
    /// rounding `dotsPerMillimeter * 25.4` (rounded, not truncated, so e.g.
    /// dpm 12 yields 305 rather than 304).
    public var dpi: Int {
        switch dotsPerMillimeter {
        case 6: return 150
        case 8: return 203
        case 12: return 300
        case 24: return 600
        default: return Int((Double(dotsPerMillimeter) * 25.4).rounded())
        }
    }

    /// Available memory in kilobytes.
    public var memoryKB: Int

    /// Available memory formatted as a string (e.g., "49152KB", "64MB").
    public var memoryFormatted: String {
        if memoryKB >= 1024 {
            return "\(memoryKB / 1024)MB"
        } else {
            return "\(memoryKB)KB"
        }
    }

    /// Installed options (e.g., "CUTTER", "REWIND") or empty if none.
    public var options: [String]

    /// Creates a PrinterInfo with all fields specified.
    public init(
        model: String,
        firmwareVersion: String,
        dotsPerMillimeter: Int,
        memoryKB: Int,
        options: [String] = []
    ) {
        self.model = model
        self.firmwareVersion = firmwareVersion
        self.dotsPerMillimeter = dotsPerMillimeter
        self.memoryKB = memoryKB
        self.options = options
    }
}

// MARK: - Response Parsing

extension PrinterInfo {
    /// ASCII control characters used in ZPL responses.
    private enum ControlChar {
        static let stx: UInt8 = 0x02  // Start of Text
        static let etx: UInt8 = 0x03  // End of Text
    }

    /// Parses printer info from a raw `~HI` response.
    ///
    /// The `~HI` response is a single comma-separated string wrapped in STX/ETX:
    ///
    /// ```
    /// <STX>MODEL,FIRMWARE,DPM,MEMORY,OPTIONS<ETX><CR><LF>
    /// ```
    ///
    /// Example: `<STX>ZT410-203dpi,V53.17.14Z,8,49152KB,NONE<ETX><CR><LF>`
    ///
    /// - Parameter data: Raw response data from the printer.
    /// - Returns: Parsed printer info.
    /// - Throws: `PrinterError.invalidResponse` if the response cannot be parsed.
    public static func parse(from data: Data) throws -> PrinterInfo {
        // Extract content between STX and ETX
        guard let content = extractContent(from: data) else {
            throw PrinterError.invalidResponse("No valid STX/ETX framing found in ~HI response")
        }

        // Split by comma
        let fields = content.split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        guard fields.count >= 4 else {
            throw PrinterError.invalidResponse(
                "Expected at least 4 fields in ~HI response, got \(fields.count)"
            )
        }

        let model = fields[0]
        let firmware = fields[1]

        // Parse dots per millimeter
        guard let dpm = Int(fields[2]) else {
            throw PrinterError.invalidResponse("Invalid dots-per-millimeter value: \(fields[2])")
        }

        // Parse memory (remove "KB" suffix if present)
        let memoryStr = fields[3].replacingOccurrences(of: "KB", with: "")
            .replacingOccurrences(of: "kb", with: "")
        guard let memory = Int(memoryStr) else {
            throw PrinterError.invalidResponse("Invalid memory value: \(fields[3])")
        }

        // Parse options (may be "NONE" or comma-separated list in remaining fields)
        var options: [String] = []
        if fields.count > 4 {
            let optionStr = fields[4]
            if optionStr.uppercased() != "NONE" && !optionStr.isEmpty {
                // Could be multiple options in remaining fields
                options = Array(fields[4...]).filter {
                    !$0.isEmpty && $0.uppercased() != "NONE"
                }
            }
        }

        return PrinterInfo(
            model: model,
            firmwareVersion: firmware,
            dotsPerMillimeter: dpm,
            memoryKB: memory,
            options: options
        )
    }

    /// Extracts content between STX and ETX from response data.
    private static func extractContent(from data: Data) -> String? {
        // Normalize to a 0-based byte array so enumerated offsets line up with
        // subscripting (Data's subscript is offset by startIndex for slices).
        let bytes = [UInt8](data)
        var startIndex: Int?

        for (index, byte) in bytes.enumerated() {
            if byte == ControlChar.stx {
                startIndex = index + 1
            } else if byte == ControlChar.etx, let start = startIndex {
                if start < index {
                    let content = bytes[start..<index]
                    return String(bytes: content, encoding: .utf8)
                }
            }
        }

        // Fallback: try parsing without STX/ETX framing (some printers may not include it)
        if let str = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty {
            return str
        }

        return nil
    }
}

// MARK: - CustomStringConvertible

extension PrinterInfo: CustomStringConvertible {
    public var description: String {
        var parts = ["\(model)", "FW \(firmwareVersion)", "\(dpi)dpi", memoryFormatted]
        if !options.isEmpty {
            parts.append(options.joined(separator: ", "))
        }
        return parts.joined(separator: ", ")
    }
}
