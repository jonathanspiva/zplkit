import Foundation
import Testing
@testable import ZPLKitPrinter

/// Loopback round-trip tests for the network code in `ZPLPrinter`,
/// `ZPLPrinter+Configuration`, and `PrinterDiagnostics`.
///
/// Each test stands up its own `FakePrinter` on an ephemeral `127.0.0.1` port
/// and tears it down via `defer`, so ports / fds never leak between tests and
/// nothing requires real hardware or an env-var gate. These exercise the same
/// code paths the hardware-gated `LivePrinterTests` cover, but hermetically.
///
/// The suite is `.serialized`: NWConnection's first use in a process pays a
/// multi-second cold-start on slow machines (GitHub Actions macOS runners
/// especially), and a dozen concurrent connect attempts all stall behind it
/// and time out together. Serial execution lets the first query pay that cost
/// once while the rest stay fast.
@Suite("Network Round-Trip Tests", .serialized)
struct NetworkRoundTripTests {

    /// Timeout for operations that are expected to succeed. Generous because
    /// CI runners pay NWConnection cold-start latency measured in seconds; a
    /// passing test never waits this long, it only bounds a failing one.
    private let successTimeout: TimeInterval = 15

    // MARK: - send(): payload integrity

    @Test("send() delivers the exact ZPL payload")
    func sendDeliversExactPayload() async throws {
        let fake = try FakePrinter(defaultBehavior: .drainThenClose)
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        let zpl = "^XA^FO50,50^A0N,40,40^FDHello^FS^XZ"
        try await printer.send(zpl)

        // Give the server thread a moment to drain after the clean FIN.
        try await waitUntil { fake.received.count >= zpl.utf8.count }
        #expect(fake.receivedString == zpl)
    }

    @Test("send() handles a large multi-KB payload (partial-write loop)")
    func sendLargePayload() async throws {
        let fake = try FakePrinter(defaultBehavior: .drainThenClose)
        defer { fake.shutdown() }

        // ~256 KB exercises the write() loop that handles short writes.
        let body = String(repeating: "A", count: 256 * 1024)
        let zpl = "^XA^FO0,0^FD\(body)^FS^XZ"

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        try await printer.send(zpl)

        try await waitUntil(timeout: 5) { fake.received.count >= zpl.utf8.count }
        #expect(fake.received.count == zpl.utf8.count)
        #expect(fake.receivedString == zpl)
    }

    @Test("send() returns normally on a graceful server close")
    func sendGracefulClose() async throws {
        let fake = try FakePrinter(defaultBehavior: .drainThenClose)
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        // Should not throw.
        try await printer.send("~HS")
        // send() returns once the client write+close complete, which can be
        // before the server thread accepts; wait for the accept to register.
        try await waitUntil { fake.connectionCount >= 1 }
        #expect(fake.connectionCount >= 1)
    }

    @Test("send() of an empty payload is a no-op success")
    func sendEmpty() async throws {
        let fake = try FakePrinter(defaultBehavior: .drainThenClose)
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        try await printer.send(Data())
        #expect(fake.connectionCount == 0)  // no connection opened for empty data
    }

    // MARK: - send(): error paths

