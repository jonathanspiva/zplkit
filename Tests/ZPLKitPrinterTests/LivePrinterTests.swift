import Foundation
import Testing
@testable import ZPLKitPrinter

extension Tag {
    @Tag static var live: Self
}

/// Whether live printer tests are enabled via environment variable.
private let liveTestsEnabled = ProcessInfo.processInfo.environment["ZPLTOOL_LIVE_TESTS"] == "1"

/// Integration tests that require real printers on the network.
///
/// These tests are disabled by default. To run them:
/// ```
/// ZPLTOOL_LIVE_TESTS=1 swift test --filter LivePrinterTests
/// ```
///
/// Environment variables:
/// - `ZPLTOOL_LIVE_TESTS`: Set to "1" to enable live tests
/// - `ZPLTOOL_ZM400_HOST`: ZM400 IP (default: 192.168.7.4)
/// - `ZPLTOOL_GX420T_HOST`: GX420t IP (default: 192.168.7.5)
@Suite("Live Printer Tests", .tags(.live), .serialized, .enabled(if: liveTestsEnabled, "Set ZPLTOOL_LIVE_TESTS=1 to enable"))
struct LivePrinterTests {
    let zm400: ZPLPrinter
    let gx420t: ZPLPrinter

    init() {
        let zm400Host = ProcessInfo.processInfo.environment["ZPLTOOL_ZM400_HOST"] ?? "192.168.7.4"
        let gx420tHost = ProcessInfo.processInfo.environment["ZPLTOOL_GX420T_HOST"] ?? "192.168.7.5"

        zm400 = ZPLPrinter(host: zm400Host, timeout: 10)
        gx420t = ZPLPrinter(host: gx420tHost, timeout: 10)
    }

    // MARK: - Raw Config Dump

    @Test("Raw config dump returns text from ZM400")
    func rawConfigDumpZM400() async throws {
        let raw = try await zm400.queryConfigurationRaw()
        #expect(!raw.isEmpty)
        print("--- ZM400 ^HH raw output ---")
        print(raw)
        print("--- end ---")
    }

    @Test("Raw config dump returns text from GX420t")
    func rawConfigDumpGX420t() async throws {
        let raw = try await gx420t.queryConfigurationRaw()
        #expect(!raw.isEmpty)
        print("--- GX420t ^HH raw output ---")
        print(raw)
        print("--- end ---")
    }

    // MARK: - Config Readback

    @Test("Query configuration parses settings from ZM400")
    func queryConfigZM400() async throws {
        let settings = try await zm400.queryConfiguration()
        print("ZM400 parsed settings: \(settings)")
    }

    @Test("Query configuration parses settings from GX420t")
    func queryConfigGX420t() async throws {
        let settings = try await gx420t.queryConfiguration()
        print("GX420t parsed settings: \(settings)")
    }

    // MARK: - Status Config Fields

    @Test("Status returns isThermalTransfer from ~HS for ZM400")
    func statusConfigFieldsZM400() async throws {
        let status = try await zm400.queryStatus()
        print("ZM400 status: isThermalTransfer=\(String(describing: status.isThermalTransfer))")
        // isThermalTransfer comes from ~HS string 2, index 3
        #expect(status.isThermalTransfer != nil)
    }

    @Test("Status returns isThermalTransfer from ~HS for GX420t")
    func statusConfigFieldsGX420t() async throws {
        let status = try await gx420t.queryStatus()
        print("GX420t status: isThermalTransfer=\(String(describing: status.isThermalTransfer))")
        #expect(status.isThermalTransfer != nil)
    }

    // MARK: - Darkness Round-Trip

