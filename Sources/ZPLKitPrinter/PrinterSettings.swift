import Foundation

/// Parsed configuration settings returned from a Zebra printer via the `^HH` command.
///
/// Use `ZPLPrinter.queryConfiguration()` to retrieve this from a connected printer.
/// The `^HH` response format varies by printer generation, so some fields may be
/// nil if the parser doesn't recognize the format for a particular printer.
///
/// ## Example
///
/// ```swift
/// let printer = ZPLPrinter(host: "192.168.1.100")
/// let settings = try await printer.queryConfiguration()
///
/// if let darkness = settings.darkness {
///     print("Darkness: \(darkness)")
/// }
/// ```
public struct PrinterSettings: Sendable, Equatable, Codable {

    /// Print darkness (0-30). ZPL: `~SD`.
    public var darkness: Int?

    /// Print speed in inches per second. ZPL: `^PR`.
    public var printSpeed: Int?

    /// Media type (direct thermal or thermal transfer). ZPL: `^MT`.
    public var mediaType: MediaType?

    /// How the printer detects labels on the roll. ZPL: `^MN`.
    public var mediaTracking: MediaTracking?

    /// Print width in dots. ZPL: `^PW`.
    public var printWidthDots: Int?

    /// Label length in dots. ZPL: `^LL`.
    public var labelLengthDots: Int?

    /// How labels are presented after printing. ZPL: `^MM`.
    public var printMode: PrintMode?

    /// Tear-off position adjustment in dots. ZPL: `~TA`.
    public var tearOffAdjust: Int?

    // MARK: - Diagnostic Fields

    /// Printer serial number (e.g., "31J114702349").
    public var serialNumber: String?

    /// Firmware version string from `^HH` (e.g., "V53.17.24Z").
    public var firmware: String?

    /// Lifetime usage counter in inches (ZM400: "NONRESET CNTR", GX420t: "TOTAL USAGE").
    public var nonresetCounterInches: Int?

    /// Resettable usage counter in inches (ZM400: "RESET CNTR1", GX420t: "HEAD USAGE").
    public var resetCounterInches: Int?

    /// Inches since last head cleaning (GX420t only: "LAST CLEANED").
    public var lastCleanedInches: Int?

    /// Maximum label length in inches (e.g., 39.0 from "39.0IN   988MM").
    public var maximumLengthInches: Double?

    /// Creates an empty PrinterSettings. Use ``parse(from:)`` to populate
    /// from a `^HH` response.
    public init() {}
}

// MARK: - Response Parsing

extension PrinterSettings {

    /// Parses printer settings from a raw `^HH` response.
    ///
    /// The `^HH` response is a multi-line text dump of printer configuration.
    /// Each line contains a setting description and its value. The format
    /// varies across printer generations, so parsing uses flexible keyword
    /// matching.
    ///
    /// - Parameter data: Raw response data from the printer.
    /// - Returns: Parsed printer settings (fields may be nil if not found).
    /// - Throws: `PrinterError.invalidResponse` if the data cannot be decoded.
    public static func parse(from data: Data) throws -> PrinterSettings {
        guard let text = String(data: data, encoding: .utf8) else {
            throw PrinterError.invalidResponse("^HH response could not be decoded as UTF-8")
        }

        return parse(from: text)
    }

