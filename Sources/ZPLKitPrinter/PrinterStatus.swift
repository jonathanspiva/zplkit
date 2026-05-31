import Foundation

/// Status information returned from a Zebra printer via the `~HS` command.
///
/// Use `ZPLPrinter.queryStatus()` to retrieve this information from a connected printer.
///
/// ## Example
///
/// ```swift
/// let printer = ZPLPrinter(host: "192.168.1.100")
/// let status = try await printer.queryStatus()
///
/// if status.isReadyToPrint {
///     try await printer.send(label.render())
/// } else if status.isPaperOut {
///     print("Load paper before printing")
/// }
/// ```
///
/// - Important: The printer may not respond to `~HS` when in certain error states
///   (MEDIA OUT, RIBBON OUT, HEAD OPEN). A timeout may indicate a printer error.
public struct PrinterStatus: Sendable, Equatable, Codable {
    // MARK: - Error Conditions

    /// Paper/media is out. Printing cannot continue until media is loaded.
    public var isPaperOut: Bool

    /// Ribbon is out. For thermal transfer printers, printing cannot continue.
    public var isRibbonOut: Bool

    /// Print head is open/raised. Close the head to continue printing.
    public var isHeadOpen: Bool

    /// Print head is too hot. Printing will pause until it cools.
    public var isHeadTooHot: Bool

    /// Print head is too cold. Printing may be affected until it warms up.
    public var isHeadCold: Bool

    // MARK: - Operational Status

    /// Printer is paused. Send `~PP` (Pause/Unpause) to resume.
    public var isPaused: Bool

    /// Receive buffer is full. The printer cannot accept more data.
    public var isReceiveBufferFull: Bool

    /// A partial format is in progress (label is being built).
    public var isPartialFormatInProgress: Bool

    // MARK: - Print Job Information

    /// Number of label formats currently in the receive buffer.
    public var formatsInBuffer: Int

    /// Number of labels remaining in the current batch job.
    public var labelsRemainingInBatch: Int

    /// Label length in dots (as reported by the printer).
    public var labelLengthInDots: Int

    // MARK: - Configuration Fields (from ~HS string 2)

    /// Whether the printer is in thermal transfer mode (true) or direct thermal (false).
    /// Parsed from `~HS` string 2, index 3.
    public var isThermalTransfer: Bool?

    // MARK: - Computed Properties

    /// True if the printer is ready to accept and print labels.
    ///
    /// A printer is ready when:
    /// - Not paused
    /// - Head is closed
    /// - Paper is loaded
    /// - Ribbon is loaded (for thermal transfer)
    /// - Not overheated
    /// - Buffer is not full
    public var isReadyToPrint: Bool {
        !isPaused &&
        !isHeadOpen &&
        !isPaperOut &&
        !isRibbonOut &&
        !isHeadTooHot &&
        !isReceiveBufferFull
    }

    /// True if any error condition is present that would prevent printing.
    public var hasError: Bool {
        isPaperOut || isRibbonOut || isHeadOpen || isHeadTooHot
    }

    // MARK: - Initialization

    /// Creates a PrinterStatus with all fields specified.
    public init(
        isPaperOut: Bool = false,
        isRibbonOut: Bool = false,
        isHeadOpen: Bool = false,
        isHeadTooHot: Bool = false,
        isHeadCold: Bool = false,
        isPaused: Bool = false,
        isReceiveBufferFull: Bool = false,
        isPartialFormatInProgress: Bool = false,
        formatsInBuffer: Int = 0,
        labelsRemainingInBatch: Int = 0,
        labelLengthInDots: Int = 0,
        isThermalTransfer: Bool? = nil
    ) {
        self.isPaperOut = isPaperOut
        self.isRibbonOut = isRibbonOut
        self.isHeadOpen = isHeadOpen
        self.isHeadTooHot = isHeadTooHot
        self.isHeadCold = isHeadCold
        self.isPaused = isPaused
        self.isReceiveBufferFull = isReceiveBufferFull
        self.isPartialFormatInProgress = isPartialFormatInProgress
        self.formatsInBuffer = formatsInBuffer
        self.labelsRemainingInBatch = labelsRemainingInBatch
        self.labelLengthInDots = labelLengthInDots
        self.isThermalTransfer = isThermalTransfer
    }
}

// MARK: - Response Parsing

extension PrinterStatus {
    /// ASCII control characters used in ZPL responses.
    private enum ControlChar {
        static let stx: UInt8 = 0x02  // Start of Text
        static let etx: UInt8 = 0x03  // End of Text
        static let cr: UInt8 = 0x0D   // Carriage Return
        static let lf: UInt8 = 0x0A   // Line Feed
    }

