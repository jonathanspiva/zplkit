import Foundation
import Testing
@testable import ZPLKitPrinter

/// Direct unit tests for the printer's pure response-parsing logic.
///
/// These parsers consume UNTRUSTED bytes from the network, so this suite
/// focuses on (a) capturing current happy-path behavior by constructing exact
/// `~HS` / `~HI` / `~HM` / `^HH` response fixtures, and (b) pinning the
/// just-added security hardening: hostile/edge inputs must throw a
/// `PrinterError` or clamp gracefully, never trap.
///
/// No real captured byte fixtures exist in the repo (the live tool
/// `Tools/PrinterTests` exercises printers over the wire but does not record
/// payloads). All fixtures here are synthesized directly from each parser's
/// documented framing and field layout (the doc comments in the source files).
@Suite("Printer Response Parsing")
struct ResponseParsingTests {

    // MARK: - Framing helpers

    /// ASCII control bytes used in ZPL responses.
    private static let stx: UInt8 = 0x02
    private static let etx: UInt8 = 0x03
    private static let cr: UInt8 = 0x0D
    private static let lf: UInt8 = 0x0A

    /// Wraps a single content string in `<STX>content<ETX><CR><LF>`.
    private func frame(_ content: String) -> Data {
        var data = Data()
        data.append(Self.stx)
        data.append(contentsOf: content.utf8)
        data.append(contentsOf: [Self.etx, Self.cr, Self.lf])
        return data
    }

    /// Builds a multi-frame `~HS` response from its component strings.
    private func framedHS(_ strings: String...) -> Data {
        strings.reduce(Data()) { $0 + frame($1) }
    }

    // MARK: - PrinterStatus: happy path

    @Test("~HS well-formed response decodes a ready printer")
    func hsReadyPrinter() throws {
        // string1: comm,paperOut,pause,labelLen,formats,bufFull,commDiag,partial,unused,corrupt,temp,unused
        // string2: func,headUp,ribbonOut,thermal,mode,width,waiting,remaining
        let data = framedHS(
            "000,0,0,1218,000,0,0,0,000,0,0,0",
            "0,0,0,1,0,0,0,0000",
            "1234,0"
        )

        let status = try PrinterStatus.parse(from: data)

        #expect(status.isPaperOut == false)
        #expect(status.isPaused == false)
        #expect(status.isHeadOpen == false)
        #expect(status.isRibbonOut == false)
        #expect(status.isReceiveBufferFull == false)
        #expect(status.isHeadTooHot == false)
        #expect(status.isHeadCold == false)
        #expect(status.labelLengthInDots == 1218)
        #expect(status.formatsInBuffer == 0)
        #expect(status.isThermalTransfer == true)
        #expect(status.isReadyToPrint == true)
        #expect(status.hasError == false)
    }

    @Test("~HS distinct flag combos decode independently")
    func hsFlagCombos() throws {
        // Paper out + paused, head/temp ok.
        let paperOutPaused = try PrinterStatus.parse(from: framedHS(
            "000,1,1,0799,000,0,0,0,000,0,0,0",
            "0,0,0,1,0,0,0,0000"
        ))
        #expect(paperOutPaused.isPaperOut == true)
        #expect(paperOutPaused.isPaused == true)
        #expect(paperOutPaused.isReadyToPrint == false)
        #expect(paperOutPaused.hasError == true)

        // Not paused, paper ok, but head open + ribbon out + over-temp.
        let headRibbonHot = try PrinterStatus.parse(from: framedHS(
            "000,0,0,0799,000,0,0,0,000,0,2,0",  // temp=2 over-temp
            "0,1,1,1,0,0,0,0000"                  // headUp=1, ribbonOut=1
        ))
        #expect(headRibbonHot.isPaperOut == false)
        #expect(headRibbonHot.isPaused == false)
        #expect(headRibbonHot.isHeadOpen == true)
        #expect(headRibbonHot.isRibbonOut == true)
        #expect(headRibbonHot.isHeadTooHot == true)
        #expect(headRibbonHot.isReadyToPrint == false)
        #expect(headRibbonHot.hasError == true)
    }