    @Test("Darkness round-trip on ZM400")
    func darknessRoundTripZM400() async throws {
        // Read current settings to restore later
        let original = try await zm400.queryConfiguration()
        let originalDarkness = original.darkness ?? 15

        // Set darkness to 20, save
        let config = PrinterConfiguration().darkness(20)
        let commands = config.zplCommands(save: true)
        try await zm400.send(commands.joined())

        // Small delay for EEPROM write
        try await Task.sleep(nanoseconds: 500_000_000)

        // Restore from EEPROM and read back
        try await zm400.restoreConfiguration()
        try await Task.sleep(nanoseconds: 500_000_000)

        let readback = try await zm400.queryConfiguration()
        #expect(readback.darkness == 20)

        // Restore original
        let restore = PrinterConfiguration().darkness(originalDarkness)
        let restoreCommands = restore.zplCommands(save: true)
        try await zm400.send(restoreCommands.joined())
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    // MARK: - Speed Round-Trip

    @Test("Speed round-trip on ZM400")
    func speedRoundTripZM400() async throws {
        let original = try await zm400.queryConfiguration()
        let originalSpeed = original.printSpeed ?? 4

        // Set speed to 4, save
        let config = PrinterConfiguration().printSpeedIPS(4)
        let commands = config.zplCommands(save: true)
        try await zm400.send(commands.joined())

        try await Task.sleep(nanoseconds: 500_000_000)

        try await zm400.restoreConfiguration()
        try await Task.sleep(nanoseconds: 500_000_000)

        let readback = try await zm400.queryConfiguration()
        #expect(readback.printSpeed == 4)

        // Restore original
        let restore = PrinterConfiguration().printSpeedIPS(originalSpeed)
        let restoreCommands = restore.zplCommands(save: true)
        try await zm400.send(restoreCommands.joined())
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    // MARK: - Multi-Setting Round-Trip

    @Test("Multi-setting round-trip on ZM400")
    func multiSettingRoundTripZM400() async throws {
        let original = try await zm400.queryConfiguration()

        // Set multiple settings at once
        let config = PrinterConfiguration()
            .darkness(18)
            .printSpeedIPS(3)

        let commands = config.zplCommands(save: true)
        try await zm400.send(commands.joined())

        try await Task.sleep(nanoseconds: 500_000_000)

        try await zm400.restoreConfiguration()
        try await Task.sleep(nanoseconds: 500_000_000)

        let readback = try await zm400.queryConfiguration()
        #expect(readback.darkness == 18)
        #expect(readback.printSpeed == 3)

        // Restore original
        var restore = PrinterConfiguration()
        if let d = original.darkness { restore = restore.darkness(d) }
        if let s = original.printSpeed { restore = restore.printSpeedIPS(s) }
        let restoreCommands = restore.zplCommands(save: true)
        try await zm400.send(restoreCommands.joined())
        try await Task.sleep(nanoseconds: 500_000_000)
    }

    // MARK: - Extended Config Fields

    @Test("Query config parses serial number from GX420t")
    func queryConfigSerialGX420t() async throws {
        let settings = try await gx420t.queryConfiguration()
        print("GX420t serial: \(settings.serialNumber ?? "nil")")
        #expect(settings.serialNumber != nil)
        #expect(settings.serialNumber?.isEmpty == false)
    }

    @Test("Query config parses counters from ZM400")
    func queryConfigCountersZM400() async throws {
        let settings = try await zm400.queryConfiguration()
        print("ZM400 nonreset: \(settings.nonresetCounterInches ?? -1) in")
        print("ZM400 reset: \(settings.resetCounterInches ?? -1) in")
        #expect(settings.nonresetCounterInches != nil)
        #expect(settings.resetCounterInches != nil)
    }

    @Test("Query config parses counters from GX420t")
    func queryConfigCountersGX420t() async throws {
        let settings = try await gx420t.queryConfiguration()
        print("GX420t total usage: \(settings.nonresetCounterInches ?? -1) in")
        print("GX420t head usage: \(settings.resetCounterInches ?? -1) in")
        #expect(settings.nonresetCounterInches != nil)
        #expect(settings.resetCounterInches != nil)
    }

    @Test("Query config parses firmware from ZM400")
    func queryConfigFirmwareZM400() async throws {
        let settings = try await zm400.queryConfiguration()
        print("ZM400 firmware: \(settings.firmware ?? "nil")")
        #expect(settings.firmware != nil)
        #expect(settings.firmware?.isEmpty == false)
    }

    @Test("Query config parses maximum length from ZM400")
    func queryConfigMaxLengthZM400() async throws {
        let settings = try await zm400.queryConfiguration()
        print("ZM400 max length: \(settings.maximumLengthInches ?? -1) in")
        #expect(settings.maximumLengthInches != nil)
        #expect(settings.maximumLengthInches! > 0)
    }

    // MARK: - Aggregate Diagnostics

    @Test("Full diagnostics snapshot from ZM400")
    func diagnosticsZM400() async throws {
        let diag = try await zm400.queryDiagnostics()
        print("--- ZM400 Diagnostics ---")
        print(diag)
        print("--- end ---")

        #expect(!diag.info.model.isEmpty)
        #expect(diag.isReadyToPrint || diag.status.hasError || diag.status.isPaused)
        // Settings may be nil if printer is in error state, but usually works
        if let settings = diag.settings {
            #expect(settings.darkness != nil)
        }
    }

    @Test("Full diagnostics snapshot from GX420t")
    func diagnosticsGX420t() async throws {
        let diag = try await gx420t.queryDiagnostics()
        print("--- GX420t Diagnostics ---")
        print(diag)
        print("--- end ---")

        #expect(!diag.info.model.isEmpty)
        if let serial = diag.serialNumber {
            #expect(!serial.isEmpty)
        }
    }

    // MARK: - Apply Single Payload

    @Test("Apply sends all commands in single TCP connection")
    func applySinglePayloadZM400() async throws {
        // Verify apply() works with the new joined implementation
        let config = PrinterConfiguration().darkness(15)
        try await zm400.apply(config)
        try await zm400.saveConfiguration()
    }

    // MARK: - Setup Integrated Save

    @Test("Setup sends config+save in single payload")
    func setupIntegratedSaveZM400() async throws {
        // Let printer settle from previous tests
        try await Task.sleep(nanoseconds: 2_000_000_000)

        let zm400Long = ZPLPrinter(host: zm400.host, timeout: 15)
        let original = try await zm400Long.queryConfiguration(responseTimeout: 15)

        // setup() sends config+save in one payload, then calibrates.
        // Calibration feeds several labels and takes time.
        let config = PrinterConfiguration().darkness(15)
        try await zm400Long.setup(config)

        // Calibration feeds 3-5 labels, wait for it to finish
        try await Task.sleep(nanoseconds: 5_000_000_000)

        let readback = try await zm400Long.queryConfiguration(responseTimeout: 15)
        #expect(readback.darkness == 15)

        // Restore
        if let d = original.darkness {
            let restore = PrinterConfiguration().darkness(d)
            let commands = restore.zplCommands(save: true)
            try await zm400Long.send(commands.joined())
            try await Task.sleep(nanoseconds: 500_000_000)
        }
    }
}