    @Test("send() to a closed port throws connectionFailed")
    func sendConnectionRefused() async throws {
        // Bind then immediately shut down to obtain a port nothing listens on.
        let fake = try FakePrinter()
        let deadPort = fake.port
        fake.shutdown()

        let printer = ZPLPrinter(host: "127.0.0.1", port: deadPort, timeout: successTimeout)
        await #expect(throws: PrinterError.self) {
            try await printer.send("^XA^XZ")
        }
    }

    @Test("send() to an invalid (zero) port throws invalidConfiguration")
    func sendZeroPort() async throws {
        let printer = ZPLPrinter(host: "127.0.0.1", port: 0, timeout: successTimeout)
        do {
            try await printer.send("^XA^XZ")
            Issue.record("expected send() to throw for port 0")
        } catch let error as PrinterError {
            guard case .invalidConfiguration = error else {
                Issue.record("expected invalidConfiguration, got \(error)")
                return
            }
        }
    }

    @Test("send() succeeds even if the server closes immediately after accept")
    func sendServerClosesImmediately() async throws {
        // The kernel buffers the small payload before the server's close(), so
        // the client's write() succeeds; this asserts send() does not spuriously
        // throw on a fast server-side close. (A throw here would also be a valid
        // PrinterError; we accept either, but the common case is success.)
        let fake = try FakePrinter(defaultBehavior: .closeImmediately)
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        do {
            try await printer.send("^XA^XZ")
        } catch let error as PrinterError {
            // A reset before the write lands is also acceptable.
            if case .sendFailed = error {} else if case .connectionFailed = error {} else {
                Issue.record("unexpected error: \(error)")
            }
        }
    }

    // MARK: - query(): single-frame responses

    @Test("queryInfo() parses a ~HI response into PrinterInfo")
    func queryInfoRoundTrip() async throws {
        let response = FakePrinter.makeHIResponse(
            model: "ZM400-200dpi", firmware: "V53.17.14Z",
            dotsPerMillimeter: 8, memoryKB: 49152, options: "NONE")
        let fake = try FakePrinter(behaviors: [.respond(chunks: [response], gap: 0)])
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        let info = try await printer.queryInfo(responseTimeout: successTimeout)

        #expect(info.model == "ZM400-200dpi")
        #expect(info.firmwareVersion == "V53.17.14Z")
        #expect(info.dotsPerMillimeter == 8)
        #expect(info.dpi == 203)
        #expect(info.memoryKB == 49152)
        // The exact command bytes reached the server.
        #expect(fake.receivedString.contains("~HI"))
    }

    @Test("queryMemory() parses a ~HM response into MemoryStatus")
    func queryMemoryRoundTrip() async throws {
        let response = FakePrinter.makeHMResponse(
            total: 2097152, maximum: 2097152, available: 1847296)
        let fake = try FakePrinter(behaviors: [.respond(chunks: [response], gap: 0)])
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        let memory = try await printer.queryMemory(responseTimeout: successTimeout)

        #expect(memory.total == 2097152)
        #expect(memory.maximum == 2097152)
        #expect(memory.available == 1847296)
        #expect(fake.receivedString.contains("~HM"))
    }

    @Test("queryConfiguration() parses a ^HH response into PrinterSettings")
    func queryConfigurationRoundTrip() async throws {
        let response = FakePrinter.makeHHResponse(
            darkness: 15, printSpeed: 4, serial: "50J000000001",
            firmware: "V53.17.14Z", printWidth: 832, labelLength: 1218)
        let fake = try FakePrinter(behaviors: [.respond(chunks: [response], gap: 0)])
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        let settings = try await printer.queryConfiguration(responseTimeout: successTimeout)

        #expect(settings.darkness == 15)
        #expect(settings.printSpeed == 4)
        #expect(settings.serialNumber == "50J000000001")
        #expect(settings.firmware == "V53.17.14Z")
        #expect(settings.printWidthDots == 832)
        #expect(settings.labelLengthDots == 1218)
        #expect(settings.nonresetCounterInches == 111367)
        #expect(fake.receivedString.contains("^HH"))
    }

    // MARK: - query(): multi-frame ~HS

    @Test("queryStatus() parses a single-write three-frame ~HS")
    func queryStatusSingleWrite() async throws {
        let frames = FakePrinter.makeHSResponse(thermalTransfer: true, labelsRemaining: 0)
        var combined = Data()
        for f in frames { combined.append(f) }
        let fake = try FakePrinter(behaviors: [.respond(chunks: [combined], gap: 0)])
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        let status = try await printer.queryStatus(responseTimeout: successTimeout)

        #expect(status.isReadyToPrint)
        #expect(status.isThermalTransfer == true)
        #expect(fake.receivedString.contains("~HS"))
    }

    @Test("queryStatus() waits for all 3 ~HS frames sent in separate segments")
    func queryStatusMultiSegment() async throws {
        // Send the three frames as separate writes with a small gap so they
        // land in distinct TCP segments. This validates that query() does NOT
        // complete on the first ETX and waits for all three frames.
        let frames = FakePrinter.makeHSResponse(
            paperOut: false, paused: false, thermalTransfer: true)
        let fake = try FakePrinter(
            behaviors: [.respond(chunks: frames, gap: 0.08)])
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        let status = try await printer.queryStatus(responseTimeout: successTimeout)

        #expect(status.isReadyToPrint)
        #expect(status.isThermalTransfer == true)
        #expect(status.isPaperOut == false)
    }

    @Test("queryStatus() does not prematurely complete on a single ~HS frame")
    func queryStatusSingleFramePartial() async throws {
        // Send only the FIRST of the three ~HS frames. Because isStatusQuery is
        // true, query() requires 3 ETX frames and must NOT complete on this
        // single ETX. The .respond behavior closes the connection after writing
        // the one frame; query() then returns the 1-frame buffer on graceful
        // close, which PrinterStatus.parse rejects (needs >= 2 strings) ->
        // invalidResponse. This proves the single ETX did not satisfy the
        // 3-frame completion check.
        let frames = FakePrinter.makeHSResponse()
        let fake = try FakePrinter(
            behaviors: [.respond(chunks: [frames[0]], gap: 0)])
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        await #expect(throws: PrinterError.self) {
            _ = try await printer.queryStatus(responseTimeout: 3)
        }
    }

    // MARK: - query(): timeout edge cases

    @Test("query() accepts an infinite timeout without trapping")
    func queryInfiniteTimeout() async throws {
        // .infinity used to trap in the seconds->nanoseconds conversion
        // (rounds up to exactly 2^64); it now clamps to the 1-day ceiling.
        let fake = try FakePrinter(behaviors: [.respond(chunks: [FakePrinter.makeHIResponse()], gap: 0)])
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: .infinity)
        let info = try await printer.queryInfo(responseTimeout: .infinity)
        #expect(info.dotsPerMillimeter == 8)
    }

    @Test("queryConfiguration() completes on the trailing ^HH ETX, not the idle timer")
    func hhCompletesOnTrailingETX() async throws {
        let fake = try FakePrinterRouting()
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        // Warm up NWConnection so cold-start doesn't pollute the timing below.
        _ = try await printer.queryInfo(responseTimeout: successTimeout)

        let start = DispatchTime.now().uptimeNanoseconds
        _ = try await printer.queryConfiguration(responseTimeout: successTimeout)
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000
        // The idle-timer fallback waits >= 1s after the last byte; completing
        // on the trailing ETX (real ^HH dumps end 0x0D 0x0A 0x03) returns in
        // milliseconds.
        #expect(elapsed < 0.9, "took \(elapsed)s; idle-timer fallback suspected")
    }

    // MARK: - query(): timeout

    @Test("query() times out when the server accepts but never replies")
    func queryResponseTimeout() async throws {
        let fake = try FakePrinter(defaultBehavior: .silent)
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        do {
            _ = try await printer.query("~HI", responseTimeout: 1)
            Issue.record("expected a response timeout")
        } catch let error as PrinterError {
            guard case .responseTimeout = error else {
                Issue.record("expected responseTimeout, got \(error)")
                return
            }
        }
    }

    // MARK: - query(): cancellation

    @Test("query() cancellation throws promptly, not after the full timeout")
    func queryCancellation() async throws {
        let fake = try FakePrinter(defaultBehavior: .silent)
        defer { fake.shutdown() }

        // Long timeouts so cancellation, not timeout, is what completes the call.
        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: 30)

        let start = DispatchTime.now()
        let task = Task { () -> Data in
            try await printer.query("~HI", responseTimeout: 30)
        }

        // Let the connection establish and the command go out, then cancel.
        try await Task.sleep(nanoseconds: 300_000_000)
        task.cancel()

        var threwCancellation = false
        do {
            _ = try await task.value
            Issue.record("expected the cancelled query to throw")
        } catch is CancellationError {
            threwCancellation = true
        } catch {
            // NWConnection cancellation can also surface as a PrinterError if a
            // receive/connection callback wins the race; accept either as long
            // as it returns promptly rather than hanging for 30s.
        }

        let elapsedNanos = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
        let elapsed = Double(elapsedNanos) / 1_000_000_000
        // Should resolve well before the 30s timeout.
        #expect(elapsed < 10, "cancellation took \(elapsed)s; expected prompt resolution")
        // Document the expected path even if a benign race produced a PrinterError.
        _ = threwCancellation
    }

    // MARK: - ZPLPrinter+Configuration: apply / setup

    @Test("apply() sends the expected configuration ZPL in one payload")
    func applySendsConfigZPL() async throws {
        let fake = try FakePrinter(defaultBehavior: .drainThenClose)
        defer { fake.shutdown() }

        let config = PrinterConfiguration.directThermal(
            widthDots: 812, lengthDots: 406, darkness: 12, speedIPS: 4)
        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        try await printer.apply(config)

        let expected = config.zplCommands().joined()
        try await waitUntil { fake.received.count >= expected.utf8.count }
        let sent = fake.receivedString
        #expect(sent == expected)
        // Spot-check the key commands are present.
        #expect(sent.contains("^XA"))
        #expect(sent.contains("^XZ"))
        #expect(sent.contains("~SD12"))     // darkness immediate command
        #expect(sent.contains("^MT"))       // media type
        #expect(sent.contains("^PW812"))    // print width
        // apply() does NOT save.
        #expect(!sent.contains("^JUS"))
    }

    @Test("setup() applies+saves in one payload, then calibrates")
    func setupAppliesSavesAndCalibrates() async throws {
        // setup() opens TWO connections: the config+save payload, then ~JC.
        let fake = try FakePrinter(defaultBehavior: .drainThenClose)
        defer { fake.shutdown() }

        let config = PrinterConfiguration.directThermal(
            widthDots: 812, lengthDots: 406)
        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        try await printer.setup(config)

        // Wait for the calibrate bytes themselves, not just the second
        // connection's accept(): connectionCount can reach 2 before the
        // calibrate payload has been read and recorded, which would race the
        // assertions below.
        try await waitUntil { fake.receivedString.contains("~JC") }
        let sent = fake.receivedString
        #expect(sent.contains("^JUS"))   // save is included
        #expect(sent.contains("~JC"))    // calibration command sent
        #expect(sent.contains("^XA"))
        #expect(sent.contains("^XZ"))
        #expect(fake.connectionCount == 2)
    }

    @Test("saveConfiguration() sends ^XA^JUS^XZ")
    func saveConfigurationZPL() async throws {
        let fake = try FakePrinter(defaultBehavior: .drainThenClose)
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        try await printer.saveConfiguration()

        try await waitUntil { fake.received.count >= 10 }
        #expect(fake.receivedString == "^XA^JUS^XZ")
    }

    // MARK: - queryDiagnostics aggregate

    @Test("queryDiagnostics() populates a full PrinterDiagnostics")
    func queryDiagnosticsRoundTrip() async throws {
        // queryDiagnostics() runs ~HI, ~HS, ~HM concurrently, then ^HH.
        // Each runs on its OWN connection. Because the three concurrent queries
        // race, route by request content rather than by a fixed behavior queue.
        let fake = try FakePrinterRouting()
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        let diag = try await printer.queryDiagnostics()

        #expect(diag.info.model == "ZM400-200dpi")
        #expect(diag.status.isReadyToPrint)
        #expect(diag.memory.total == 2097152)
        #expect(diag.settings != nil)
        #expect(diag.serialNumber == "50J000000001")
        #expect(diag.lifetimeUsageInches == 111367)
    }

    @Test("queryDiagnostics() leaves settings nil when ^HH yields no response")
    func queryDiagnosticsHHEmpty() async throws {
        // Answer ~HI/~HS/~HM but close the ^HH connection with no reply. A
        // graceful close with an empty buffer surfaces as responseTimeout,
        // which queryDiagnostics catches -> settings == nil. (We close rather
        // than stay silent so the test stays fast; queryConfiguration's default
        // 15s response timeout is never reached.)
        let fake = try FakePrinterRouting(answerHH: false)
        defer { fake.shutdown() }

        let printer = ZPLPrinter(host: "127.0.0.1", port: fake.port, timeout: successTimeout)
        let diag = try await printer.queryDiagnostics()

        #expect(diag.info.model == "ZM400-200dpi")
        #expect(diag.status.isReadyToPrint)
        #expect(diag.memory.total == 2097152)
        #expect(diag.settings == nil)
    }

    // MARK: - Helpers

    /// Polls `condition` until true or `timeout` elapses, yielding between
    /// checks. Used to wait for the background server thread to record bytes
    /// or accept connections without sleeping a fixed duration.
    private func waitUntil(
        timeout: TimeInterval = 10,
        _ condition: @Sendable () -> Bool
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + UInt64(timeout * 1_000_000_000)
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
        }
        // One final check before giving up.
        if condition() { return }
    }
}