    /// Parses printer settings from a `^HH` response string.
    ///
    /// The `^HH` response uses a two-column format where the value appears on the
    /// left and the field name on the right, separated by whitespace:
    /// ```
    ///   +15                 DARKNESS
    ///   2 IPS               PRINT SPEED
    ///   THERMAL-TRANS.      PRINT METHOD
    ///   GAP/NOTCH           MEDIA TYPE
    /// ```
    ///
    /// The "MEDIA TYPE" field refers to media tracking (gap, continuous, mark),
    /// while "PRINT METHOD" indicates thermal mode (direct-thermal vs thermal-transfer).
    ///
    /// - Parameter text: The response text from `^HH`.
    /// - Returns: Parsed printer settings.
    public static func parse(from text: String) -> PrinterSettings {
        var settings = PrinterSettings()

        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        for line in lines {
            let upper = line.uppercased()

            // Darkness: "  +15                 DARKNESS"
            if upper.hasSuffix("DARKNESS") {
                if let value = extractInt(from: line) {
                    settings.darkness = value
                }
            }

            // Print speed: "  2 IPS               PRINT SPEED"
            if upper.hasSuffix("PRINT SPEED") {
                if let value = extractInt(from: line) {
                    settings.printSpeed = value
                }
            }

            // Print method (thermal mode): "  THERMAL-TRANS.      PRINT METHOD"
            // This is distinct from MEDIA TYPE which refers to tracking mode.
            if upper.hasSuffix("PRINT METHOD") {
                if upper.contains("DIRECT") {
                    settings.mediaType = .directThermal
                } else if upper.contains("THERMAL-TRANS") || upper.contains("TRANSFER") {
                    settings.mediaType = .thermalTransfer
                }
            }

            // Media type (tracking mode): "  GAP/NOTCH           MEDIA TYPE"
            // or "  CONTINUOUS          MEDIA TYPE"
            if upper.hasSuffix("MEDIA TYPE") {
                if upper.contains("CONTINUOUS") {
                    settings.mediaTracking = .continuous
                } else if upper.contains("GAP") || upper.contains("NOTCH")
                            || upper.contains("NON-CONTINUOUS") {
                    settings.mediaTracking = .gap
                } else if upper.contains("MARK") {
                    settings.mediaTracking = .mark
                }
            }

            // Sensor type/select as fallback for tracking: "  WEB  SENSOR TYPE"
            // or "  TRANSMISSIVE        SENSOR SELECT"
            if settings.mediaTracking == nil
                && (upper.hasSuffix("SENSOR TYPE") || upper.hasSuffix("SENSOR SELECT")) {
                if upper.contains("WEB") || upper.contains("TRANSMISSIVE") {
                    settings.mediaTracking = .gap
                } else if upper.contains("MARK") || upper.contains("REFLECTIVE") {
                    settings.mediaTracking = .mark
                }
            }

            // Print width: "  812                 PRINT WIDTH"
            if upper.hasSuffix("PRINT WIDTH") {
                if let value = extractInt(from: line) {
                    settings.printWidthDots = value
                }
            }

            // Label length: "  0419                LABEL LENGTH"
            if upper.hasSuffix("LABEL LENGTH") {
                if let value = extractInt(from: line) {
                    settings.labelLengthDots = value
                }
            }

            // Print mode: "  TEAR OFF            PRINT MODE"
            if upper.hasSuffix("PRINT MODE") {
                if upper.contains("TEAR") {
                    settings.printMode = .tearOff
                } else if upper.contains("PEEL") {
                    settings.printMode = .peel
                } else if upper.contains("REWIND") {
                    settings.printMode = .rewind
                } else if upper.contains("CUTTER") || upper.contains("CUT") {
                    settings.printMode = .cutter
                }
            }

            // Tear-off adjust: "  +000                TEAR OFF"
            // Only match "TEAR OFF" as a field name (suffix), not when it's
            // a value in PRINT MODE. The field name version ends with "TEAR OFF"
            // and has a numeric value on the left.
            if upper.hasSuffix("TEAR OFF") && !upper.contains("PRINT MODE") {
                if let value = extractSignedInt(from: line) {
                    settings.tearOffAdjust = value
                }
            }

            // Serial number: "31J114702349        SERIAL NUMBER"
            if upper.hasSuffix("SERIAL NUMBER") {
                if let value = extractLeftValue(from: line, suffix: "SERIAL NUMBER") {
                    settings.serialNumber = value
                }
            }

            // Firmware: "V53.17.24Z <-       FIRMWARE"
            if upper.hasSuffix("FIRMWARE") {
                if var value = extractLeftValue(from: line, suffix: "FIRMWARE") {
                    // Strip arrow marker if present
                    if let arrowRange = value.range(of: "<-") {
                        value = String(value[..<arrowRange.lowerBound])
                            .trimmingCharacters(in: .whitespaces)
                    }
                    settings.firmware = value
                }
            }

            // Lifetime usage: "111,367 IN          NONRESET CNTR" or "500 IN              TOTAL USAGE"
            if upper.hasSuffix("NONRESET CNTR") || upper.hasSuffix("TOTAL USAGE") {
                if let value = extractCommaInt(from: line) {
                    settings.nonresetCounterInches = value
                }
            }

            // Resettable usage: "111,367 IN          RESET CNTR1" or "500 IN              HEAD USAGE"
            if upper.hasSuffix("RESET CNTR1") || upper.hasSuffix("HEAD USAGE") {
                if let value = extractCommaInt(from: line) {
                    settings.resetCounterInches = value
                }
            }

            // Last cleaned: "200 IN              LAST CLEANED"
            if upper.hasSuffix("LAST CLEANED") {
                if let value = extractCommaInt(from: line) {
                    settings.lastCleanedInches = value
                }
            }

            // Maximum length: "39.0IN   988MM      MAXIMUM LENGTH"
            if upper.hasSuffix("MAXIMUM LENGTH") {
                if let value = extractMaxLength(from: line) {
                    settings.maximumLengthInches = value
                }
            }
        }

        return settings
    }

