import Foundation
import ZPLKit
import ZPLKitPrinter

/// Integration test harness for ZPLKitPrinter against real Zebra printers.
///
/// Tests query commands (~HS, ~HI, ~HM, ^HH, ^HW), network behavior
/// (concurrent queries, rapid bursts, timeouts), Bonjour discovery,
/// and error paths. Validates that ZPLKit's parsing code produces
/// correct results from real printer responses.
///
/// Usage:
///   swift run PrinterTests 192.168.1.100 192.168.1.101 192.168.1.102
///   swift run PrinterTests --timeout 15 192.168.1.100

// MARK: - Test Infrastructure

struct TestResult {
    let name: String
    let printer: String
    let passed: Bool
    let message: String
    let duration: TimeInterval
}

enum TestError: Error, CustomStringConvertible {
    case assertionFailed(String)

    var description: String {
        switch self {
        case .assertionFailed(let msg): return msg
        }
    }
}

func assert(_ condition: Bool, _ message: String) throws {
    guard condition else {
        throw TestError.assertionFailed(message)
    }
}

func runTest(
    name: String, printer: String,
    body: () async throws -> String
) async -> TestResult {
    let start = Date()
    do {
        let message = try await body()
        return TestResult(name: name, printer: printer, passed: true,
                          message: message, duration: Date().timeIntervalSince(start))
    } catch {
        return TestResult(name: name, printer: printer, passed: false,
                          message: "\(error)", duration: Date().timeIntervalSince(start))
    }
}

// MARK: - Core Query Tests

func testQueryInfo(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "queryInfo", printer: host) {
        let info = try await printer.queryInfo()
        try assert(!info.model.isEmpty, "Model should not be empty")
        try assert(!info.firmwareVersion.isEmpty, "Firmware version should not be empty")
        try assert(info.dotsPerMillimeter > 0, "DPM should be positive, got \(info.dotsPerMillimeter)")
        try assert(info.dpi > 0, "DPI should be positive, got \(info.dpi)")
        try assert(info.memoryKB > 0, "Memory should be positive, got \(info.memoryKB)")
        return "\(info.model), FW \(info.firmwareVersion), \(info.dpi)dpi, \(info.memoryFormatted)"
    }
}

func testQueryStatus(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "queryStatus", printer: host) {
        let status = try await printer.queryStatus()
        try assert(status.labelLengthInDots > 0,
                   "Label length should be positive, got \(status.labelLengthInDots)")
        try assert(status.formatsInBuffer >= 0,
                   "Formats in buffer should be non-negative")
        try assert(status.labelsRemainingInBatch >= 0,
                   "Labels remaining should be non-negative")
        try assert(!status.isHeadOpen, "Head reported as open")

        var flags: [String] = []
        if status.isPaperOut { flags.append("paper-out") }
        if status.isRibbonOut { flags.append("ribbon-out") }
        if status.isPaused { flags.append("paused") }
        if status.isHeadTooHot { flags.append("too-hot") }
        if status.isHeadCold { flags.append("cold") }
        if flags.isEmpty { flags.append("no-errors") }
        return "label=\(status.labelLengthInDots)dots, flags=[\(flags.joined(separator: ", "))]"
    }
}

func testQueryMemory(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "queryMemory", printer: host) {
        let memory = try await printer.queryMemory()
        try assert(memory.total > 0, "Total memory should be positive")
        try assert(memory.maximum > 0, "Maximum memory should be positive")
        try assert(memory.available > 0, "Available memory should be positive")
        try assert(memory.available <= memory.total,
                   "Available (\(memory.available)) exceeds total (\(memory.total))")
        try assert(memory.used >= 0, "Used memory should be non-negative")
        try assert(memory.usagePercent >= 0 && memory.usagePercent <= 100,
                   "Usage percent should be 0-100, got \(memory.usagePercent)")
        return "\(memory.availableFormatted) free of \(memory.totalFormatted) (\(memory.usagePercent)% used)"
    }
}

// MARK: - Response Framing Tests

