import Foundation

extension ZPLPrinter {

    /// Applies a configuration to the printer by sending the generated ZPL commands.
    ///
    /// All commands (immediate and format) are concatenated into a single TCP payload
    /// so they arrive in one connection. Only non-nil fields in the configuration
    /// produce ZPL commands.
    ///
    /// The printer applies settings immediately but does not save them
    /// to non-volatile memory (use ``saveConfiguration()`` or ``setup(_:)`` for that).
    ///
    /// - Parameter configuration: The configuration to apply.
    /// - Throws: `PrinterError` if the command fails to send.
    public func apply(_ configuration: PrinterConfiguration) async throws {
        let commands = configuration.zplCommands()
        let payload = commands.joined()
        if !payload.isEmpty {
            try await send(payload)
        }
    }

    /// Saves the current printer configuration to non-volatile memory.
    ///
    /// Settings persist across power cycles after this command. ZPL: `^JUS`.
    ///
    /// - Throws: `PrinterError` if the command fails to send.
    public func saveConfiguration() async throws {
        try await send("^XA^JUS^XZ")
    }

    /// Restores configuration from non-volatile memory, discarding
    /// any unsaved changes.
    ///
    /// ZPL: `^JUR`.
    ///
    /// - Throws: `PrinterError` if the command fails to send.
    public func restoreConfiguration() async throws {
        try await send("^XA^JUR^XZ")
    }

    /// Resets the printer to factory default settings.
    ///
    /// This erases all saved configuration. ZPL: `^JUF`.
    ///
    /// - Throws: `PrinterError` if the command fails to send.
    public func factoryReset() async throws {
        try await send("^XA^JUF^XZ")
    }

    /// Runs a media and ribbon sensor calibration.
    ///
    /// The printer feeds several labels to measure the label length and set
    /// its sensor levels. This is typically needed after changing media type
    /// or label size. ZPL: `~JC`.
    ///
    /// Waits for the printer to go idle first (see ``waitUntilIdle(timeout:)``).
    /// Tilde commands run the moment they arrive, ahead of any queued formats,
    /// and a `~JC` that arrives while labels are queued calibrates ahead of
    /// them. On a GX420t (V56.17.17Z) the two queued labels then stalled until
    /// the next job arrived and printed out of register.
    ///
    /// The calibration only measures in gap or mark tracking; in continuous
    /// tracking `~JC` feeds nothing.
    ///
    /// - Parameter idleTimeout: How long to wait for queued jobs to finish.
    /// - Throws: `PrinterError.printerBusy` if the printer is still busy after
    ///   `idleTimeout`, or another `PrinterError` if a query or send fails.
    public func calibrate(idleTimeout: TimeInterval = defaultIdleTimeout) async throws {
        try await waitUntilIdle(timeout: idleTimeout)
        try await send("~JC")
    }

    /// Default for how long ``calibrate(idleTimeout:)`` and
    /// ``calibrateFull(idleTimeout:)`` wait for queued jobs to finish.
    public static let defaultIdleTimeout: TimeInterval = 60

