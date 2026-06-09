import Foundation
import Testing
@testable import ZPLKitPrinter

/// Whether network-touching tests are enabled via environment variable.
///
/// These tests perform real socket / Bonjour operations (connection-refused,
/// timeouts, browser lifecycle) that are slow and flaky on CI runners, so they
/// are gated behind the same `ZPLTOOL_LIVE_TESTS` switch used by
/// `LivePrinterTests`. Hermetic parsing tests always run.
private let networkTestsEnabled = ProcessInfo.processInfo.environment["ZPLTOOL_LIVE_TESTS"] == "1"

@Suite("ZPLKitPrinter Tests")
struct ZPLKitPrinterTests {

    @Test("ZPLPrinter initializes with defaults")
    func printerDefaults() {
        let printer = ZPLPrinter(host: "192.168.1.100")

        #expect(printer.host == "192.168.1.100")
        #expect(printer.port == 9100)
        #expect(printer.timeout == 10)
    }

    @Test("ZPLPrinter initializes with custom port")
    func printerCustomPort() {
        let printer = ZPLPrinter(host: "10.0.0.50", port: 9101, timeout: 5)

        #expect(printer.host == "10.0.0.50")
        #expect(printer.port == 9101)
        #expect(printer.timeout == 5)
    }

    @Test("ZPLPrinter initializes from DiscoveredPrinter")
    func printerFromDiscovered() {
        let discovered = DiscoveredPrinter(
            name: "Zebra ZD420",
            host: "192.168.1.55",
            port: 9100
        )

        let printer = ZPLPrinter(discovered)

        #expect(printer.host == "192.168.1.55")
        #expect(printer.port == 9100)
    }

    @Test("DiscoveredPrinter has correct description")
    func discoveredPrinterDescription() {
        let printer = DiscoveredPrinter(
            name: "Label Printer",
            host: "10.0.0.100",
            port: 9100
        )

        #expect(printer.description == "Label Printer (10.0.0.100:9100)")
    }

    @Test("DiscoveredPrinter equality uses id")
    func discoveredPrinterEquality() {
        let printer1 = DiscoveredPrinter(
            id: "abc123",
            name: "Printer 1",
            host: "192.168.1.1"
        )
        let printer2 = DiscoveredPrinter(
            id: "abc123",
            name: "Different Name",
            host: "10.0.0.1"
        )
        let printer3 = DiscoveredPrinter(
            id: "xyz789",
            name: "Printer 1",
            host: "192.168.1.1"
        )

        #expect(printer1 == printer2)  // Same ID
        #expect(printer1 != printer3)  // Different ID
    }

    @Test("PrinterError descriptions are meaningful")
    func errorDescriptions() {
        let connectionError = PrinterError.connectionFailed(
            host: "192.168.1.100",
            port: 9100,
            underlying: "Connection refused"
        )
        #expect(connectionError.errorDescription?.contains("192.168.1.100") == true)
        #expect(connectionError.errorDescription?.contains("9100") == true)

        let timeoutError = PrinterError.timeout(host: "10.0.0.1", port: 9100)
        #expect(timeoutError.errorDescription?.contains("timed out") == true)

        let notFoundError = PrinterError.printerNotFound(name: "My Printer")
        #expect(notFoundError.errorDescription?.contains("My Printer") == true)

        let receiveError = PrinterError.receiveFailed(underlying: "Connection reset")
        #expect(receiveError.errorDescription?.contains("receive") == true)

        let responseTimeoutError = PrinterError.responseTimeout(host: "192.168.1.50", port: 9100)
        #expect(responseTimeoutError.errorDescription?.contains("No response") == true)
        #expect(responseTimeoutError.errorDescription?.contains("error state") == true)

        let invalidResponseError = PrinterError.invalidResponse("Unexpected format")
        #expect(invalidResponseError.errorDescription?.contains("Invalid response") == true)

        let sendError = PrinterError.sendFailed(underlying: "Broken pipe")
        #expect(sendError.errorDescription?.contains("send") == true)
        #expect(sendError.errorDescription?.contains("Broken pipe") == true)

        let configError = PrinterError.invalidConfiguration("Port must be positive")
        #expect(configError.errorDescription?.contains("Invalid configuration") == true)
        #expect(configError.errorDescription?.contains("Port must be positive") == true)
    }

    @Test("ZPLPrinterBrowser service type is correct")
    func browserServiceType() {
        #expect(ZPLPrinterBrowser.serviceType == "_pdl-datastream._tcp")
    }

    // MARK: - Network Error Tests