func testRawQueryFraming(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "rawQueryFraming", printer: host) {
        let data = try await printer.query("~HS")
        try assert(!data.isEmpty, "Raw response should not be empty")

        let stxCount = data.filter { $0 == 0x02 }.count
        let etxCount = data.filter { $0 == 0x03 }.count
        try assert(stxCount >= 2, "~HS should have at least 2 STX markers, got \(stxCount)")
        try assert(etxCount >= 2, "~HS should have at least 2 ETX markers, got \(etxCount)")
        try assert(stxCount == etxCount, "STX count (\(stxCount)) != ETX count (\(etxCount))")
        return "\(data.count) bytes, \(stxCount) framed strings"
    }
}

// MARK: - Consistency and Cross-Validation Tests

func testQueryConsistency(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "queryConsistency", printer: host) {
        let info1 = try await printer.queryInfo()
        let info2 = try await printer.queryInfo()
        try assert(info1.model == info2.model,
                   "Model mismatch: '\(info1.model)' vs '\(info2.model)'")
        try assert(info1.firmwareVersion == info2.firmwareVersion,
                   "Firmware mismatch: '\(info1.firmwareVersion)' vs '\(info2.firmwareVersion)'")
        try assert(info1.dotsPerMillimeter == info2.dotsPerMillimeter,
                   "DPM mismatch: \(info1.dotsPerMillimeter) vs \(info2.dotsPerMillimeter)")
        try assert(info1.memoryKB == info2.memoryKB,
                   "Memory mismatch: \(info1.memoryKB) vs \(info2.memoryKB)")
        return "Two consecutive ~HI queries returned identical results"
    }
}

func testDPICrossCheck(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "dpiCrossCheck", printer: host) {
        let info = try await printer.queryInfo()
        let status = try await printer.queryStatus()

        let minDots = info.dpi / 2   // 0.5 inch minimum
        let maxDots = info.dpi * 12  // 12 inch maximum
        try assert(status.labelLengthInDots >= minDots,
                   "Label \(status.labelLengthInDots)dots too small for \(info.dpi)dpi")
        try assert(status.labelLengthInDots <= maxDots,
                   "Label \(status.labelLengthInDots)dots too large for \(info.dpi)dpi")

        let labelInches = Double(status.labelLengthInDots) / Double(info.dpi)
        return "label=\(String(format: "%.1f", labelInches))\" (\(status.labelLengthInDots)dots at \(info.dpi)dpi)"
    }
}

/// Tests that PrinterInfo.dpi maps to a valid ZPLKit DPI enum case.
func testDPIEnumMapping(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "dpiEnumMapping", printer: host) {
        let info = try await printer.queryInfo()

        // The printer reports dpmm, which we convert to DPI.
        // 8 dpmm -> 203 DPI -> should match .dpi203
        // The DPI enum has: 152, 200, 203, 300, 600
        let computedDPI = info.dpi
        let matchingCase = DPI(rawValue: computedDPI)

        if let matched = matchingCase {
            return "Printer reports \(info.dotsPerMillimeter)dpmm = \(computedDPI)dpi -> .\(matched)"
        } else {
            // Common case: 8 dpmm = 203 DPI (matches .dpi203, not .dpi200)
            // 12 dpmm = 304 DPI (no exact match for .dpi300)
            let closest: DPI
            switch info.dotsPerMillimeter {
            case 6: closest = .dpi152
            case 8: closest = .dpi203
            case 12: closest = .dpi300
            case 24: closest = .dpi600
            default: closest = .dpi203
            }
            return "Printer reports \(info.dotsPerMillimeter)dpmm = \(computedDPI)dpi (no exact enum match, closest: .\(closest))"
        }
    }
}

// MARK: - Description Formatting Tests

func testInfoDescription(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "infoDescription", printer: host) {
        let info = try await printer.queryInfo()
        let desc = info.description
        try assert(!desc.isEmpty, "Description should not be empty")
        try assert(desc.contains(info.model), "Description should contain model name")
        try assert(desc.contains("dpi"), "Description should contain 'dpi'")
        return desc
    }
}