    /// Waits until the printer has no formats queued, no partial format in
    /// progress, and no labels left in a batch.
    ///
    /// Polls ``queryStatus()``. The printer must read idle on two consecutive
    /// polls, so a format that has only just arrived is not mistaken for an
    /// empty queue.
    ///
    /// - Parameter timeout: How long to wait before giving up.
    /// - Throws: `PrinterError.printerBusy` if the printer is still busy after
    ///   `timeout` (a paused printer never drains its queue), or another
    ///   `PrinterError` if a status query fails.
    public func waitUntilIdle(timeout: TimeInterval = defaultIdleTimeout) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + .milliseconds(Int(min(max(0, timeout), 86_400) * 1000))
        var idleReadings = 0
        while true {
            let status = try await queryStatus()
            let idle = status.formatsInBuffer == 0
                && !status.isPartialFormatInProgress
                && status.labelsRemainingInBatch == 0
            idleReadings = idle ? idleReadings + 1 : 0
            if idleReadings >= 2 { return }
            if clock.now >= deadline {
                throw PrinterError.printerBusy(host: host, port: port)
            }
            try await Task.sleep(for: .milliseconds(250))
        }
    }

    /// Zero-touch printer setup: apply configuration with integrated save,
    /// then calibrate sensors.
    ///
    /// All configuration commands and the save (`^JUS`) are sent in a single
    /// TCP payload, followed by a calibration command. This is the recommended
    /// way to configure a new or factory-reset printer.
    ///
    /// ```swift
    /// let config = PrinterConfiguration.directThermal(
    ///     widthDots: 812,
    ///     lengthDots: 406
    /// )
    /// try await printer.setup(config)
    /// ```
    ///
    /// - Parameter configuration: The configuration to apply, save, and calibrate.
    /// - Throws: `PrinterError` if any step fails.
    public func setup(_ configuration: PrinterConfiguration) async throws {
        let commands = configuration.zplCommands(save: true)
        let payload = commands.joined()
        if !payload.isEmpty {
            try await send(payload)
        }
        try await calibrate()
    }

    // MARK: - Printer Control

    /// Toggles the printer's pause state.
    ///
    /// If the printer is running, it pauses. If paused, it resumes. ZPL: `~PP`.
    ///
    /// - Throws: `PrinterError` if the command fails to send.
    public func togglePause() async throws {
        try await send("~PP")
    }

    /// Cancels all pending print jobs in the buffer.
    ///
    /// ZPL: `~JA`.
    ///
    /// - Throws: `PrinterError` if the command fails to send.
    public func cancelAll() async throws {
        try await send("~JA")
    }

    /// Feeds one blank label.
    ///
    /// Sends an empty format block which causes the printer to advance one label.
    ///
    /// - Throws: `PrinterError` if the command fails to send.
    public func feedLabel() async throws {
        try await send("^XA^XZ")
    }

    /// Runs a graphing sensor calibration: the same measurement as
    /// ``calibrate(idleTimeout:)``, plus a printed graph of the media sensor
    /// profile. ZPL: `~JG`.
    ///
    /// Use it to diagnose sensor or registration problems; the graph costs
    /// several extra labels. It is not a more thorough calibration than `~JC`.
    /// Waits for the printer to go idle first, for the same reason as
    /// ``calibrate(idleTimeout:)``.
    ///
    /// - Parameter idleTimeout: How long to wait for queued jobs to finish.
    /// - Throws: `PrinterError.printerBusy` if the printer is still busy after
    ///   `idleTimeout`, or another `PrinterError` if a query or send fails.
    public func calibrateFull(idleTimeout: TimeInterval = defaultIdleTimeout) async throws {
        try await waitUntilIdle(timeout: idleTimeout)
        try await send("~JG")
    }

    /// Performs a power-on reset.
    ///
    /// The printer restarts as if power-cycled. The TCP connection will be lost.
    /// ZPL: `~JR`.
    ///
    /// - Throws: `PrinterError` if the command fails to send.
    public func powerOnReset() async throws {
        try await send("~JR")
    }

    // MARK: - Configuration Readback

    /// Queries the printer's full configuration as raw text using `^HH`.
    ///
    /// The `^HH` command causes the printer to send its complete configuration
    /// back to the host as text. This is useful for debugging and discovering
    /// what settings a printer has.
    ///
    /// - Parameter responseTimeout: Time to wait for response. Defaults to 15 seconds
    ///   since `^HH` returns a large response.
    /// - Returns: The raw configuration text from the printer.
    /// - Throws: `PrinterError` if the query fails.
    public func queryConfigurationRaw(responseTimeout: TimeInterval = 15) async throws -> String {
        let data = try await query("^XA^HH^XZ", responseTimeout: responseTimeout)
        guard let text = String(data: data, encoding: .utf8) else {
            throw PrinterError.invalidResponse("^HH response could not be decoded as UTF-8")
        }
        return text
    }

    /// Queries the printer's configuration and parses it into a ``PrinterSettings`` struct.
    ///
    /// Sends `^HH` and parses the response into structured fields. The `^HH` response
    /// format varies by printer generation, so some fields may be nil if the parser
    /// doesn't recognize the format.
    ///
    /// - Parameter responseTimeout: Time to wait for response. Defaults to 15 seconds.
    /// - Returns: Parsed printer settings.
    /// - Throws: `PrinterError` if the query fails or response cannot be parsed.
    public func queryConfiguration(responseTimeout: TimeInterval = 15) async throws -> PrinterSettings {
        let data = try await query("^XA^HH^XZ", responseTimeout: responseTimeout)
        return try PrinterSettings.parse(from: data)
    }

    // MARK: - Aggregate Diagnostics

    /// Queries a complete diagnostic snapshot from the printer.
    ///
    /// Runs `~HI`, `~HS`, and `~HM` sequentially, then attempts `^HH` for
    /// extended settings. If `^HH` times out (common when the printer is in
    /// an error state), the ``PrinterDiagnostics/settings`` field will be nil.
    ///
    /// The queries run one at a time rather than concurrently: many older Zebra
    /// printers (e.g. GX420t, ZM400) accept only one or two simultaneous
    /// connections on port 9100, so firing all three at once can stall or fail.
    /// Each query opens and closes its own connection.
    ///
    /// - Returns: Aggregate diagnostics including info, status, memory, and settings.
    /// - Throws: `PrinterError` if any of the required queries (`~HI`, `~HS`, `~HM`) fail.
    public func queryDiagnostics() async throws -> PrinterDiagnostics {
        let info = try await queryInfo()
        let status = try await queryStatus()
        let memory = try await queryMemory()

        // ^HH can timeout when the printer is in an error state, so a failure
        // here degrades to settings == nil rather than failing the snapshot.
        // Cancellation must still propagate: swallowing CancellationError would
        // return a "successful" result from a cancelled task.
        let settings: PrinterSettings?
        do {
            settings = try await queryConfiguration()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            settings = nil
        }

        return PrinterDiagnostics(
            info: info,
            status: status,
            memory: memory,
            settings: settings
        )
    }
}
