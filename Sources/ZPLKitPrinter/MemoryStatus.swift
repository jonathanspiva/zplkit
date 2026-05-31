import Foundation

/// RAM memory status returned from a Zebra printer via the `~HM` command.
///
/// Use `ZPLPrinter.queryMemory()` to retrieve this information from a connected printer.
///
/// ## Example
///
/// ```swift
/// let printer = ZPLPrinter(host: "192.168.1.100")
/// let memory = try await printer.queryMemory()
///
/// print("Available: \(memory.availableFormatted) of \(memory.totalFormatted)")
/// print("Usage: \(memory.usagePercent)%")
/// ```
public struct MemoryStatus: Sendable, Equatable, Codable {
    /// Total RAM in bytes.
    public var total: Int

    /// Maximum RAM available for use in bytes.
    public var maximum: Int

    /// Currently available (free) RAM in bytes.
    public var available: Int

    /// Memory currently in use in bytes.
    public var used: Int {
        total - available
    }

    /// Memory usage as a percentage (0-100).
    public var usagePercent: Int {
        guard total > 0 else { return 0 }
        return Int((Double(used) / Double(total)) * 100)
    }

    /// Total memory formatted for display (e.g., "48KB", "2MB").
    public var totalFormatted: String {
        Self.formatBytes(total)
    }

    /// Available memory formatted for display.
    public var availableFormatted: String {
        Self.formatBytes(available)
    }

    /// Used memory formatted for display.
    public var usedFormatted: String {
        Self.formatBytes(used)
    }

    /// Creates a MemoryStatus with all fields specified.
    public init(total: Int, maximum: Int, available: Int) {
        self.total = total
        self.maximum = maximum
        self.available = available
    }

    /// Formats bytes as a human-readable string.
    private static func formatBytes(_ bytes: Int) -> String {
        if bytes >= 1_048_576 {  // 1 MB
            return "\(bytes / 1_048_576)MB"
        } else if bytes >= 1024 {
            return "\(bytes / 1024)KB"
        } else {
            return "\(bytes)B"
        }
    }
}

// MARK: - Response Parsing

extension MemoryStatus {
    /// ASCII control characters used in ZPL responses.
    private enum ControlChar {
        static let stx: UInt8 = 0x02  // Start of Text
        static let etx: UInt8 = 0x03  // End of Text
    }

    /// Parses memory status from a raw `~HM` response.
    ///
    /// The `~HM` response contains three comma-separated values:
    ///
    /// ```
    /// <STX>TOTAL,MAXIMUM,AVAILABLE<ETX><CR><LF>
    /// ```
    ///
    /// Example: `<STX>2097152,2097152,1847296<ETX><CR><LF>`
    ///
    /// - Parameter data: Raw response data from the printer.
    /// - Returns: Parsed memory status.
    /// - Throws: `PrinterError.invalidResponse` if the response cannot be parsed.
    public static func parse(from data: Data) throws -> MemoryStatus {
        // Extract content between STX and ETX
        guard let content = extractContent(from: data) else {
            throw PrinterError.invalidResponse("No valid content found in ~HM response")
        }

        // Split by comma
        let fields = content.split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespaces) }

        guard fields.count >= 3 else {
            throw PrinterError.invalidResponse(
                "Expected 3 fields in ~HM response, got \(fields.count)"
            )
        }

        guard let total = Int(fields[0]) else {
            throw PrinterError.invalidResponse("Invalid total memory value: \(fields[0])")
        }

        guard let maximum = Int(fields[1]) else {
            throw PrinterError.invalidResponse("Invalid maximum memory value: \(fields[1])")
        }

        guard let available = Int(fields[2]) else {
            throw PrinterError.invalidResponse("Invalid available memory value: \(fields[2])")
        }

        return MemoryStatus(total: total, maximum: maximum, available: available)
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

        // Fallback: try parsing without STX/ETX framing
        if let str = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty {
            return str
        }

        return nil
    }
}

// MARK: - CustomStringConvertible

extension MemoryStatus: CustomStringConvertible {
    public var description: String {
        "\(availableFormatted) available of \(totalFormatted) (\(usagePercent)% used)"
    }
}