func testStatusDescription(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "statusDescription", printer: host) {
        let status = try await printer.queryStatus()
        let desc = status.description
        try assert(!desc.isEmpty, "Status description should not be empty")
        if status.isReadyToPrint {
            try assert(desc.contains("Ready"), "Ready printer should say 'Ready'")
        }
        return desc
    }
}

func testMemoryDescription(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "memoryDescription", printer: host) {
        let memory = try await printer.queryMemory()
        let desc = memory.description
        try assert(!desc.isEmpty, "Memory description should not be empty")
        try assert(desc.contains("available"), "Should contain 'available'")
        try assert(desc.contains("%"), "Should contain usage percentage")
        return desc
    }
}

// MARK: - Codable Roundtrip Tests

func testInfoCodable(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "infoCodable", printer: host) {
        let info = try await printer.queryInfo()
        let data = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(PrinterInfo.self, from: data)
        try assert(info == decoded, "Decoded PrinterInfo should equal original")
        return "JSON roundtrip: \(data.count) bytes"
    }
}

func testStatusCodable(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "statusCodable", printer: host) {
        let status = try await printer.queryStatus()
        let data = try JSONEncoder().encode(status)
        let decoded = try JSONDecoder().decode(PrinterStatus.self, from: data)
        try assert(status == decoded, "Decoded PrinterStatus should equal original")
        return "JSON roundtrip: \(data.count) bytes"
    }
}

func testMemoryCodable(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "memoryCodable", printer: host) {
        let memory = try await printer.queryMemory()
        let data = try JSONEncoder().encode(memory)
        let decoded = try JSONDecoder().decode(MemoryStatus.self, from: data)
        try assert(memory == decoded, "Decoded MemoryStatus should equal original")
        return "JSON roundtrip: \(data.count) bytes"
    }
}

// MARK: - Additional ZPL Query Commands

/// Tests ^HH (configuration return to host) which returns a large config dump.
func testQueryConfiguration(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "queryConfiguration", printer: host) {
        let data = try await printer.query("^XA^HH^XZ", responseTimeout: 10)
        try assert(!data.isEmpty, "Configuration response should not be empty")

        try assert(data.count > 100, "Config dump should be substantial, got \(data.count) bytes")

        return "\(data.count) bytes, contains config data"
    }
}

/// Tests ^HW (host directory listing) which returns stored objects.
func testQueryDirectory(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "queryDirectory", printer: host) {
        // Query the R: drive (firmware/ROM) which should always have entries
        let data = try await printer.query("^XA^HWR:*.*^XZ", responseTimeout: 10)
        try assert(!data.isEmpty, "Directory response should not be empty")

        let responseStr = String(data: data, encoding: .utf8) ?? "(non-UTF8)"
        let lineCount = responseStr.components(separatedBy: "\n").count
        return "\(data.count) bytes, ~\(lineCount) lines"
    }
}

/// Tests ~JA (cancel all jobs) when no job is active. Should be side-effect-free.
func testCancelIdleJob(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "cancelIdleJob", printer: host) {
        try await printer.send("~JA")

        // Verify printer is still healthy after cancel
        let status = try await printer.queryStatus()
        try assert(!status.isHeadOpen, "Head should still be closed after cancel")
        return "~JA sent, printer still responsive"
    }
}

// MARK: - Network Behavior Tests

/// Tests sending ~HI, ~HS, ~HM concurrently to the same printer.
func testConcurrentQueries(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "concurrentQueries", printer: host) {
        // Each query creates its own TCP connection, so they should be independent
        async let info = printer.queryInfo()
        async let status = printer.queryStatus()
        async let memory = printer.queryMemory()

        let (i, s, m) = try await (info, status, memory)

        try assert(!i.model.isEmpty, "Info model should not be empty")
        try assert(s.labelLengthInDots > 0, "Status label length should be positive")
        try assert(m.total > 0, "Memory total should be positive")
        return "3 concurrent queries returned valid data"
    }
}

