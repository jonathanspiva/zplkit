import Foundation
import Testing
@testable import ZPLKitPrinter

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
    }

    @Test("ZPLPrinterBrowser service type is correct")
    func browserServiceType() {
        #expect(ZPLPrinterBrowser.serviceType == "_pdl-datastream._tcp")
    }

    // MARK: - Network Error Tests

    @Test("ZPLPrinter times out on non-routable address")
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

    @Test("ZPLPrinter fails on connection refused")
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

    @Test("ZPLPrinterBrowser starts and stops without crashing")
    func browserLifecycle() {
        let browser = ZPLPrinterBrowser()

        // Start browsing
        browser.start()

        // Should be able to get empty list immediately
        let printers = browser.discoveredPrinters
        #expect(printers.isEmpty || !printers.isEmpty)  // Just verify it doesn't crash

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

    @Test("ZPLPrinterBrowser can restart after stop")
    func browserRestart() {
        let browser = ZPLPrinterBrowser()

        browser.start()
        browser.stop()
        browser.start()
        browser.stop()

        // Should complete without crashing
    }

    // MARK: - Query (Bidirectional) Tests

    @Test("ZPLPrinter query times out on non-routable address")
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

    @Test("ZPLPrinter query fails on connection refused")
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

    @Test("ZPLPrinter query static method works with discovered printer")
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
}