    /// Parses printer status from a raw `~HS` response.
    ///
    /// The `~HS` response consists of three comma-separated strings, each
    /// wrapped in STX...ETX CR LF framing:
    ///
    /// ```
    /// <STX>aaa,b,c,dddd,eee,f,g,h,iii,j,k,l<ETX><CR><LF>
    /// <STX>m,n,o,p,q,r,s,t<ETX><CR><LF>
    /// <STX>u,v<ETX><CR><LF>
    /// ```
    ///
    /// - Parameter data: Raw response data from the printer.
    /// - Returns: Parsed printer status.
    /// - Throws: `PrinterError.invalidResponse` if the response cannot be parsed.
    public static func parse(from data: Data) throws -> PrinterStatus {
        // Extract the content strings (between STX and ETX)
        let strings = extractStrings(from: data)

        guard strings.count >= 2 else {
            throw PrinterError.invalidResponse(
                "Expected at least 2 response strings, got \(strings.count)"
            )
        }

        // Parse string 1: aaa,b,c,dddd,eee,f,g,h,iii,j,k,l
        let fields1 = strings[0].split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0) }

        // Parse string 2: m,n,o,p,q,r,s,t
        let fields2 = strings[1].split(separator: ",", omittingEmptySubsequences: false)
            .map { String($0) }

        // Extract fields from string 1
        // Index: 0=comm, 1=paper out, 2=pause, 3=label length, 4=formats in buffer,
        //        5=buffer full, 6=comm diag, 7=partial format, 8=unused, 9=corrupt RAM,
        //        10=temp range, 11=unused
        let isPaperOut = fields1.count > 1 && fields1[1] == "1"
        let isPaused = fields1.count > 2 && fields1[2] == "1"
        let labelLength = fields1.count > 3 ? Int(fields1[3]) ?? 0 : 0
        let formatsInBuffer = fields1.count > 4 ? Int(fields1[4]) ?? 0 : 0
        let isBufferFull = fields1.count > 5 && fields1[5] == "1"
        let isPartialFormat = fields1.count > 7 && fields1[7] == "1"

        // Temperature range is a binary-encoded field
        // Bit 0 = Under temp, Bit 1 = Over temp
        let tempRange = fields1.count > 10 ? Int(fields1[10]) ?? 0 : 0
        let isHeadCold = (tempRange & 0x01) != 0
        let isHeadTooHot = (tempRange & 0x02) != 0

        // Extract fields from string 2
        // Index: 0=function settings, 1=head up, 2=ribbon out, 3=thermal transfer,
        //        4=print mode, 5=print width, 6=label waiting, 7=labels remaining
        let isHeadOpen = fields2.count > 1 && fields2[1] == "1"
        let isRibbonOut = fields2.count > 2 && fields2[2] == "1"
        let isThermalTransfer: Bool? = fields2.count > 3 ? fields2[3] == "1" : nil
        let labelsRemaining = fields2.count > 7 ? Int(fields2[7]) ?? 0 : 0

        return PrinterStatus(
            isPaperOut: isPaperOut,
            isRibbonOut: isRibbonOut,
            isHeadOpen: isHeadOpen,
            isHeadTooHot: isHeadTooHot,
            isHeadCold: isHeadCold,
            isPaused: isPaused,
            isReceiveBufferFull: isBufferFull,
            isPartialFormatInProgress: isPartialFormat,
            formatsInBuffer: formatsInBuffer,
            labelsRemainingInBatch: labelsRemaining,
            labelLengthInDots: labelLength,
            isThermalTransfer: isThermalTransfer
        )
    }

    /// Extracts content strings from STX/ETX framed response data.
    ///
    /// Each string in the response is wrapped: `<STX>content<ETX><CR><LF>`
    private static func extractStrings(from data: Data) -> [String] {
        // Normalize to a 0-based byte array. `Data`'s subscript is relative to
        // `startIndex`, which is not guaranteed to be 0 for a slice, so indexing
        // the original Data with enumerated offsets would read the wrong bytes.
        let bytes = [UInt8](data)
        var strings: [String] = []
        var currentStart: Int?

        for (index, byte) in bytes.enumerated() {
            if byte == ControlChar.stx {
                currentStart = index + 1  // Start after STX
            } else if byte == ControlChar.etx, let start = currentStart {
                // Extract content between STX and ETX
                if start < index {
                    let content = bytes[start..<index]
                    if let str = String(bytes: content, encoding: .utf8) {
                        strings.append(str)
                    }
                }
                currentStart = nil
            }
        }

        return strings
    }
}

// MARK: - CustomStringConvertible

extension PrinterStatus: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []

        if isReadyToPrint {
            parts.append("Ready")
        } else {
            if isPaperOut { parts.append("Paper Out") }
            if isRibbonOut { parts.append("Ribbon Out") }
            if isHeadOpen { parts.append("Head Open") }
            if isHeadTooHot { parts.append("Head Too Hot") }
            if isHeadCold { parts.append("Head Cold") }
            if isPaused { parts.append("Paused") }
            if isReceiveBufferFull { parts.append("Buffer Full") }
        }

        if formatsInBuffer > 0 {
            parts.append("\(formatsInBuffer) format(s) in buffer")
        }
        if labelsRemainingInBatch > 0 {
            parts.append("\(labelsRemainingInBatch) label(s) remaining")
        }

        return parts.isEmpty ? "Unknown" : parts.joined(separator: ", ")
    }
}