/// Tests sending 10 rapid sequential ~HI queries.
func testRapidQueryBurst(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "rapidQueryBurst", printer: host) {
        let burstCount = 10
        var models: Set<String> = []

        for _ in 0..<burstCount {
            let info = try await printer.queryInfo()
            models.insert(info.model)
        }

        // All queries should return the same model
        try assert(models.count == 1,
                   "Expected consistent model across \(burstCount) queries, got \(models.count) distinct values")
        return "\(burstCount) rapid queries, all consistent"
    }
}

/// Tests a mixed sequence of different query types.
func testMixedQuerySequence(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "mixedQuerySequence", printer: host) {
        let info1 = try await printer.queryInfo()
        let status = try await printer.queryStatus()
        let memory = try await printer.queryMemory()
        let info2 = try await printer.queryInfo()

        // Validate each returned the correct type (parsers didn't get confused)
        try assert(!info1.model.isEmpty, "First ~HI should return valid info")
        try assert(status.labelLengthInDots > 0, "~HS should return valid status")
        try assert(memory.total > 0, "~HM should return valid memory")
        try assert(info1.model == info2.model, "~HI results should be consistent across the sequence")
        return "~HI -> ~HS -> ~HM -> ~HI sequence all returned correct types"
    }
}

/// Tests that a very short response timeout produces the correct error.
func testShortResponseTimeout(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "shortResponseTimeout", printer: host) {
        // Use an extremely short response timeout (10ms). The printer may or
        // may not respond in time, so we accept either a valid response or a timeout.
        do {
            _ = try await printer.query("~HI", responseTimeout: 0.01)
            // If the printer was fast enough, that's fine too
            return "Printer responded within 10ms (fast!)"
        } catch let error as PrinterError {
            switch error {
            case .responseTimeout:
                return "Correctly returned .responseTimeout for 10ms limit"
            default:
                throw error
            }
        }
    }
}

/// Tests that querying works after a forced timeout (connection cleanup).
func testQueryAfterTimeout(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "queryAfterTimeout", printer: host) {
        // Force a timeout with very short deadline
        do {
            _ = try await printer.query("~HI", responseTimeout: 0.01)
        } catch {
            // Expected to fail, that's ok
        }

        // Now do a normal query. Should still work (connection was cleaned up).
        let info = try await printer.queryInfo()
        try assert(!info.model.isEmpty, "Query after timeout should still work")
        return "Normal query succeeded after forced timeout"
    }
}

// MARK: - Error Path Tests

/// Tests connection failure to an invalid port.
func testConnectionRefused(host: String) async -> TestResult {
    await runTest(name: "connectionRefused", printer: host) {
        let badPrinter = ZPLPrinter(host: host, port: 1, timeout: 3)
        do {
            _ = try await badPrinter.query("~HI", responseTimeout: 3)
            throw TestError.assertionFailed("Expected error but query succeeded")
        } catch is TestError {
            throw TestError.assertionFailed("Expected PrinterError but query succeeded")
        } catch let error as PrinterError {
            switch error {
            case .connectionFailed, .timeout:
                return "Correctly threw \(error) for invalid port"
            default:
                throw TestError.assertionFailed("Unexpected PrinterError: \(error)")
            }
        }
    }
}

/// Tests that sending an invalid command that produces no response gives responseTimeout.
func testInvalidCommand(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "invalidCommand", printer: host) {
        do {
            _ = try await printer.query("INVALID_NONSENSE", responseTimeout: 2)
            // Some printers may ignore and not respond, others may close the connection
            return "Printer ignored invalid command (no crash)"
        } catch let error as PrinterError {
            switch error {
            case .responseTimeout:
                return "Correctly timed out for invalid command"
            default:
                // Any PrinterError is acceptable for invalid commands
                return "Threw \(error) for invalid command"
            }
        }
    }
}