    @Test("~HS temperature field is bit-decoded (under vs over)")
    func hsTemperatureBits() throws {
        let cold = try PrinterStatus.parse(from: framedHS(
            "000,0,0,0799,000,0,0,0,000,0,1,0",  // temp bit0 = under
            "0,0,0,1,0,0,0,0000"
        ))
        #expect(cold.isHeadCold == true)
        #expect(cold.isHeadTooHot == false)
        // Head cold is a warning, not a print-blocking error.
        #expect(cold.hasError == false)

        let both = try PrinterStatus.parse(from: framedHS(
            "000,0,0,0799,000,0,0,0,000,0,3,0",  // bits 0+1 set
            "0,0,0,1,0,0,0,0000"
        ))
        #expect(both.isHeadCold == true)
        #expect(both.isHeadTooHot == true)
    }

    @Test("~HS batch counters decode from leading-zero fields")
    func hsBatchCounters() throws {
        let status = try PrinterStatus.parse(from: framedHS(
            "000,0,0,0799,007,0,0,0,000,0,0,0",  // formats=007
            "0,0,0,1,0,0,0,0099"                  // remaining=0099
        ))
        #expect(status.formatsInBuffer == 7)
        #expect(status.labelsRemainingInBatch == 99)
    }

    // MARK: - PrinterStatus: hostile / edge

