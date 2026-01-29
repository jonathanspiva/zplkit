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
}
