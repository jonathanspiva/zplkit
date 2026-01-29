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
}