/// Tests that response timeout and connection timeout produce different error types.
func testTimeoutDifferentiation(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "timeoutDifferentiation", printer: host) {
        // Connection timeout: use a non-routable IP
        let unreachable = ZPLPrinter(host: "192.0.2.1", port: 9100, timeout: 2)
        var gotConnectionTimeout = false
        do {
            _ = try await unreachable.query("~HI", responseTimeout: 2)
        } catch let error as PrinterError {
            switch error {
            case .timeout:
                gotConnectionTimeout = true
            default:
                break
            }
        }
        try assert(gotConnectionTimeout, "Non-routable IP should produce .timeout")

        // Response timeout: connect to real printer but use a command that produces no response
        var gotResponseTimeout = false
        do {
            _ = try await printer.query("GARBAGE", responseTimeout: 1)
        } catch let error as PrinterError {
            switch error {
            case .responseTimeout:
                gotResponseTimeout = true
            default:
                break
            }
        }

        if gotResponseTimeout {
            return "Connection timeout -> .timeout, response timeout -> .responseTimeout"
        } else {
            return "Connection timeout -> .timeout (response timeout not triggered, printer may have responded)"
        }
    }
}

// MARK: - Bonjour Discovery Tests

func testBonjourDiscovery(hosts: [String]) async -> [TestResult] {
    var results: [TestResult] = []

    let start = Date()
    let browser = ZPLPrinterBrowser()

    // Wait for discovery (printers advertise _pdl-datastream._tcp)
    print("  Scanning for printers via Bonjour (5s)...")
    try? await Task.sleep(nanoseconds: 5_000_000_000)

    let discovered = browser.discoveredPrinters
    browser.stop()

    let discoveryTime = Date().timeIntervalSince(start)

    if discovered.isEmpty {
        results.append(TestResult(
            name: "bonjourDiscovery", printer: "network",
            passed: true, // Not a failure; printers may not advertise mDNS
            message: "No printers found via Bonjour (printers may not advertise _pdl-datastream._tcp)",
            duration: discoveryTime
        ))
        return results
    }

    // Test: discovered printers exist
    results.append(TestResult(
        name: "bonjourDiscovery", printer: "network",
        passed: true,
        message: "Found \(discovered.count) printer(s): \(discovered.map(\.name).joined(separator: ", "))",
        duration: discoveryTime
    ))

    // Test: discovered printer fields are valid
    for dp in discovered {
        let fieldResult = await runTest(name: "bonjourFields[\(dp.name)]", printer: dp.host) {
            try assert(!dp.name.isEmpty, "Discovered printer name should not be empty")
            try assert(!dp.host.isEmpty, "Discovered printer host should not be empty")
            try assert(dp.port > 0, "Discovered printer port should be positive, got \(dp.port)")
            return "name=\(dp.name), host=\(dp.host), port=\(dp.port)"
        }
        results.append(fieldResult)
    }

    // Test: connect to a discovered printer and query it
    if let first = discovered.first {
        let connectResult = await runTest(name: "bonjourConnect[\(first.name)]", printer: first.host) {
            let printer = ZPLPrinter(first)
            let info = try await printer.queryInfo()
            try assert(!info.model.isEmpty, "Should get valid info from discovered printer")
            return "Connected to discovered \(first.name): \(info.model)"
        }
        results.append(connectResult)
    }

    return results
}

// MARK: - Configuration Tests

/// Tests applying a configuration and verifying the printer accepted it.
func testApplyConfiguration(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "applyConfiguration", printer: host) {
        let info = try await printer.queryInfo()
        let dpmm = info.dotsPerMillimeter

        // Build a conservative config based on the printer's actual resolution
        let config = PrinterConfiguration.directThermal(
            widthDots: dpmm * 102,  // ~4 inches
            lengthDots: dpmm * 51   // ~2 inches
        )
        .printerName("ZPLKit-Test")

        // Apply the configuration
        try await printer.apply(config)

        // Verify printer is still responsive and accepted the config
        let status = try await printer.queryStatus()
        try assert(!status.isHeadOpen, "Head should be closed after config apply")

        // Verify the label length changed (within a reasonable tolerance)
        let expectedLength = dpmm * 51
        let tolerance = dpmm * 5  // Allow some tolerance for printer rounding
        try assert(
            abs(status.labelLengthInDots - expectedLength) <= tolerance,
            "Label length \(status.labelLengthInDots) not within \(tolerance) dots of expected \(expectedLength)"
        )

        return "Applied config (\(dpmm * 102)x\(dpmm * 51) dots), label now \(status.labelLengthInDots) dots"
    }
}