    /// Extracts the first signed integer found in a line (handles +000, -015, etc).
    private static func extractSignedInt(from line: String) -> Int? {
        // Scan for a sign followed by digits, or just digits
        var i = line.startIndex
        while i < line.endIndex {
            let c = line[i]
            if c == "+" || c == "-" || c.isNumber {
                var end = line.index(after: i)
                // If we started with a sign, need at least one digit after
                if (c == "+" || c == "-") {
                    guard end < line.endIndex && line[end].isNumber else {
                        i = end
                        continue
                    }
                }
                while end < line.endIndex && line[end].isNumber {
                    end = line.index(after: end)
                }
                if let value = Int(line[i..<end]) {
                    return value
                }
            }
            i = line.index(after: i)
        }
        return nil
    }

    /// Extracts the first integer found in a line.
    private static func extractInt(from line: String) -> Int? {
        // Split on common delimiters and find the first integer token
        let tokens = line.components(separatedBy: CharacterSet.alphanumerics.inverted)
        for token in tokens {
            if let value = Int(token), !token.isEmpty {
                return value
            }
        }
        return nil
    }

    /// Extracts the left-side value from a `^HH` line by removing the known suffix.
    ///
    /// `^HH` lines have the format: `VALUE          FIELD NAME`
    /// where value and field name are separated by 2+ spaces.
    private static func extractLeftValue(from line: String, suffix: String) -> String? {
        let upper = line.uppercased()
        guard let suffixRange = upper.range(of: suffix) else { return nil }
        let leftPart = line[line.startIndex..<suffixRange.lowerBound]
        let trimmed = leftPart.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Extracts a comma-formatted integer with " IN" suffix (e.g., "111,367 IN" -> 111367).
    private static func extractCommaInt(from line: String) -> Int? {
        let upper = line.uppercased()
        // Find the "IN" marker followed by spaces (separating value from field name)
        guard let inRange = upper.range(of: " IN") else { return nil }
        let leftPart = String(line[line.startIndex..<inRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        let stripped = leftPart.replacingOccurrences(of: ",", with: "")
        return Int(stripped)
    }

    /// Extracts maximum length in inches from "39.0IN   988MM" format.
    private static func extractMaxLength(from line: String) -> Double? {
        let upper = line.uppercased()
        // Look for a number immediately before "IN" (e.g., "39.0IN")
        guard let inRange = upper.range(of: "IN") else { return nil }
        let leftPart = String(line[line.startIndex..<inRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        // The number is the last whitespace-separated token before "IN"
        let tokens = leftPart.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        guard let lastToken = tokens.last else { return nil }
        return Double(lastToken)
    }
}

// MARK: - CustomStringConvertible

extension PrinterSettings: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []

        if let darkness { parts.append("darkness: \(darkness)") }
        if let printSpeed { parts.append("speed: \(printSpeed) IPS") }
        if let mediaType {
            parts.append("media: \(mediaType == .directThermal ? "direct-thermal" : "thermal-transfer")")
        }
        if let mediaTracking {
            let trackingStr: String
            switch mediaTracking {
            case .gap: trackingStr = "gap"
            case .continuous: trackingStr = "continuous"
            case .mark: trackingStr = "mark"
            case .auto: trackingStr = "auto"
            }
            parts.append("tracking: \(trackingStr)")
        }
        if let printWidthDots { parts.append("width: \(printWidthDots) dots") }
        if let labelLengthDots { parts.append("length: \(labelLengthDots) dots") }
        if let printMode {
            let modeStr: String
            switch printMode {
            case .tearOff: modeStr = "tear-off"
            case .peel: modeStr = "peel"
            case .rewind: modeStr = "rewind"
            case .cutter: modeStr = "cutter"
            }
            parts.append("mode: \(modeStr)")
        }
        if let tearOffAdjust { parts.append("tear-off adjust: \(tearOffAdjust)") }
        if let serialNumber { parts.append("serial: \(serialNumber)") }
        if let firmware { parts.append("firmware: \(firmware)") }
        if let nonresetCounterInches { parts.append("lifetime: \(nonresetCounterInches) in") }
        if let resetCounterInches { parts.append("head usage: \(resetCounterInches) in") }
        if let lastCleanedInches { parts.append("last cleaned: \(lastCleanedInches) in") }
        if let maximumLengthInches { parts.append("max length: \(maximumLengthInches) in") }

        return parts.isEmpty ? "No settings parsed" : parts.joined(separator: ", ")
    }
}
