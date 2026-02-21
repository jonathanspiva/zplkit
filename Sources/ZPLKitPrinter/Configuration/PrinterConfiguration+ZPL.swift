extension PrinterConfiguration {

    /// Generates the ZPL commands for this configuration.
    ///
    /// Only non-nil fields produce commands. Commands are ordered correctly:
    /// immediate commands (`~` prefix) come first, then format commands
    /// are wrapped in a `^XA...^XZ` block.
    ///
    /// - Returns: An array of complete ZPL command strings ready to send.
    ///   Typically one or two strings: immediate commands (if any) and
    ///   a format block (if any).
    public func zplCommands() -> [String] {
        var immediateCommands: [String] = []
        var formatCommands: [String] = []

        // MARK: - Immediate Commands (~prefix, sent outside ^XA/^XZ)

        // ~SD: Set Darkness (00-30)
        if let darkness {
            let padded = String(format: "%02d", darkness)
            immediateCommands.append("~SD\(padded)")
        }

        // ~TA: Tear-off Adjust Position
        if let tearOffAdjust {
            let padded = String(format: "%04d", tearOffAdjust)
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

        // ^PW: Print Width
        if let printWidthDots {
            formatCommands.append("^PW\(printWidthDots)")
        }

        // ^LL: Label Length
        if let labelLengthDots {
            formatCommands.append("^LL\(labelLengthDots)")
        }

        // ^ML: Maximum Label Length
        if let maxLabelLengthDots {
            formatCommands.append("^ML\(maxLabelLengthDots)")
        }

        // ^PR: Print Speed (print, slew, backfeed)
        if let printSpeedIPS {
            var cmd = "^PR\(printSpeedIPS)"
            if let slewSpeedIPS {
                cmd += ",\(slewSpeedIPS)"
                if let backfeedSpeedIPS {
                    cmd += ",\(backfeedSpeedIPS)"
                }
            }
            formatCommands.append(cmd)
        } else if let slewSpeedIPS {
            // If slew is set but print speed isn't, we still need ^PR
            var cmd = "^PR,\(slewSpeedIPS)"
            if let backfeedSpeedIPS {
                cmd += ",\(backfeedSpeedIPS)"
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

        // ^FW: Field Default Rotation
        if let fieldRotation {
            formatCommands.append("^FW\(fieldRotation)")
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

        // ^JN: Printer Name (within format block)
        if let printerName {
            formatCommands.append("^JN\(printerName)")
        }

        // ^ND: Network Configuration
        if let ipAddress, let subnetMask, let gateway {
            let dhcpFlag = dhcpEnabled == true ? "Y" : "N"
            formatCommands.append("^ND\(ipAddress),\(subnetMask),\(gateway),\(dhcpFlag)")
        } else if dhcpEnabled == true {
            formatCommands.append("^NDY")
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
