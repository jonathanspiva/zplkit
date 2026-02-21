extension ZPLPrinter {

    /// Applies a configuration to the printer by sending the generated ZPL commands.
    ///
    /// Only non-nil fields in the configuration produce ZPL commands.
    /// The printer applies settings immediately but does not save them
    /// to non-volatile memory (use ``saveConfiguration()`` or ``setup(_:)`` for that).
    ///
    /// - Parameter configuration: The configuration to apply.
    /// - Throws: `PrinterError` if any command fails to send.
    public func apply(_ configuration: PrinterConfiguration) async throws {
        let commands = configuration.zplCommands()
        for command in commands {
            try await send(command)
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
    /// The printer feeds several labels to calibrate its sensors.
    /// This is typically needed after changing media type or label size.
    /// ZPL: `~JC`.
    ///
    /// - Throws: `PrinterError` if the command fails to send.
    public func calibrate() async throws {
        try await send("~JC")
    }

    /// Zero-touch printer setup: apply configuration, save to non-volatile
    /// memory, and calibrate sensors.
    ///
    /// This is the recommended way to configure a new or factory-reset printer.
    /// It combines ``apply(_:)``, ``saveConfiguration()``, and ``calibrate()``
    /// into a single call.
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
        try await apply(configuration)
        try await saveConfiguration()
        try await calibrate()
    }
}