    @Test("~HS single frame throws (needs >= 2 strings)")
    func hsSingleFrameThrows() {
        let data = frame("000,0,0,0799,000,0,0,0,000,0,0,0")
        #expect(throws: PrinterError.self) {
            _ = try PrinterStatus.parse(from: data)
        }
    }

    @Test("~HS empty input throws, does not trap")
    func hsEmptyThrows() {
        #expect(throws: PrinterError.self) {
            _ = try PrinterStatus.parse(from: Data())
        }
    }

    @Test("~HS missing ETX yields no usable strings and throws")
    func hsMissingETX() {
        // Two STX-opened frames but neither is closed by ETX, so extractStrings
        // collects nothing.
        var data = Data()
        data.append(Self.stx)
        data.append(contentsOf: "000,0,0,0799,000,0,0,0,000,0,0,0".utf8)
        data.append(Self.stx)
        data.append(contentsOf: "0,0,0,1,0,0,0,0000".utf8)
        #expect(throws: PrinterError.self) {
            _ = try PrinterStatus.parse(from: data)
        }
    }

    @Test("~HS truncated trailing frame still parses available strings")
    func hsTruncatedTrailingFrame() throws {
        // Two complete frames plus a third that is cut off mid-STX (no ETX).
        var data = framedHS(
            "000,0,0,0799,000,0,0,0,000,0,0,0",
            "0,0,0,1,0,0,0,0000"
        )
        data.append(Self.stx)
        data.append(contentsOf: "12".utf8)  // truncated, no ETX

        let status = try PrinterStatus.parse(from: data)
        #expect(status.labelLengthInDots == 799)
    }

    @Test("~HS too-few comma fields default safely (no trap)")
    func hsTooFewFields() throws {
        // string1 has only 2 fields, string2 only 1; parser guards each index.
        let status = try PrinterStatus.parse(from: framedHS("000,1", "0"))
        #expect(status.isPaperOut == true)          // index 1 present
        #expect(status.isPaused == false)           // index 2 missing -> default
        #expect(status.labelLengthInDots == 0)      // index 3 missing -> 0
        #expect(status.isHeadOpen == false)         // string2 index 1 missing
        #expect(status.isThermalTransfer == nil)    // string2 index 3 missing
    }

    @Test("~HS non-numeric numeric fields fall back to 0")
    func hsNonNumericFields() throws {
        let status = try PrinterStatus.parse(from: framedHS(
            "000,0,0,NOPE,XXXX,0,0,0,000,0,YY,0",  // labelLen/formats/temp non-numeric
            "0,0,0,1,0,0,0,ZZZZ"                    // remaining non-numeric
        ))
        #expect(status.labelLengthInDots == 0)
        #expect(status.formatsInBuffer == 0)
        #expect(status.isHeadCold == false)
        #expect(status.isHeadTooHot == false)
        #expect(status.labelsRemainingInBatch == 0)
    }

    @Test("~HS empty STX/ETX frame is skipped, leaving too few strings")
    func hsEmptyFrameSkipped() {
        // An empty frame (STX immediately followed by ETX) is not collected,
        // so only one usable string remains -> throws.
        var data = Data([Self.stx, Self.etx, Self.cr, Self.lf])
        data += frame("000,0,0,0799,000,0,0,0,000,0,0,0")
        #expect(throws: PrinterError.self) {
            _ = try PrinterStatus.parse(from: data)
        }
    }

    // MARK: - PrinterInfo: happy path

    @Test("~HI response missing its ETX strips the leading STX in fallback")
    func hiTruncatedFrameStripsSTX() throws {
        // A response whose final ETX was lost (idle-timer partial buffer) falls
        // back to unframed parsing; the leading 0x02 must not leak into the
        // model string.
        var data = Data([0x02])
        data.append(contentsOf: Array("GX420t-203dpi,V56.17.17Z,8,8192KB,NONE".utf8))
        let info = try PrinterInfo.parse(from: data)
        #expect(info.model == "GX420t-203dpi")
    }

    @Test("~HI well-formed response decodes model/firmware/dpm")
    func hiHappyPath() throws {
        let data = frame("ZT410-203dpi,V53.17.14Z,8,49152KB,NONE")
        let info = try PrinterInfo.parse(from: data)
        #expect(info.model == "ZT410-203dpi")
        #expect(info.firmwareVersion == "V53.17.14Z")
        #expect(info.dotsPerMillimeter == 8)
        #expect(info.memoryKB == 49152)
        #expect(info.options.isEmpty)
        #expect(info.dpi == 203)
    }

    @Test(
        "~HI dpi maps standard Zebra resolutions exactly",
        arguments: [
            (6, 150),
            (8, 203),
            (12, 300),
            (24, 600),
        ]
    )
    func hiStandardDPI(dpm: Int, expectedDPI: Int) throws {
        let data = frame("MODEL,V1,\(dpm),1024KB,NONE")
        let info = try PrinterInfo.parse(from: data)
        #expect(info.dotsPerMillimeter == dpm)
        #expect(info.dpi == expectedDPI)
    }

    @Test("~HI dpi rounds non-standard dpm (10 -> 254)")
    func hiNonStandardDPIRounds() throws {
        // 10 dpmm is not in the lookup table: 10 * 25.4 = 254.0 -> 254.
        let info = try PrinterInfo.parse(from: frame("MODEL,V1,10,1024KB,NONE"))
        #expect(info.dpi == 254)
    }

    @Test("~HI parses installed options list")
    func hiOptions() throws {
        let info = try PrinterInfo.parse(from: frame("ZT410-203dpi,V1,8,49152KB,CUTTER,REWIND"))
        #expect(info.options == ["CUTTER", "REWIND"])
    }

    @Test("~HI memory KB suffix is stripped")
    func hiMemorySuffix() throws {
        #expect(try PrinterInfo.parse(from: frame("M,V1,8,9984KB,NONE")).memoryKB == 9984)
        // lowercase suffix is also handled
        #expect(try PrinterInfo.parse(from: frame("M,V1,8,2048kb,NONE")).memoryKB == 2048)
    }

    // MARK: - PrinterInfo: hostile / edge

    @Test("~HI too few fields throws")
    func hiTooFewFields() {
        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: frame("ZT410,V1,8"))
        }
    }

    @Test("~HI non-numeric dpm throws")
    func hiNonNumericDPM() {
        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: frame("M,V1,nope,1024KB,NONE"))
        }
    }

    @Test("~HI out-of-range dpm (hostile) throws instead of trapping")
    func hiHostileDPM() {
        // Huge value would have trapped the Int(Double) conversion in `dpi`.
        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: frame("EVIL,V1,999999999999,1KB,NONE"))
        }
        // Negative dpm rejected.
        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: frame("EVIL,V1,-5,1KB,NONE"))
        }
        // Zero dpm rejected (range is 1...100).
        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: frame("EVIL,V1,0,1KB,NONE"))
        }
    }

    @Test("~HI non-numeric memory throws")
    func hiNonNumericMemory() {
        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: frame("M,V1,8,lots,NONE"))
        }
    }

    @Test("~HI empty input throws")
    func hiEmptyInput() {
        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: Data())
        }
    }

    @Test("PrinterInfo.dpi and .description never trap on hostile dpm")
    func infoDPINoTrap() {
        // Constructed directly to bypass parse's range guard.
        for dpm in [Int.max, Int.min, 0, -1, 1, 100, 101] {
            let info = PrinterInfo(model: "X", firmwareVersion: "V1", dotsPerMillimeter: dpm, memoryKB: 1)
            let dpi = info.dpi
            #expect(dpi >= 0)                 // never negative / trapped
            _ = info.description              // reads dpi; must not crash
        }
    }

    // MARK: - MemoryStatus: happy path

    @Test("~HM well-formed response decodes total/max/available/used")
    func hmHappyPath() throws {
        let memory = try MemoryStatus.parse(from: frame("2097152,2097152,1847296"))
        #expect(memory.total == 2097152)
        #expect(memory.maximum == 2097152)
        #expect(memory.available == 1847296)
        #expect(memory.used == 2097152 - 1847296)
    }

    @Test("~HM usagePercent computed from used/total")
    func hmUsagePercent() throws {
        // 1000 total, 250 free -> 750 used -> 75%.
        let memory = try MemoryStatus.parse(from: frame("1000,1000,250"))
        #expect(memory.used == 750)
        #expect(memory.usagePercent == 75)
    }

    @Test("~HM full == empty boundaries")
    func hmBoundaries() throws {
        let empty = try MemoryStatus.parse(from: frame("1000,1000,1000"))  // all free
        #expect(empty.used == 0)
        #expect(empty.usagePercent == 0)

        let full = try MemoryStatus.parse(from: frame("1000,1000,0"))       // none free
        #expect(full.used == 1000)
        #expect(full.usagePercent == 100)
    }

    @Test("~HM parses without STX/ETX framing (fallback path)")
    func hmNoFraming() throws {
        let memory = try MemoryStatus.parse(from: Data("4096,4096,1024".utf8))
        #expect(memory.total == 4096)
        #expect(memory.available == 1024)
        #expect(memory.used == 3072)
    }

    // MARK: - MemoryStatus: hostile / edge

    @Test("~HM too few fields throws")
    func hmTooFewFields() {
        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: frame("1000,1000"))
        }
    }

    @Test("~HM non-numeric field throws")
    func hmNonNumeric() {
        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: frame("1000,oops,500"))
        }
    }

    @Test("~HM negative values (hostile) throw")
    func hmNegativeValues() {
        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: frame("-1,1000,500"))
        }
        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: frame("1000,-1,500"))
        }
        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: frame("1000,1000,-5"))
        }
    }

    @Test("~HM available > total (hostile) throws")
    func hmAvailableExceedsTotal() {
        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: frame("1000,1000,5000"))
        }
    }

    @Test("~HM empty input throws")
    func hmEmptyInput() {
        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: Data())
        }
    }

    @Test("MemoryStatus computed properties never trap on extreme values")
    func memoryNoTrap() {
        // Constructed directly to bypass parse validation.
        let inverted = MemoryStatus(total: 1, maximum: 1, available: Int.max)
        #expect(inverted.used == 0)              // saturating subtraction clamps
        #expect(inverted.usagePercent == 0)
        _ = inverted.description

        let overflow = MemoryStatus(total: Int.max, maximum: Int.max, available: Int.min)
        _ = overflow.used                         // overflow -> 0, no trap
        let pct = overflow.usagePercent
        #expect((0...100).contains(pct))
        _ = overflow.description

        let zeroTotal = MemoryStatus(total: 0, maximum: 0, available: 0)
        #expect(zeroTotal.used == 0)
        #expect(zeroTotal.usagePercent == 0)      // guard total > 0
        _ = zeroTotal.description
    }

    // MARK: - PrinterSettings: ^HH parsing (pure text)

    @Test("^HH parses core fields from a ZM400 dump")
    func hhZM400() {
        let text = """
          50J000000001        SERIAL NUMBER
          +15                 DARKNESS
          2 IPS               PRINT SPEED
          +000                TEAR OFF
          TEAR OFF            PRINT MODE
          GAP/NOTCH           MEDIA TYPE
          THERMAL-TRANS.      PRINT METHOD
          812                 PRINT WIDTH
          0419                LABEL LENGTH
          39.0IN   988MM      MAXIMUM LENGTH
          V53.17.24Z <-       FIRMWARE
          111,367 IN          NONRESET CNTR
        """
        let s = PrinterSettings.parse(from: text)
        #expect(s.serialNumber == "50J000000001")
        #expect(s.darkness == 15)
        #expect(s.printSpeed == 2)
        #expect(s.tearOffAdjust == 0)
        #expect(s.printMode == .tearOff)
        #expect(s.mediaTracking == .gap)
        #expect(s.mediaType == .thermalTransfer)
        #expect(s.printWidthDots == 812)
        #expect(s.labelLengthDots == 419)
        #expect(s.maximumLengthInches == 39.0)
        #expect(s.firmware == "V53.17.24Z")
        #expect(s.nonresetCounterInches == 111367)
    }

    @Test("^HH parse(from: Data) rejects invalid UTF-8")
    func hhInvalidUTF8() {
        let data = Data([0xFF, 0xFE, 0x00, 0x01])
        #expect(throws: PrinterError.self) {
            _ = try PrinterSettings.parse(from: data)
        }
    }

    @Test("^HH unrecognized text yields all-nil settings (no trap)")
    func hhUnrecognized() {
        let s = PrinterSettings.parse(from: "garbage line one\nrandom\n\n")
        #expect(s.darkness == nil)
        #expect(s.printSpeed == nil)
        #expect(s.mediaType == nil)
        #expect(s.description == "No settings parsed")
    }

    @Test("^HH empty input yields empty settings")
    func hhEmpty() {
        let s = PrinterSettings.parse(from: "")
        #expect(s == PrinterSettings())
    }

    // MARK: - PrinterDiagnostics: pure assembly / formatting

    /// Builds a representative diagnostics struct for formatting assertions.
    private func sampleDiagnostics(settings: PrinterSettings? = nil) -> PrinterDiagnostics {
        let info = PrinterInfo(
            model: "ZT410-203dpi",
            firmwareVersion: "V53.17.14Z",
            dotsPerMillimeter: 8,
            memoryKB: 49152
        )
        let status = PrinterStatus()  // ready, no errors
        let memory = MemoryStatus(total: 2_097_152, maximum: 2_097_152, available: 1_048_576)
        return PrinterDiagnostics(info: info, status: status, memory: memory, settings: settings)
    }

    @Test("PrinterDiagnostics convenience accessors read from settings")
    func diagnosticsAccessors() {
        var settings = PrinterSettings()
        settings.serialNumber = "ABC123"
        settings.nonresetCounterInches = 5000

        let diag = sampleDiagnostics(settings: settings)
        #expect(diag.serialNumber == "ABC123")
        #expect(diag.lifetimeUsageInches == 5000)
        #expect(diag.isReadyToPrint == true)
    }

    @Test("PrinterDiagnostics accessors are nil when settings absent")
    func diagnosticsNilSettings() {
        let diag = sampleDiagnostics(settings: nil)
        #expect(diag.serialNumber == nil)
        #expect(diag.lifetimeUsageInches == nil)
    }

    @Test("PrinterDiagnostics.description assembles core fields")
    func diagnosticsDescriptionCore() {
        let diag = sampleDiagnostics(settings: nil)
        let desc = diag.description
        #expect(desc.contains("model: ZT410-203dpi"))
        #expect(desc.contains("firmware: V53.17.14Z"))
        #expect(desc.contains("dpi: 203"))
        #expect(desc.contains("memory: 1MB free of 2MB"))
        #expect(desc.contains("ready: true"))
        // No settings -> no serial/lifetime lines.
        #expect(!desc.contains("serial:"))
        #expect(!desc.contains("lifetime_usage:"))
    }

    @Test("PrinterDiagnostics.description includes optional settings lines")
    func diagnosticsDescriptionWithSettings() {
        var settings = PrinterSettings()
        settings.serialNumber = "50J000000001"
        settings.firmware = "V53.17.24Z"
        settings.nonresetCounterInches = 111_367
        settings.resetCounterInches = 50_234
        settings.lastCleanedInches = 200
        settings.maximumLengthInches = 39.0

        let diag = sampleDiagnostics(settings: settings)
        let desc = diag.description
        #expect(desc.contains("serial: 50J000000001"))
        #expect(desc.contains("config_firmware: V53.17.24Z"))
        #expect(desc.contains("lifetime_usage: 111367 in"))
        #expect(desc.contains("head_usage: 50234 in"))
        #expect(desc.contains("last_cleaned: 200 in"))
        #expect(desc.contains("max_length: 39.0 in"))
    }

    @Test("PrinterDiagnostics.description surfaces error status")
    func diagnosticsDescriptionError() {
        let info = PrinterInfo(model: "M", firmwareVersion: "V1", dotsPerMillimeter: 8, memoryKB: 1024)
        let status = PrinterStatus(isPaperOut: true)
        let memory = MemoryStatus(total: 1024, maximum: 1024, available: 512)
        let diag = PrinterDiagnostics(info: info, status: status, memory: memory)

        let desc = diag.description
        #expect(desc.contains("ready: false"))
        #expect(desc.contains("errors:"))
        #expect(desc.contains("Paper Out"))
    }
}
