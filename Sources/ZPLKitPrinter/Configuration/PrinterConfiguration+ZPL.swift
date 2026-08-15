#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

extension PrinterConfiguration {

    // MARK: - Validation Helpers

    /// ZPL control characters that must never appear inside an interpolated
    /// field value, plus the comma parameter separator. Allowing any of these
    /// through would let a value break out of its command and inject arbitrary
    /// ZPL.
    private static let zplUnsafeCharacters: Set<Character> = ["^", "~", ","]

    /// Strips ZPL-significant characters (`^`, `~`, `,`) from an interpolated
    /// value so it cannot break out of its command.
    private static func sanitize(_ value: String) -> String {
        value.filter { !zplUnsafeCharacters.contains($0) }
    }

    /// Returns the value if it is a valid IPv4 or IPv6 literal, otherwise nil.
    /// Network commands are skipped entirely when an address is invalid rather
    /// than emitting a malformed (and potentially injectable) command.
    private static func validatedIPAddress(_ value: String) -> String? {
        var v4 = in_addr()
        if value.withCString({ inet_pton(AF_INET, $0, &v4) }) == 1 {
            return value
        }
        var v6 = in6_addr()
        if value.withCString({ inet_pton(AF_INET6, $0, &v6) }) == 1 {
            return value
        }
        return nil
    }