    @Test("ZPLPrinter times out on non-routable address",
          .tags(.live),
          .enabled(if: networkTestsEnabled, "Set ZPLTOOL_LIVE_TESTS=1 to enable network tests"))
    func printerTimeout() async throws {
        // 10.255.255.1 is a non-routable address that should timeout
        let printer = ZPLPrinter(host: "10.255.255.1", timeout: 1)

        do {
            try await printer.send("^XA^XZ")
            Issue.record("Expected timeout error")
        } catch let error as PrinterError {
            // Verify we got a timeout or connection error
            switch error {
            case .timeout(let host, let port):
                #expect(host == "10.255.255.1")
                #expect(port == 9100)
            case .connectionFailed:
                // Connection refused is also acceptable
                break
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test("ZPLPrinter fails on connection refused",
          .tags(.live),
          .enabled(if: networkTestsEnabled, "Set ZPLTOOL_LIVE_TESTS=1 to enable network tests"))
    func printerConnectionRefused() async throws {
        // localhost on an unlikely port should refuse connection
        let printer = ZPLPrinter(host: "127.0.0.1", port: 59999, timeout: 2)

        do {
            try await printer.send("^XA^XZ")
            Issue.record("Expected connection error")
        } catch let error as PrinterError {
            switch error {
            case .connectionFailed(let host, let port, _):
                #expect(host == "127.0.0.1")
                #expect(port == 59999)
            case .timeout:
                // Timeout is also acceptable on some systems
                break
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - Browser Lifecycle Tests

    @Test("ZPLPrinterBrowser starts and stops without crashing",
          .tags(.live),
          .enabled(if: networkTestsEnabled, "Set ZPLTOOL_LIVE_TESTS=1 to enable network tests"))
    func browserLifecycle() {
        let browser = ZPLPrinterBrowser()

        // Start browsing
        browser.start()

        // Immediately after start (before mDNS resolution completes) the
        // discovered set is empty.
        let printers = browser.discoveredPrinters
        #expect(printers.isEmpty)

        // Stop browsing
        browser.stop()

        // Should be able to stop multiple times safely
        browser.stop()
    }

    @Test("ZPLPrinterBrowser discoveredPrinters is initially empty")
    func browserInitiallyEmpty() {
        let browser = ZPLPrinterBrowser()
        #expect(browser.discoveredPrinters.isEmpty)
    }

    @Test("ZPLPrinterBrowser can restart after stop",
          .tags(.live),
          .enabled(if: networkTestsEnabled, "Set ZPLTOOL_LIVE_TESTS=1 to enable network tests"))
    func browserRestart() {
        let browser = ZPLPrinterBrowser()

        browser.start()
        browser.stop()
        browser.start()
        browser.stop()

        // Should complete without crashing
    }

    // MARK: - Query (Bidirectional) Tests

    @Test("ZPLPrinter query times out on non-routable address",
          .tags(.live),
          .enabled(if: networkTestsEnabled, "Set ZPLTOOL_LIVE_TESTS=1 to enable network tests"))
    func queryTimeout() async throws {
        // 10.255.255.1 is a non-routable address that should timeout
        let printer = ZPLPrinter(host: "10.255.255.1", timeout: 1)

        do {
            _ = try await printer.query("~HS", responseTimeout: 1)
            Issue.record("Expected timeout error")
        } catch let error as PrinterError {
            switch error {
            case .timeout(let host, let port):
                #expect(host == "10.255.255.1")
                #expect(port == 9100)
            case .connectionFailed:
                // Connection failed is also acceptable
                break
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test("ZPLPrinter query fails on connection refused",
          .tags(.live),
          .enabled(if: networkTestsEnabled, "Set ZPLTOOL_LIVE_TESTS=1 to enable network tests"))
    func queryConnectionRefused() async throws {
        // localhost on an unlikely port should refuse connection
        let printer = ZPLPrinter(host: "127.0.0.1", port: 59999, timeout: 2)

        do {
            _ = try await printer.query("~HS", responseTimeout: 1)
            Issue.record("Expected connection error")
        } catch let error as PrinterError {
            switch error {
            case .connectionFailed(let host, let port, _):
                #expect(host == "127.0.0.1")
                #expect(port == 59999)
            case .timeout:
                // Timeout is also acceptable on some systems
                break
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    @Test("query() returns promptly on fast connection-refused (no hang)",
          .tags(.live), .timeLimit(.minutes(1)),
          .enabled(if: networkTestsEnabled, "Set ZPLTOOL_LIVE_TESTS=1 to enable network tests"))
    func queryFastFailureDoesNotHang() async throws {
        // Connecting to a closed local port fails almost instantly. This
        // exercises the H1 race where the connection can fail before the
        // detached task registers the continuation. With the pending-result
        // fix the continuation is always resumed, so this must throw rather
        // than hang. The .timeLimit catches a regression as a failure.
        let printer = ZPLPrinter(host: "127.0.0.1", port: 59997, timeout: 2)

        await #expect(throws: PrinterError.self) {
            _ = try await printer.query("~HS", responseTimeout: 2)
        }
    }

    @Test("query() rejects invalid (zero) port instead of crashing")
    func queryRejectsZeroPort() async throws {
        let printer = ZPLPrinter(host: "127.0.0.1", port: 0)
        await #expect(throws: PrinterError.self) {
            _ = try await printer.query("~HS", responseTimeout: 1)
        }
    }

    @Test("send() rejects invalid (zero) port instead of crashing")
    func sendRejectsZeroPort() async throws {
        let printer = ZPLPrinter(host: "127.0.0.1", port: 0)
        await #expect(throws: PrinterError.self) {
            try await printer.send("^XA^XZ")
        }
    }

    @Test("send() of empty data is a no-op success")
    func sendEmptyDataSucceeds() async throws {
        // Empty data must not trap on baseAddress and must not perform any
        // socket work. Port 0 would otherwise throw, proving the early return.
        let printer = ZPLPrinter(host: "127.0.0.1", port: 0)
        try await printer.send(Data())
    }

    @Test("ZPLPrinter query static method works with discovered printer",
          .tags(.live),
          .enabled(if: networkTestsEnabled, "Set ZPLTOOL_LIVE_TESTS=1 to enable network tests"))
    func queryStaticMethod() async throws {
        let discovered = DiscoveredPrinter(
            name: "Test Printer",
            host: "127.0.0.1",
            port: 59998
        )

        do {
            _ = try await ZPLPrinter.query("~HS", from: discovered, timeout: 1, responseTimeout: 1)
            Issue.record("Expected error")
        } catch let error as PrinterError {
            // Any error is fine, we just want to verify the static method compiles and runs
            switch error {
            case .connectionFailed, .timeout, .responseTimeout:
                break  // Expected
            default:
                Issue.record("Unexpected error type: \(error)")
            }
        }
    }

    // MARK: - PrinterStatus Tests

    /// Helper to build ~HS response data with proper framing.
    private func buildHSResponse(string1: String, string2: String, string3: String = "0000,0") -> Data {
        var data = Data()
        for str in [string1, string2, string3] {
            data.append(0x02)  // STX
            data.append(contentsOf: str.utf8)
            data.append(contentsOf: [0x03, 0x0D, 0x0A] as [UInt8])  // ETX CR LF
        }
        return data
    }

    @Test("PrinterStatus parses valid ~HS response")
    func printerStatusParsesValidResponse() throws {
        // String 1: comm=000, paper_out=0, pause=0, label_len=0799, formats=000, buffer_full=0,
        //           comm_diag=0, partial=0, unused=000, corrupt=0, temp=0, unused=0
        // String 2: func=0, head_up=0, ribbon_out=0, thermal=1, mode=0, width=0, waiting=0, remaining=0000
        let response = buildHSResponse(
            string1: "000,0,0,0799,000,0,0,0,000,0,0,0",
            string2: "0,0,0,1,0,0,0,0000"
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isPaperOut == false)
        #expect(status.isRibbonOut == false)
        #expect(status.isHeadOpen == false)
        #expect(status.isPaused == false)
        #expect(status.isReceiveBufferFull == false)
        #expect(status.labelLengthInDots == 799)
        #expect(status.isReadyToPrint == true)
    }

    @Test("PrinterStatus parses paper out condition")
    func printerStatusParsesPaperOut() throws {
        let response = buildHSResponse(
            string1: "000,1,0,0799,000,0,0,0,000,0,0,0",  // paper_out=1
            string2: "0,0,0,1,0,0,0,0000"
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isPaperOut == true)
        #expect(status.isReadyToPrint == false)
        #expect(status.hasError == true)
    }

    @Test("PrinterStatus parses head open condition")
    func printerStatusParsesHeadOpen() throws {
        let response = buildHSResponse(
            string1: "000,0,0,0799,000,0,0,0,000,0,0,0",
            string2: "0,1,0,1,0,0,0,0000"  // head_up=1
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isHeadOpen == true)
        #expect(status.isReadyToPrint == false)
        #expect(status.hasError == true)
    }

    @Test("PrinterStatus parses ribbon out condition")
    func printerStatusParsesRibbonOut() throws {
        let response = buildHSResponse(
            string1: "000,0,0,0799,000,0,0,0,000,0,0,0",
            string2: "0,0,1,1,0,0,0,0000"  // ribbon_out=1
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isRibbonOut == true)
        #expect(status.isReadyToPrint == false)
        #expect(status.hasError == true)
    }

    @Test("PrinterStatus parses paused state")
    func printerStatusParsesPaused() throws {
        let response = buildHSResponse(
            string1: "000,0,1,0799,000,0,0,0,000,0,0,0",  // pause=1
            string2: "0,0,0,1,0,0,0,0000"
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isPaused == true)
        #expect(status.isReadyToPrint == false)
        #expect(status.hasError == false)  // Paused is not an error
    }

    @Test("PrinterStatus parses labels remaining")
    func printerStatusParsesLabelsRemaining() throws {
        let response = buildHSResponse(
            string1: "000,0,0,0799,003,0,0,0,000,0,0,0",  // formats=003
            string2: "0,0,0,1,0,0,0,0042"  // remaining=0042
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.formatsInBuffer == 3)
        #expect(status.labelsRemainingInBatch == 42)
    }

    @Test("PrinterStatus parses temperature flags")
    func printerStatusParsesTemperature() throws {
        let response = buildHSResponse(
            string1: "000,0,0,0799,000,0,0,0,000,0,2,0",  // temp=2 (over temp)
            string2: "0,0,0,1,0,0,0,0000"
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isHeadTooHot == true)
        #expect(status.isHeadCold == false)
        #expect(status.hasError == true)
    }

    @Test("PrinterStatus parses head cold condition")
    func printerStatusParsesHeadCold() throws {
        let response = buildHSResponse(
            string1: "000,0,0,0799,000,0,0,0,000,0,1,0",  // temp=1 (under temp)
            string2: "0,0,0,1,0,0,0,0000"
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isHeadCold == true)
        #expect(status.isHeadTooHot == false)
        // Note: isHeadCold is a warning, not an error that prevents printing
        #expect(status.hasError == false)
    }

    @Test("PrinterStatus parses receive buffer full")
    func printerStatusParsesReceiveBufferFull() throws {
        let response = buildHSResponse(
            string1: "000,0,0,0799,000,1,0,0,000,0,0,0",  // buffer_full=1
            string2: "0,0,0,1,0,0,0,0000"
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isReceiveBufferFull == true)
    }

    @Test("PrinterStatus parses partial format in progress")
    func printerStatusParsesPartialFormat() throws {
        let response = buildHSResponse(
            string1: "000,0,0,0799,000,0,0,1,000,0,0,0",  // partial=1
            string2: "0,0,0,1,0,0,0,0000"
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isPartialFormatInProgress == true)
    }

    @Test("PrinterStatus parses multiple combined errors")
    func printerStatusParsesMultipleErrors() throws {
        let response = buildHSResponse(
            string1: "000,1,1,0799,000,0,0,0,000,0,2,0",  // paper_out=1, pause=1, temp=2
            string2: "0,1,1,1,0,0,0,0000"  // head_up=1, ribbon_out=1
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isPaperOut == true)
        #expect(status.isPaused == true)
        #expect(status.isHeadTooHot == true)
        #expect(status.isHeadOpen == true)
        #expect(status.isRibbonOut == true)
        #expect(status.isReadyToPrint == false)
        #expect(status.hasError == true)
    }

    @Test("PrinterStatus throws on invalid response")
    func printerStatusThrowsOnInvalidResponse() throws {
        // Only one string instead of two
        var data = Data()
        data.append(0x02)
        data.append(contentsOf: "000,0,0,0799,000,0,0,0,000,0,0,0".utf8)
        data.append(contentsOf: [0x03, 0x0D, 0x0A] as [UInt8])

        #expect(throws: PrinterError.self) {
            _ = try PrinterStatus.parse(from: data)
        }
    }

    @Test("PrinterStatus parses identically from a non-zero-startIndex slice")
    func printerStatusParsesFromSlice() throws {
        let response = buildHSResponse(
            string1: "000,0,0,0799,000,0,0,0,000,0,0,0",
            string2: "0,0,0,1,0,0,0,0000"
        )
        // Prepend bytes, then slice them off so startIndex != 0.
        let prefixed = Data([0x00, 0x00]) + response
        let slice = prefixed[2...]
        #expect(slice.startIndex != 0)

        let fromSlice = try PrinterStatus.parse(from: slice)
        let fromFull = try PrinterStatus.parse(from: response)
        #expect(fromSlice == fromFull)
    }

    @Test("PrinterStatus description is readable")
    func printerStatusDescription() {
        let ready = PrinterStatus()
        #expect(ready.description == "Ready")

        let paperOut = PrinterStatus(isPaperOut: true)
        #expect(paperOut.description.contains("Paper Out"))

        let multiple = PrinterStatus(isPaperOut: true, isHeadOpen: true)
        #expect(multiple.description.contains("Paper Out"))
        #expect(multiple.description.contains("Head Open"))
    }

    @Test("PrinterStatus is Codable")
    func printerStatusCodable() throws {
        let status = PrinterStatus(
            isPaperOut: true,
            formatsInBuffer: 5,
            labelsRemainingInBatch: 10
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(status)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PrinterStatus.self, from: data)

        #expect(decoded == status)
    }

    // MARK: - PrinterInfo Tests

    /// Helper to build ~HI response data with proper framing.
    private func buildHIResponse(_ content: String) -> Data {
        var data = Data()
        data.append(0x02)  // STX
        data.append(contentsOf: content.utf8)
        data.append(contentsOf: [0x03, 0x0D, 0x0A] as [UInt8])  // ETX CR LF
        return data
    }

    @Test("PrinterInfo parses valid ~HI response")
    func printerInfoParsesValidResponse() throws {
        let response = buildHIResponse("ZT410-203dpi,V53.17.14Z,8,49152KB,NONE")

        let info = try PrinterInfo.parse(from: response)

        #expect(info.model == "ZT410-203dpi")
        #expect(info.firmwareVersion == "V53.17.14Z")
        #expect(info.dotsPerMillimeter == 8)
        #expect(info.dpi == 203)
        #expect(info.memoryKB == 49152)
        #expect(info.options.isEmpty)
    }

    @Test("PrinterInfo parses ZM400 response")
    func printerInfoParsesZM400() throws {
        let response = buildHIResponse("ZM400-200dpi,V48.18.2Z,8,9984KB,NONE")

        let info = try PrinterInfo.parse(from: response)

        #expect(info.model == "ZM400-200dpi")
        #expect(info.firmwareVersion == "V48.18.2Z")
        #expect(info.dotsPerMillimeter == 8)
        #expect(info.memoryKB == 9984)
    }

    @Test("PrinterInfo parses 300dpi printer")
    func printerInfoParses300dpi() throws {
        let response = buildHIResponse("ZT410-300dpi,V75.20.15Z,12,65536KB,NONE")

        let info = try PrinterInfo.parse(from: response)

        #expect(info.dotsPerMillimeter == 12)
        #expect(info.dpi == 300)  // 12 dpm maps to the standard 300 dpi
    }

    @Test("PrinterInfo parses with options")
    func printerInfoParsesWithOptions() throws {
        let response = buildHIResponse("ZT410-203dpi,V53.17.14Z,8,49152KB,CUTTER")

        let info = try PrinterInfo.parse(from: response)

        #expect(info.options.count == 1)
        #expect(info.options.contains("CUTTER"))
    }

    @Test("PrinterInfo memory formatting")
    func printerInfoMemoryFormatting() {
        let smallMemory = PrinterInfo(
            model: "Test",
            firmwareVersion: "V1.0",
            dotsPerMillimeter: 8,
            memoryKB: 512
        )
        #expect(smallMemory.memoryFormatted == "512KB")

        let largeMemory = PrinterInfo(
            model: "Test",
            firmwareVersion: "V1.0",
            dotsPerMillimeter: 8,
            memoryKB: 65536
        )
        #expect(largeMemory.memoryFormatted == "64MB")
    }

    @Test("PrinterInfo throws on invalid response")
    func printerInfoThrowsOnInvalidResponse() throws {
        // Too few fields
        let response = buildHIResponse("ZT410,V53.17.14Z")

        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: response)
        }
    }

    @Test("PrinterInfo throws on invalid DPM")
    func printerInfoThrowsOnInvalidDPM() throws {
        let response = buildHIResponse("ZT410-203dpi,V53.17.14Z,invalid,49152KB,NONE")

        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: response)
        }
    }

    @Test("PrinterInfo throws on invalid memory value")
    func printerInfoThrowsOnInvalidMemory() throws {
        let response = buildHIResponse("ZT410-203dpi,V53.17.14Z,8,invalid,NONE")

        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: response)
        }
    }

    @Test("PrinterInfo rejects out-of-range DPM (hostile data)")
    func printerInfoRejectsHostileDPM() throws {
        // A huge DPM value would previously trap the dpi computation; parse
        // must reject it as untrusted network input.
        let huge = buildHIResponse("EVIL,V1,999999999999,1KB,NONE")
        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: huge)
        }

        let negative = buildHIResponse("EVIL,V1,-5,1KB,NONE")
        #expect(throws: PrinterError.self) {
            _ = try PrinterInfo.parse(from: negative)
        }
    }

    @Test("PrinterInfo.dpi does not trap on hostile dotsPerMillimeter")
    func printerInfoDPIDoesNotTrap() {
        // Constructed directly (bypassing parse) with an absurd value: dpi
        // must clamp instead of trapping the Int(Double) conversion, and
        // description (which reads dpi) must not crash.
        let info = PrinterInfo(
            model: "X",
            firmwareVersion: "V1",
            dotsPerMillimeter: Int.max,
            memoryKB: 1
        )
        _ = info.dpi
        _ = info.description

        let negative = PrinterInfo(
            model: "X",
            firmwareVersion: "V1",
            dotsPerMillimeter: Int.min,
            memoryKB: 1
        )
        _ = negative.dpi
        _ = negative.description
    }

    @Test("PrinterInfo description is readable")
    func printerInfoDescription() {
        let info = PrinterInfo(
            model: "ZT410-203dpi",
            firmwareVersion: "V53.17.14Z",
            dotsPerMillimeter: 8,
            memoryKB: 49152,
            options: ["CUTTER"]
        )

        let desc = info.description
        #expect(desc.contains("ZT410-203dpi"))
        #expect(desc.contains("V53.17.14Z"))
        #expect(desc.contains("203dpi"))
        #expect(desc.contains("48MB"))
        #expect(desc.contains("CUTTER"))
    }

    @Test("PrinterInfo is Codable")
    func printerInfoCodable() throws {
        let info = PrinterInfo(
            model: "ZT410-203dpi",
            firmwareVersion: "V53.17.14Z",
            dotsPerMillimeter: 8,
            memoryKB: 49152,
            options: ["CUTTER", "REWIND"]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(info)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PrinterInfo.self, from: data)

        #expect(decoded == info)
    }

    @Test("PrinterInfo parses identically from a non-zero-startIndex slice")
    func printerInfoParsesFromSlice() throws {
        let response = buildHIResponse("ZT410-203dpi,V53.17.14Z,8,49152KB,NONE")
        let prefixed = Data([0x00, 0x00]) + response
        let slice = prefixed[2...]
        #expect(slice.startIndex != 0)

        let fromSlice = try PrinterInfo.parse(from: slice)
        let fromFull = try PrinterInfo.parse(from: response)
        #expect(fromSlice == fromFull)
    }

    @Test("PrinterInfo parses without STX/ETX framing")
    func printerInfoParsesWithoutFraming() throws {
        // Some printers or connections may strip framing
        let response = Data("ZT410-203dpi,V53.17.14Z,8,49152KB,NONE".utf8)

        let info = try PrinterInfo.parse(from: response)

        #expect(info.model == "ZT410-203dpi")
        #expect(info.firmwareVersion == "V53.17.14Z")
    }

    // MARK: - MemoryStatus Tests

    /// Helper to build ~HM response data with proper framing.
    private func buildHMResponse(_ content: String) -> Data {
        var data = Data()
        data.append(0x02)  // STX
        data.append(contentsOf: content.utf8)
        data.append(contentsOf: [0x03, 0x0D, 0x0A] as [UInt8])  // ETX CR LF
        return data
    }

    @Test("MemoryStatus parses valid ~HM response")
    func memoryStatusParsesValidResponse() throws {
        // 2MB total, 2MB max, ~1.76MB available
        let response = buildHMResponse("2097152,2097152,1847296")

        let memory = try MemoryStatus.parse(from: response)

        #expect(memory.total == 2097152)
        #expect(memory.maximum == 2097152)
        #expect(memory.available == 1847296)
        #expect(memory.used == 249856)
    }

    @Test("MemoryStatus calculates usage percent")
    func memoryStatusUsagePercent() {
        let memory = MemoryStatus(total: 1000, maximum: 1000, available: 250)

        #expect(memory.usagePercent == 75)
    }

    @Test("MemoryStatus formats bytes correctly")
    func memoryStatusFormatting() {
        // Small memory (bytes)
        let small = MemoryStatus(total: 512, maximum: 512, available: 256)
        #expect(small.totalFormatted == "512B")

        // Medium memory (KB)
        let medium = MemoryStatus(total: 65536, maximum: 65536, available: 32768)
        #expect(medium.totalFormatted == "64KB")
        #expect(medium.availableFormatted == "32KB")

        // Large memory (MB)
        let large = MemoryStatus(total: 2097152, maximum: 2097152, available: 1048576)
        #expect(large.totalFormatted == "2MB")
        #expect(large.availableFormatted == "1MB")
    }

    @Test("MemoryStatus throws on invalid response")
    func memoryStatusThrowsOnInvalidResponse() throws {
        // Too few fields
        let response = buildHMResponse("2097152,2097152")

        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: response)
        }
    }

    @Test("MemoryStatus throws on non-numeric value")
    func memoryStatusThrowsOnNonNumeric() throws {
        let response = buildHMResponse("2097152,invalid,1847296")

        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: response)
        }
    }

    @Test("MemoryStatus description is readable")
    func memoryStatusDescription() {
        let memory = MemoryStatus(total: 2097152, maximum: 2097152, available: 1048576)

        let desc = memory.description
        #expect(desc.contains("1MB available"))
        #expect(desc.contains("2MB"))
        #expect(desc.contains("50% used"))
    }

    @Test("MemoryStatus is Codable")
    func memoryStatusCodable() throws {
        let memory = MemoryStatus(total: 2097152, maximum: 2097152, available: 1048576)

        let encoder = JSONEncoder()
        let data = try encoder.encode(memory)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MemoryStatus.self, from: data)

        #expect(decoded == memory)
    }

    @Test("MemoryStatus rejects negative and inverted values (hostile data)")
    func memoryStatusRejectsHostileValues() throws {
        // Negative values
        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: buildHMResponse("-1,1000,500"))
        }
        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: buildHMResponse("1000,1000,-5"))
        }
        // available > total
        #expect(throws: PrinterError.self) {
            _ = try MemoryStatus.parse(from: buildHMResponse("1000,1000,5000"))
        }
    }

    @Test("MemoryStatus used/usagePercent do not trap on extreme values")
    func memoryStatusDoesNotTrap() {
        // Constructed directly (bypassing parse) with extreme values: the
        // computed properties must clamp, not overflow-trap, and description
        // (which reads both) must not crash.
        let extreme = MemoryStatus(total: Int.max, maximum: Int.max, available: Int.min)
        _ = extreme.used
        _ = extreme.usagePercent
        _ = extreme.description

        let inverted = MemoryStatus(total: 1, maximum: 1, available: Int.max)
        _ = inverted.used
        _ = inverted.usagePercent
        _ = inverted.description
    }

    @Test("MemoryStatus parses identically from a non-zero-startIndex slice")
    func memoryStatusParsesFromSlice() throws {
        let response = buildHMResponse("2097152,2097152,1847296")
        let prefixed = Data([0x00, 0x00]) + response
        let slice = prefixed[2...]
        #expect(slice.startIndex != 0)

        let fromSlice = try MemoryStatus.parse(from: slice)
        let fromFull = try MemoryStatus.parse(from: response)
        #expect(fromSlice == fromFull)
    }

    @Test("MemoryStatus parses without STX/ETX framing")
    func memoryStatusParsesWithoutFraming() throws {
        let response = Data("2097152,2097152,1847296".utf8)

        let memory = try MemoryStatus.parse(from: response)

        #expect(memory.total == 2097152)
        #expect(memory.available == 1847296)
    }

    // MARK: - PrinterStatus Config Fields

    @Test("PrinterStatus parses thermal transfer flag from string 2")
    func printerStatusParsesThermalTransfer() throws {
        let response = buildHSResponse(
            string1: "000,0,0,0799,000,0,0,0,000,0,0,0",
            string2: "0,0,0,1,0,2,0,0000"  // thermal_transfer=1
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isThermalTransfer == true)
    }

    @Test("PrinterStatus parses direct thermal mode")
    func printerStatusParsesDirectThermal() throws {
        let response = buildHSResponse(
            string1: "000,0,0,0799,000,0,0,0,000,0,0,0",
            string2: "0,0,0,0,0,2,0,0000"  // thermal_transfer=0
        )

        let status = try PrinterStatus.parse(from: response)

        #expect(status.isThermalTransfer == false)
    }

    // MARK: - PrinterSettings Tests

    @Test("PrinterSettings parses darkness from ^HH response")
    func printerSettingsParsesDarkness() {
        // Real ^HH format: value on left, field name on right
        let text = """
          +15                 DARKNESS
          4 IPS               PRINT SPEED
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.darkness == 15)
        #expect(settings.printSpeed == 4)
    }

    @Test("PrinterSettings parses media type via PRINT METHOD")
    func printerSettingsParsesThermalTransfer() {
        let text = """
          THERMAL-TRANS.      PRINT METHOD
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.mediaType == .thermalTransfer)
    }

    @Test("PrinterSettings parses direct thermal via PRINT METHOD")
    func printerSettingsParsesDirectThermal() {
        let text = """
          DIRECT-THERMAL      PRINT METHOD
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.mediaType == .directThermal)
    }

    @Test("PrinterSettings parses media tracking from MEDIA TYPE field")
    func printerSettingsParsesTrackingGap() {
        let text = """
          GAP/NOTCH           MEDIA TYPE
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.mediaTracking == .gap)
    }

    @Test("PrinterSettings parses continuous tracking from MEDIA TYPE field")
    func printerSettingsParsesTrackingContinuous() {
        let text = """
          CONTINUOUS          MEDIA TYPE
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.mediaTracking == .continuous)
    }

    @Test("PrinterSettings parses mark tracking from MEDIA TYPE field")
    func printerSettingsParsesTrackingMark() {
        let text = """
          MARK                MEDIA TYPE
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.mediaTracking == .mark)
    }

    @Test("PrinterSettings falls back to SENSOR TYPE for tracking")
    func printerSettingsParsesTrackingFromSensor() {
        let text = """
          WEB                 SENSOR TYPE
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.mediaTracking == .gap)
    }

    @Test("PrinterSettings parses print width and label length")
    func printerSettingsParsesDimensions() {
        let text = """
          832                 PRINT WIDTH
          1218                LABEL LENGTH
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.printWidthDots == 832)
        #expect(settings.labelLengthDots == 1218)
    }

    @Test("PrinterSettings parses print mode tear-off")
    func printerSettingsParsesPrintMode() {
        let text = """
          TEAR OFF            PRINT MODE
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.printMode == .tearOff)
    }

    @Test("PrinterSettings parses tear-off adjust")
    func printerSettingsParsesTearOffAdjust() {
        let text = """
          +000                TEAR OFF
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.tearOffAdjust == 0)
    }

    @Test("PrinterSettings parses negative tear-off adjust")
    func printerSettingsParsesNegativeTearOff() {
        let text = """
          -015                TEAR OFF
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.tearOffAdjust == -15)
    }

    @Test("PrinterSettings returns empty for unrecognized text")
    func printerSettingsParsesEmpty() {
        let text = "Some random printer output with no config keys"
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.darkness == nil)
        #expect(settings.printSpeed == nil)
        #expect(settings.mediaType == nil)
    }

    @Test("PrinterSettings parse from Data works")
    func printerSettingsParsesFromData() throws {
        let text = "  25                  DARKNESS\n  6 IPS               PRINT SPEED"
        let data = Data(text.utf8)
        let settings = try PrinterSettings.parse(from: data)
        #expect(settings.darkness == 25)
        #expect(settings.printSpeed == 6)
    }

    @Test("PrinterSettings throws on invalid data")
    func printerSettingsThrowsOnInvalidData() {
        // Invalid UTF-8 data
        let data = Data([0xFF, 0xFE, 0x00, 0x01])
        #expect(throws: PrinterError.self) {
            _ = try PrinterSettings.parse(from: data)
        }
    }

    @Test("PrinterSettings description is readable")
    func printerSettingsDescription() {
        var settings = PrinterSettings()
        settings.darkness = 20
        settings.printSpeed = 4
        settings.mediaType = .directThermal

        let desc = settings.description
        #expect(desc.contains("darkness: 20"))
        #expect(desc.contains("speed: 4"))
        #expect(desc.contains("direct-thermal"))
    }

    @Test("PrinterSettings empty description")
    func printerSettingsEmptyDescription() {
        let settings = PrinterSettings()
        #expect(settings.description == "No settings parsed")
    }

    @Test("PrinterSettings is Codable")
    func printerSettingsCodable() throws {
        var settings = PrinterSettings()
        settings.darkness = 20
        settings.printSpeed = 6
        settings.mediaType = .thermalTransfer
        settings.mediaTracking = .gap
        settings.printWidthDots = 832
        settings.labelLengthDots = 1218
        settings.printMode = .tearOff
        settings.tearOffAdjust = 16

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(PrinterSettings.self, from: data)

        #expect(decoded == settings)
    }

    @Test("PrinterSettings parses ZM400 ^HH output")
    func printerSettingsParsesZM400Output() {
        // Real ZM400 ^HH output format
        let text = """
          +15                 DARKNESS
          2 IPS               PRINT SPEED
          +000                TEAR OFF
          TEAR OFF            PRINT MODE
          GAP/NOTCH           MEDIA TYPE
          TRANSMISSIVE        SENSOR SELECT
          THERMAL-TRANS.      PRINT METHOD
          812                 PRINT WIDTH
          0419                LABEL LENGTH
          39.0IN   988MM      MAXIMUM LENGTH
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.darkness == 15)
        #expect(settings.printSpeed == 2)
        #expect(settings.mediaType == .thermalTransfer)
        #expect(settings.mediaTracking == .gap)
        #expect(settings.printWidthDots == 812)
        #expect(settings.labelLengthDots == 419)
        #expect(settings.printMode == .tearOff)
        #expect(settings.tearOffAdjust == 0)
    }

    @Test("PrinterSettings parses GX420t ^HH output")
    func printerSettingsParsesGX420tOutput() {
        // Real GX420t ^HH output format
        let text = """
          05.0                DARKNESS
          4 IPS               PRINT SPEED
          +000                TEAR OFF
          TEAR OFF            PRINT MODE
          CONTINUOUS          MEDIA TYPE
          WEB                 SENSOR TYPE
          MANUAL              SENSOR SELECT
          THERMAL-TRANS.      PRINT METHOD
          812                 PRINT WIDTH
          0406                LABEL LENGTH
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.darkness == 5)
        #expect(settings.printSpeed == 4)
        #expect(settings.mediaType == .thermalTransfer)
        #expect(settings.mediaTracking == .continuous)
        #expect(settings.printWidthDots == 812)
        #expect(settings.labelLengthDots == 406)
        #expect(settings.printMode == .tearOff)
        #expect(settings.tearOffAdjust == 0)
    }

    // MARK: - Extended Diagnostic Field Tests

    @Test("PrinterSettings parses serial number")
    func printerSettingsParsesSerialNumber() {
        let text = "  31J114702349        SERIAL NUMBER"
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.serialNumber == "31J114702349")
    }

    @Test("PrinterSettings parses firmware with arrow marker")
    func printerSettingsParsesFirmwareWithArrow() {
        let text = "  V53.17.24Z <-       FIRMWARE"
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.firmware == "V53.17.24Z")
    }

    @Test("PrinterSettings parses firmware without arrow marker")
    func printerSettingsParsesFirmwareWithoutArrow() {
        let text = "  V48.18.2Z           FIRMWARE"
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.firmware == "V48.18.2Z")
    }

    @Test("PrinterSettings parses usage counters with commas")
    func printerSettingsParsesUsageCountersWithCommas() {
        let text = """
          111,367 IN          NONRESET CNTR
          50,234 IN           RESET CNTR1
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.nonresetCounterInches == 111367)
        #expect(settings.resetCounterInches == 50234)
    }

    @Test("PrinterSettings parses usage counters without commas")
    func printerSettingsParsesUsageCountersWithoutCommas() {
        let text = """
          500 IN              NONRESET CNTR
          200 IN              RESET CNTR1
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.nonresetCounterInches == 500)
        #expect(settings.resetCounterInches == 200)
    }

    @Test("PrinterSettings parses GX420t counter field names")
    func printerSettingsParsesGX420tCounters() {
        let text = """
          1,234 IN            TOTAL USAGE
          567 IN              HEAD USAGE
          100 IN              LAST CLEANED
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.nonresetCounterInches == 1234)
        #expect(settings.resetCounterInches == 567)
        #expect(settings.lastCleanedInches == 100)
    }

    @Test("PrinterSettings parses maximum length")
    func printerSettingsParsesMaximumLength() {
        let text = "  39.0IN   988MM      MAXIMUM LENGTH"
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.maximumLengthInches == 39.0)
    }

    @Test("PrinterSettings parses extended ZM400 full output")
    func printerSettingsParsesExtendedZM400() {
        let text = """
          31J114702349        SERIAL NUMBER
          +15                 DARKNESS
          2 IPS               PRINT SPEED
          +000                TEAR OFF
          TEAR OFF            PRINT MODE
          GAP/NOTCH           MEDIA TYPE
          TRANSMISSIVE        SENSOR SELECT
          THERMAL-TRANS.      PRINT METHOD
          812                 PRINT WIDTH
          0419                LABEL LENGTH
          39.0IN   988MM      MAXIMUM LENGTH
          V53.17.24Z <-       FIRMWARE
          111,367 IN          NONRESET CNTR
          50,234 IN           RESET CNTR1
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.serialNumber == "31J114702349")
        #expect(settings.darkness == 15)
        #expect(settings.printSpeed == 2)
        #expect(settings.mediaType == .thermalTransfer)
        #expect(settings.mediaTracking == .gap)
        #expect(settings.printWidthDots == 812)
        #expect(settings.labelLengthDots == 419)
        #expect(settings.maximumLengthInches == 39.0)
        #expect(settings.firmware == "V53.17.24Z")
        #expect(settings.nonresetCounterInches == 111367)
        #expect(settings.resetCounterInches == 50234)
    }

    @Test("PrinterSettings parses extended GX420t full output")
    func printerSettingsParsesExtendedGX420t() {
        let text = """
          ABC12345678         SERIAL NUMBER
          05.0                DARKNESS
          4 IPS               PRINT SPEED
          +000                TEAR OFF
          TEAR OFF            PRINT MODE
          CONTINUOUS          MEDIA TYPE
          WEB                 SENSOR TYPE
          MANUAL              SENSOR SELECT
          THERMAL-TRANS.      PRINT METHOD
          812                 PRINT WIDTH
          0406                LABEL LENGTH
          V48.18.2Z           FIRMWARE
          1,234 IN            TOTAL USAGE
          567 IN              HEAD USAGE
          100 IN              LAST CLEANED
        """
        let settings = PrinterSettings.parse(from: text)
        #expect(settings.serialNumber == "ABC12345678")
        #expect(settings.darkness == 5)
        #expect(settings.printSpeed == 4)
        #expect(settings.mediaType == .thermalTransfer)
        #expect(settings.mediaTracking == .continuous)
        #expect(settings.printWidthDots == 812)
        #expect(settings.labelLengthDots == 406)
        #expect(settings.firmware == "V48.18.2Z")
        #expect(settings.nonresetCounterInches == 1234)
        #expect(settings.resetCounterInches == 567)
        #expect(settings.lastCleanedInches == 100)
    }

    @Test("PrinterSettings Codable round-trip with diagnostic fields")
    func printerSettingsCodableWithDiagnostics() throws {
        var settings = PrinterSettings()
        settings.darkness = 20
        settings.printSpeed = 6
        settings.mediaType = .thermalTransfer
        settings.mediaTracking = .gap
        settings.printWidthDots = 832
        settings.labelLengthDots = 1218
        settings.printMode = .tearOff
        settings.tearOffAdjust = 16
        settings.serialNumber = "31J114702349"
        settings.firmware = "V53.17.24Z"
        settings.nonresetCounterInches = 111367
        settings.resetCounterInches = 50234
        settings.lastCleanedInches = 200
        settings.maximumLengthInches = 39.0

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(PrinterSettings.self, from: data)

        #expect(decoded == settings)
    }

    @Test("PrinterSettings description includes diagnostic fields")
    func printerSettingsDescriptionWithDiagnostics() {
        var settings = PrinterSettings()
        settings.serialNumber = "ABC123"
        settings.firmware = "V1.0"
        settings.nonresetCounterInches = 5000
        settings.resetCounterInches = 1000
        settings.lastCleanedInches = 200
        settings.maximumLengthInches = 39.0

        let desc = settings.description
        #expect(desc.contains("serial: ABC123"))
        #expect(desc.contains("firmware: V1.0"))
        #expect(desc.contains("lifetime: 5000"))
        #expect(desc.contains("head usage: 1000"))
        #expect(desc.contains("last cleaned: 200"))
        #expect(desc.contains("max length: 39.0"))
    }
}
