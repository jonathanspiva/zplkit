import Foundation
import Testing
@testable import ZPLKitPrinter

/// Parser tests that run against **real, captured responses from physical Zebra
/// printers**, committed as fixtures under `Fixtures/RealDevice/`.
///
/// Unlike the synthetic fixtures in `ResponseParsingTests`, every byte here was
/// produced by an actual printer at the firmware noted in the file name. These
/// tests run in CI with no hardware attached, so they continuously verify that
/// our `~HI` / `~HS` / `~HM` / `^HH` parsers handle the exact bytes these
/// devices emit.
///
/// Captured 2026-06-09 from the lab printers:
///   - ZM400-200dpi,  firmware **V53.17.24Z** (thermal-transfer / ribbon)
///   - GX420t-200dpi, firmware **V56.17.17Z** (direct-thermal)
///
/// See `Fixtures/RealDevice/README.md` and `HARDWARE-VALIDATION.md` for the full
/// provenance and the live-hardware test matrix.
@Suite("Real-device response fixtures")
struct RealDeviceFixtureTests {

    /// Loads a captured response fixture as raw `Data` (exact printer bytes,
    /// including STX/ETX framing).
    static func fixture(_ name: String, _ ext: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "RealDevice"),
            "missing fixture \(name).\(ext)"
        )
        return try Data(contentsOf: url)
    }

    // MARK: - ZM400-200dpi, firmware V53.17.24Z (thermal-transfer)

    @Test("ZM400 V53.17.24Z ~HI parses model/firmware/dpi/memory")
    func zm400Info() throws {
        let info = try PrinterInfo.parse(from: Self.fixture("zm400_V53.17.24Z_HI", "bin"))
        #expect(info.model == "ZM400-200dpi")
        #expect(info.firmwareVersion == "V53.17.24Z")
        #expect(info.dotsPerMillimeter == 8)
        #expect(info.dpi == 203)
        #expect(info.memoryKB == 10840)
    }

    @Test("ZM400 V53.17.24Z ~HM parses memory totals")
    func zm400Memory() throws {
        let mem = try MemoryStatus.parse(from: Self.fixture("zm400_V53.17.24Z_HM", "bin"))
        #expect(mem.total == 10840)
        #expect(mem.maximum == 10742)
        #expect(mem.available == 10742)
        #expect(mem.used == 98)
        #expect(mem.usagePercent >= 0 && mem.usagePercent <= 100)
    }

    @Test("ZM400 V53.17.24Z ~HS parses status (not paused, 420-dot label)")
    func zm400Status() throws {
        let status = try PrinterStatus.parse(from: Self.fixture("zm400_V53.17.24Z_HS", "bin"))
        #expect(status.isPaperOut == false)
        #expect(status.isPaused == false)
        #expect(status.labelLengthInDots == 420)
    }

    @Test("ZM400 V53.17.24Z ^HH parses settings (darkness/speed/width/method/firmware)")
    func zm400Settings() throws {
        let s = try PrinterSettings.parse(from: Self.fixture("zm400_V53.17.24Z_HH", "txt"))
        #expect(s.darkness == 30)
        #expect(s.printSpeed == 2)
        #expect(s.printWidthDots == 812)
        #expect(s.mediaType == .thermalTransfer)   // "THERMAL-TRANS." PRINT METHOD
        #expect(s.firmware?.contains("V53.17.24Z") == true)
    }

    // MARK: - GX420t-200dpi, firmware V56.17.17Z (direct-thermal)

    @Test("GX420t V56.17.17Z ~HI parses model/firmware/dpi/memory")
    func gx420tInfo() throws {
        let info = try PrinterInfo.parse(from: Self.fixture("gx420t_V56.17.17Z_HI", "bin"))
        #expect(info.model == "GX420t-200dpi")
        #expect(info.firmwareVersion == "V56.17.17Z")
        #expect(info.dotsPerMillimeter == 8)
        #expect(info.dpi == 203)
        #expect(info.memoryKB == 2104)
    }

    @Test("GX420t V56.17.17Z ~HM parses memory totals")
    func gx420tMemory() throws {
        let mem = try MemoryStatus.parse(from: Self.fixture("gx420t_V56.17.17Z_HM", "bin"))
        #expect(mem.total == 2104)
        #expect(mem.maximum == 2006)
        #expect(mem.available == 2006)
        #expect(mem.used == 98)
    }

    @Test("GX420t V56.17.17Z ~HS parses status (paused, 418-dot label)")
    func gx420tStatus() throws {
        let status = try PrinterStatus.parse(from: Self.fixture("gx420t_V56.17.17Z_HS", "bin"))
        #expect(status.isPaperOut == false)
        // This printer was left paused at capture time; the parser reflects it.
        #expect(status.isPaused == true)
        #expect(status.labelLengthInDots == 418)
    }

    @Test("GX420t V56.17.17Z ^HH parses settings (darkness/speed/width/method/serial/firmware)")
    func gx420tSettings() throws {
        let s = try PrinterSettings.parse(from: Self.fixture("gx420t_V56.17.17Z_HH", "txt"))
        #expect(s.darkness == 15)
        #expect(s.printSpeed == 4)
        #expect(s.printWidthDots == 816)
        #expect(s.mediaType == .directThermal)      // "DIRECT-THERMAL" PRINT METHOD
        #expect(s.serialNumber == "31J114702349")
        #expect(s.firmware?.contains("V56.17.17Z") == true)
    }

    // MARK: - Cross-cutting

    @Test("Every captured response parses without throwing")
    func allFixturesParse() throws {
        // ~HI / ~HM / ~HS / ^HH for both printers must all parse cleanly.
        _ = try PrinterInfo.parse(from: Self.fixture("zm400_V53.17.24Z_HI", "bin"))
        _ = try PrinterInfo.parse(from: Self.fixture("gx420t_V56.17.17Z_HI", "bin"))
        _ = try MemoryStatus.parse(from: Self.fixture("zm400_V53.17.24Z_HM", "bin"))
        _ = try MemoryStatus.parse(from: Self.fixture("gx420t_V56.17.17Z_HM", "bin"))
        _ = try PrinterStatus.parse(from: Self.fixture("zm400_V53.17.24Z_HS", "bin"))
        _ = try PrinterStatus.parse(from: Self.fixture("gx420t_V56.17.17Z_HS", "bin"))
        _ = try PrinterSettings.parse(from: Self.fixture("zm400_V53.17.24Z_HH", "txt"))
        _ = try PrinterSettings.parse(from: Self.fixture("gx420t_V56.17.17Z_HH", "txt"))
    }
}