    /// Generates the ZPL commands for this configuration.
    ///
    /// Only non-nil fields produce commands. Commands are ordered correctly:
    /// immediate commands (`~` prefix) come first, then format commands
    /// are wrapped in a `^XA...^XZ` block.
    ///
    /// - Parameter save: When true, appends `^JUS` to the format block so
    ///   the configuration is saved to non-volatile memory in the same TCP payload.
    /// - Returns: An array of complete ZPL command strings ready to send.
    ///   Typically one or two strings: immediate commands (if any) and
    ///   a format block (if any).
    public func zplCommands(save: Bool = false) -> [String] {
        var immediateCommands: [String] = []
        var formatCommands: [String] = []

        // MARK: - Immediate Commands (~prefix, sent outside ^XA/^XZ)

        // ~SD: Set Darkness (00-30). Clamp here as the last line of defense:
        // the public `darkness` var and Codable can set out-of-range values
        // that bypass the clamping modifier.
        if let darkness {
            let clamped = max(0, min(30, darkness))
            let padded = String(format: "%02d", clamped)
            immediateCommands.append("~SD\(padded)")
        }

        // ~TA: Tear-off Adjust Position (-120 to 120). Clamp defensively.
        if let tearOffAdjust {
            let clamped = max(-120, min(120, tearOffAdjust))
            let padded = String(format: "%04d", clamped)
            immediateCommands.append("~TA\(padded)")
        }

        // MARK: - Format Commands (^prefix, inside ^XA/^XZ)

        // ^CI: Character Encoding
        if let characterEncoding {
            formatCommands.append("^CI\(characterEncoding)")
        }

        // ^MT: Media Type
        if let mediaType {
            formatCommands.append("^MT\(mediaType.rawValue)")
        }

        // ^MN: Media Tracking
        if let mediaTracking {
            formatCommands.append("^MN\(mediaTracking.rawValue)")
        }

        // ^MM: Print Mode
        if let printMode {
            formatCommands.append("^MM\(printMode.rawValue)")
        }

        // ^PW: Print Width. Dimensions are dot counts and can never be
        // negative; clamp to 0 so a negative value can't emit invalid ZPL.
        if let printWidthDots {
            formatCommands.append("^PW\(max(0, printWidthDots))")
        }

        // ^LL: Label Length
        if let labelLengthDots {
            formatCommands.append("^LL\(max(0, labelLengthDots))")
        }

        // ^ML: Maximum Label Length
        if let maxLabelLengthDots {
            formatCommands.append("^ML\(max(0, maxLabelLengthDots))")
        }

        // ^PR: Print Speed (print, slew, backfeed). Speeds are 1-14 ips and
        // never negative; clamp to a non-negative value defensively.
        if let printSpeedIPS {
            var cmd = "^PR\(max(0, printSpeedIPS))"
            if let slewSpeedIPS {
                cmd += ",\(max(0, slewSpeedIPS))"
                if let backfeedSpeedIPS {
                    cmd += ",\(max(0, backfeedSpeedIPS))"
                }
            }
            formatCommands.append(cmd)
        } else if let slewSpeedIPS {
            // If slew is set but print speed isn't, we still need ^PR
            var cmd = "^PR,\(max(0, slewSpeedIPS))"
            if let backfeedSpeedIPS {
                cmd += ",\(max(0, backfeedSpeedIPS))"
            }
            formatCommands.append(cmd)
        }

        // ^JS: Sensor Type
        if let sensorType {
            formatCommands.append("^JS\(sensorType.rawValue)")
        }

        // ^PO: Print Orientation
        if let orientation {
            formatCommands.append("^PO\(orientation.rawValue)")
        }

        // ^FW: Field Default Rotation. The FieldRotation enum guarantees one of
        // the four valid N/R/I/B letters.
        if let fieldRotation {
            formatCommands.append("^FW\(fieldRotation.rawValue)")
        }

        // ^LH: Label Home Position
        if let labelHomeX, let labelHomeY {
            formatCommands.append("^LH\(labelHomeX),\(labelHomeY)")
        }

        // ^LT: Label Top Shift
        if let labelTopShift {
            formatCommands.append("^LT\(labelTopShift)")
        }

        // ^LS: Label Shift (left offset)
        if let labelShift {
            formatCommands.append("^LS\(labelShift)")
        }

        // ^MF: Power-Up / Head Close Actions
        if let powerUpAction {
            let headClose = headCloseAction ?? powerUpAction
            formatCommands.append("^MF\(powerUpAction.rawValue),\(headClose.rawValue)")
        } else if let headCloseAction {
            formatCommands.append("^MF,\(headCloseAction.rawValue)")
        }

        // ^JZ: Reprint After Error
        if let reprintAfterError {
            formatCommands.append("^JZ\(reprintAfterError ? "Y" : "N")")
        }

        // ^KN: Define Printer Name (within format block). The ZPL II manual
        // documents the printer-name command as ^KN, not ^JN. The name is
        // sanitized to strip ^, ~, and commas so it cannot inject ZPL.
        if let printerName {
            let safeName = Self.sanitize(printerName)
            if !safeName.isEmpty {
                formatCommands.append("^KN\(safeName)")
            }
        }

        // ^NS: Change Wired Networking Settings.
        // Per the ZPL II manual the format is ^NSa,b,c,d,e,f,g,h,i where:
        //   a = IP resolution (P = PERMANENT/static, D = DHCP, ...)
        //   b = IP address, c = subnet mask, d = default gateway
        // The previous ^ND form did not match ^ND's documented parameters.
        // IP fields are validated with inet_pton; if any is invalid the
        // command is skipped rather than emitting a malformed/injectable value.
        // EXPERIMENTAL / NOT hardware-verified. On a GX420t (V56.17.17Z), an
        // `^NSP,<ip>,<subnet>,<gw>` static change + `^JUS` + `~JR` did NOT change
        // the printer's IP (2026-07-23 round-trip test); it may need a full power
        // cycle or differ by model/firmware. Reference: ZPL II Programming Guide,
        // "^NS Change Wired Networking Settings" (Format ^NSa,b,c,d,e,f,g,h,i).
        // See the warning on PrinterConfiguration.networkConfig(...).
        if let ipAddress, let subnetMask, let gateway {
            if let ip = Self.validatedIPAddress(ipAddress),
               let subnet = Self.validatedIPAddress(subnetMask),
               let gw = Self.validatedIPAddress(gateway) {
                let resolution = dhcpEnabled == true ? "D" : "P"
                formatCommands.append("^NS\(resolution),\(ip),\(subnet),\(gw)")
            }
        } else if dhcpEnabled == true {
            // DHCP-only: set IP resolution to DHCP with no static addresses.
            formatCommands.append("^NSD")
        }

        // Save to non-volatile memory inside the format block
        if save {
            formatCommands.append("^JUS")
        }

        // Build output
        var result: [String] = []

        if !immediateCommands.isEmpty {
            result.append(immediateCommands.joined())
        }

        if !formatCommands.isEmpty {
            result.append("^XA" + formatCommands.joined() + "^XZ")
        }

        return result
    }
}