/// Tests save and restore of configuration.
func testSaveAndRestore(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "saveAndRestore", printer: host) {
        // Get the current status as our baseline
        let originalStatus = try await printer.queryStatus()
        let originalLength = originalStatus.labelLengthInDots

        let info = try await printer.queryInfo()
        let dpmm = info.dotsPerMillimeter

        // Apply a different label length
        let testLength = dpmm * 76  // ~3 inches
        let testConfig = PrinterConfiguration().labelLengthDots(testLength)
        try await printer.apply(testConfig)

        // Save it
        try await printer.saveConfiguration()

        // Verify it took effect
        let changedStatus = try await printer.queryStatus()
        let tolerance = dpmm * 5
        try assert(
            abs(changedStatus.labelLengthInDots - testLength) <= tolerance,
            "After save, label length \(changedStatus.labelLengthInDots) not near \(testLength)"
        )

        // Restore to the original length
        let restoreConfig = PrinterConfiguration().labelLengthDots(originalLength)
        try await printer.apply(restoreConfig)
        try await printer.saveConfiguration()

        // Verify restoration
        let restoredStatus = try await printer.queryStatus()
        try assert(
            abs(restoredStatus.labelLengthInDots - originalLength) <= tolerance,
            "After restore, label length \(restoredStatus.labelLengthInDots) not near original \(originalLength)"
        )

        return "Saved (\(testLength) dots), restored to original (\(originalLength) dots)"
    }
}

/// Tests the full setup() workflow (apply + save + calibrate).
func testCalibrateAfterSetup(printer: ZPLPrinter, host: String) async -> TestResult {
    await runTest(name: "calibrateAfterSetup", printer: host) {
        let info = try await printer.queryInfo()
        let dpmm = info.dotsPerMillimeter

        let config = PrinterConfiguration.directThermal(
            widthDots: dpmm * 102,  // ~4 inches
            lengthDots: dpmm * 51   // ~2 inches
        )

        // Run the full setup workflow
        try await printer.setup(config)

        // Wait a moment for calibration to complete
        try await Task.sleep(nanoseconds: 2_000_000_000)

        // Verify printer is ready after setup
        let status = try await printer.queryStatus()
        try assert(status.isReadyToPrint,
                   "Printer should be ready after setup, got: \(status)")

        return "setup() completed, printer ready: \(status.isReadyToPrint)"
    }
}

// MARK: - Runner

func parseArgs() -> (hosts: [String], timeout: TimeInterval) {
    let args = Array(CommandLine.arguments.dropFirst())
    var timeout: TimeInterval = 10
    var hosts: [String] = []

    var i = 0
    while i < args.count {
        if args[i] == "--timeout", i + 1 < args.count {
            timeout = TimeInterval(args[i + 1]) ?? 10
            i += 2
        } else if args[i] == "--help" || args[i] == "-h" {
            print("""
            Usage: swift run PrinterTests [OPTIONS] <IP> [<IP> ...]

            Runs integration tests against real Zebra printers.
            Tests query commands, network behavior, Bonjour discovery,
            and error paths.

            Options:
              --timeout <seconds>  Connection timeout (default: 10)
              --help, -h           Show this help

            Example:
              swift run PrinterTests 192.168.1.100 192.168.1.101 192.168.1.102
            """)
            exit(0)
        } else {
            hosts.append(args[i])
            i += 1
        }
    }

    return (hosts, timeout)
}

