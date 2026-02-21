extension PrinterConfiguration {

    /// Creates a configuration preset for direct thermal printing.
    ///
    /// Sets media type, tracking, dimensions, and sensible defaults for
    /// direct thermal labels (the most common label printer setup).
    ///
    /// - Parameters:
    ///   - widthDots: Print width in dots.
    ///   - lengthDots: Label length in dots.
    ///   - darkness: Print darkness (0-30). Defaults to 15.
    ///   - speedIPS: Print speed in inches per second. Defaults to 4.
    /// - Returns: A configured `PrinterConfiguration`.
    public static func directThermal(
        widthDots: Int,
        lengthDots: Int,
        darkness: Int = 15,
        speedIPS: Int = 4
    ) -> PrinterConfiguration {
        var config = PrinterConfiguration()
        config.mediaType = .directThermal
        config.mediaTracking = .gap
        config.printWidthDots = widthDots
        config.labelLengthDots = lengthDots
        config.darkness = max(0, min(30, darkness))
        config.printSpeedIPS = speedIPS
        config.characterEncoding = 28  // UTF-8
        config.printMode = .tearOff
        return config
    }

    /// Creates a configuration preset for thermal transfer printing.
    ///
    /// Sets media type, tracking, dimensions, and sensible defaults for
    /// thermal transfer labels (requires ribbon).
    ///
    /// - Parameters:
    ///   - widthDots: Print width in dots.
    ///   - lengthDots: Label length in dots.
    ///   - darkness: Print darkness (0-30). Defaults to 15.
    ///   - speedIPS: Print speed in inches per second. Defaults to 4.
    /// - Returns: A configured `PrinterConfiguration`.
    public static func thermalTransfer(
        widthDots: Int,
        lengthDots: Int,
        darkness: Int = 15,
        speedIPS: Int = 4
    ) -> PrinterConfiguration {
        var config = PrinterConfiguration()
        config.mediaType = .thermalTransfer
        config.mediaTracking = .gap
        config.printWidthDots = widthDots
        config.labelLengthDots = lengthDots
        config.darkness = max(0, min(30, darkness))
        config.printSpeedIPS = speedIPS
        config.characterEncoding = 28  // UTF-8
        config.printMode = .tearOff
        return config
    }
}