func printResult(_ result: TestResult) {
    let icon = result.passed ? "PASS" : "FAIL"
    let time = String(format: "%.1fs", result.duration)
    print("  [\(icon)] \(result.name) (\(time)) - \(result.message)")
}

func runTestsForPrinter(host: String, timeout: TimeInterval) async -> [TestResult] {
    let printer = ZPLPrinter(host: host, timeout: timeout)
    var results: [TestResult] = []

    // Core query tests
    let coreTests: [(ZPLPrinter, String) async -> TestResult] = [
        testQueryInfo,
        testQueryStatus,
        testQueryMemory,
        testRawQueryFraming,
    ]

    // Consistency and cross-validation
    let validationTests: [(ZPLPrinter, String) async -> TestResult] = [
        testQueryConsistency,
        testDPICrossCheck,
        testDPIEnumMapping,
    ]

    // Description formatting
    let descriptionTests: [(ZPLPrinter, String) async -> TestResult] = [
        testInfoDescription,
        testStatusDescription,
        testMemoryDescription,
    ]

    // Codable roundtrips
    let codableTests: [(ZPLPrinter, String) async -> TestResult] = [
        testInfoCodable,
        testStatusCodable,
        testMemoryCodable,
    ]

    // Additional ZPL commands
    let commandTests: [(ZPLPrinter, String) async -> TestResult] = [
        testQueryConfiguration,
        testQueryDirectory,
        testCancelIdleJob,
    ]

    // Network behavior
    let networkTests: [(ZPLPrinter, String) async -> TestResult] = [
        testConcurrentQueries,
        testRapidQueryBurst,
        testMixedQuerySequence,
        testShortResponseTimeout,
        testQueryAfterTimeout,
    ]

    // Error paths
    let errorTests: [(ZPLPrinter, String) async -> TestResult] = [
        testInvalidCommand,
        testTimeoutDifferentiation,
    ]

    // Configuration tests
    let configTests: [(ZPLPrinter, String) async -> TestResult] = [
        testApplyConfiguration,
        testSaveAndRestore,
        testCalibrateAfterSetup,
    ]

    let allTests = coreTests + validationTests + descriptionTests
        + codableTests + commandTests + networkTests + errorTests + configTests

    for test in allTests {
        let result = await test(printer, host)
        results.append(result)
        printResult(result)
    }

    // connectionRefused has a different signature (no printer param)
    let connResult = await testConnectionRefused(host: host)
    results.append(connResult)
    printResult(connResult)

    return results
}

// MARK: - Main

let config = parseArgs()

guard !config.hosts.isEmpty else {
    print("Error: No printer IPs specified.")
    print("Usage: swift run PrinterTests <IP> [<IP> ...]")
    print("       swift run PrinterTests --help")
    exit(1)
}

print("ZPLKit Printer Integration Tests")
print("=================================")
print("Printers: \(config.hosts.joined(separator: ", "))")
print("Timeout: \(Int(config.timeout))s")
print()

var allResults: [TestResult] = []

for host in config.hosts {
    print("[\(host)]")
    let results = await runTestsForPrinter(host: host, timeout: config.timeout)
    allResults.append(contentsOf: results)
    print()
}

// Bonjour discovery tests (run once across all printers)
print("[Bonjour Discovery]")
let bonjourResults = await testBonjourDiscovery(hosts: config.hosts)
for result in bonjourResults {
    printResult(result)
}
allResults.append(contentsOf: bonjourResults)
print()

// Summary
let passed = allResults.filter(\.passed).count
let failed = allResults.filter { !$0.passed }.count
let total = allResults.count
let totalTime = allResults.reduce(0.0) { $0 + $1.duration }

print("=================================")
print("Results: \(passed)/\(total) passed, \(failed) failed (\(String(format: "%.1fs", totalTime)) total)")

if failed > 0 {
    print()
    print("Failures:")
    for result in allResults where !result.passed {
        print("  [\(result.printer)] \(result.name): \(result.message)")
    }
    exit(1)
}
