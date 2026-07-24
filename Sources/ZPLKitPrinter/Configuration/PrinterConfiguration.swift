/// Type-safe configuration for a Zebra printer.
///
/// `PrinterConfiguration` uses a modifier pattern (like `ZPLLabel` and `Text`) where
/// each setter returns a new copy with the modified field. Only non-nil fields generate
/// ZPL commands, so you can configure just the settings you want to change.
///
/// ## Quick Start
///
/// ```swift
/// let config = PrinterConfiguration.directThermal(
///     widthDots: 812,    // 4 inches at 203 dpi
///     lengthDots: 406    // 2 inches at 203 dpi
/// )
/// .printerName("Warehouse-01")
/// .darkness(20)
///
/// try await printer.setup(config)
/// ```
///
/// ## Modifier Pattern
///
/// All fields are optional. Only set fields produce ZPL commands:
///
/// ```swift
/// // Only changes darkness, leaves everything else alone
/// let config = PrinterConfiguration()
///     .darkness(25)
/// ```
///
/// Dimensions are in dots. Use `PrinterInfo.dotsPerMillimeter` to convert
/// from physical units:
///
/// ```swift
/// let info = try await printer.queryInfo()
/// let dpmm = info.dotsPerMillimeter
/// let config = PrinterConfiguration()
///     .printWidthDots(dpmm * 102)   // 4 inches in mm
///     .labelLengthDots(dpmm * 51)   // 2 inches in mm
/// ```
public struct PrinterConfiguration: Sendable, Equatable, Codable {

    // MARK: - Essential Settings

    /// Media type (direct thermal or thermal transfer). ZPL: `^MT`.
    public var mediaType: MediaType?

    /// How the printer detects labels on the roll. ZPL: `^MN`.
    public var mediaTracking: MediaTracking?

    /// Print width in dots. ZPL: `^PW`.
    public var printWidthDots: Int?

    /// Label length in dots. ZPL: `^LL`.
    public var labelLengthDots: Int?

    /// Print darkness (0-30, where 30 is darkest). ZPL: `~SD`.
    public var darkness: Int?

    /// Print speed in inches per second (1-14, printer-dependent). ZPL: `^PR`.
    public var printSpeedIPS: Int?

    /// Character encoding. ZPL: `^CI`. Common values: 28 = UTF-8.
    public var characterEncoding: Int?

    /// How labels are presented after printing. ZPL: `^MM`.
    public var printMode: PrintMode?

    // MARK: - Advanced Settings

    /// Which sensor to use for media detection. ZPL: `^JS`.
    public var sensorType: SensorType?

    /// Default print orientation. ZPL: `^PO`.
    public var orientation: PrintOrientation?

    /// Default field rotation for all fields. ZPL: `^FW`.
    public var fieldRotation: FieldRotation?

    /// Slew speed in inches per second. ZPL: `^PR` (second parameter).
    public var slewSpeedIPS: Int?

    /// Backfeed speed in inches per second. ZPL: `^PR` (third parameter).
    public var backfeedSpeedIPS: Int?

    /// Tear-off position adjustment in dots (-120 to 120). ZPL: `~TA`.
    public var tearOffAdjust: Int?

    /// Label home position X offset in dots. ZPL: `^LH`.
    public var labelHomeX: Int?

    /// Label home position Y offset in dots. ZPL: `^LH`.
    public var labelHomeY: Int?

    /// Shift all fields down by this many dots. ZPL: `^LT`.
    public var labelTopShift: Int?

    /// Shift all fields left by this many dots. ZPL: `^LS`.
    public var labelShift: Int?

    /// Action on power-up. ZPL: `^MF` (first parameter).
    public var powerUpAction: PowerUpAction?

    /// Action on head close. ZPL: `^MF` (second parameter).
    public var headCloseAction: PowerUpAction?

    /// Whether to reprint the last label after a recoverable error. ZPL: `^JZ`.
    public var reprintAfterError: Bool?

    // MARK: - Network Settings

    /// Printer name for identification. ZPL: `^KN` (within `^XA...^XZ`).
    /// Note: Some printers use the SGD `device.friendly_name` instead.
    public var printerName: String?

    /// Static IP address. ZPL: `^NS`.
    public var ipAddress: String?

    /// Subnet mask. ZPL: `^NS`.
    public var subnetMask: String?

    /// Default gateway. ZPL: `^NS`.
    public var gateway: String?

    /// Whether DHCP is enabled. ZPL: `^NS` (IP resolution parameter).
    public var dhcpEnabled: Bool?

    // MARK: - Safety Limits

    /// Maximum label length in dots (prevents runaway prints). ZPL: `^ML`.
    public var maxLabelLengthDots: Int?

    // MARK: - Initialization

    /// Creates an empty configuration. No ZPL commands will be generated
    /// until fields are set via modifier methods.
    public init() {}

    // MARK: - Modifier Methods (Essential)

    /// Sets the media type (direct thermal or thermal transfer).
    public func mediaType(_ value: MediaType) -> PrinterConfiguration {
        var copy = self
        copy.mediaType = value
        return copy
    }

    /// Sets how the printer detects labels on the roll.
    public func mediaTracking(_ value: MediaTracking) -> PrinterConfiguration {
        var copy = self
        copy.mediaTracking = value
        return copy
    }

    /// Sets the print width in dots.
    public func printWidthDots(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.printWidthDots = value
        return copy
    }

    /// Sets the label length in dots.
    public func labelLengthDots(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.labelLengthDots = value
        return copy
    }

    /// Sets the print darkness (0-30).
    public func darkness(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.darkness = max(0, min(30, value))
        return copy
    }

    /// Sets the print speed in inches per second.
    public func printSpeedIPS(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.printSpeedIPS = value
        return copy
    }

    /// Sets the character encoding (28 = UTF-8).
    public func characterEncoding(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.characterEncoding = value
        return copy
    }

    /// Sets how labels are presented after printing.
    public func printMode(_ value: PrintMode) -> PrinterConfiguration {
        var copy = self
        copy.printMode = value
        return copy
    }

    // MARK: - Modifier Methods (Advanced)

    /// Sets which sensor to use for media detection.
    public func sensorType(_ value: SensorType) -> PrinterConfiguration {
        var copy = self
        copy.sensorType = value
        return copy
    }

    /// Sets the default print orientation.
    public func orientation(_ value: PrintOrientation) -> PrinterConfiguration {
        var copy = self
        copy.orientation = value
        return copy
    }

    /// Sets the default field rotation.
    public func fieldRotation(_ value: FieldRotation) -> PrinterConfiguration {
        var copy = self
        copy.fieldRotation = value
        return copy
    }

    /// Sets the slew (non-print movement) speed in inches per second.
    public func slewSpeedIPS(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.slewSpeedIPS = value
        return copy
    }

    /// Sets the backfeed speed in inches per second.
    public func backfeedSpeedIPS(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.backfeedSpeedIPS = value
        return copy
    }

    /// Sets the tear-off position adjustment in dots (-120 to 120).
    public func tearOffAdjust(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.tearOffAdjust = max(-120, min(120, value))
        return copy
    }

    /// Sets the label home position in dots.
    public func labelHome(x: Int, y: Int) -> PrinterConfiguration {
        var copy = self
        copy.labelHomeX = x
        copy.labelHomeY = y
        return copy
    }

    /// Shifts all fields down by the given number of dots.
    public func labelTopShift(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.labelTopShift = value
        return copy
    }

    /// Shifts all fields left by the given number of dots.
    public func labelShift(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.labelShift = value
        return copy
    }

    /// Sets the action on power-up.
    public func powerUpAction(_ value: PowerUpAction) -> PrinterConfiguration {
        var copy = self
        copy.powerUpAction = value
        return copy
    }

    /// Sets the action on head close.
    public func headCloseAction(_ value: PowerUpAction) -> PrinterConfiguration {
        var copy = self
        copy.headCloseAction = value
        return copy
    }

    /// Sets whether to reprint the last label after a recoverable error.
    public func reprintAfterError(_ value: Bool) -> PrinterConfiguration {
        var copy = self
        copy.reprintAfterError = value
        return copy
    }

    // MARK: - Modifier Methods (Network)

    /// Sets the printer name for identification.
    public func printerName(_ value: String) -> PrinterConfiguration {
        var copy = self
        copy.printerName = value
        return copy
    }

    /// Sets static network configuration.
    public func networkConfig(
        ip: String,
        subnet: String = "255.255.255.0",
        gateway: String,
        dhcp: Bool = false
    ) -> PrinterConfiguration {
        var copy = self
        copy.ipAddress = ip
        copy.subnetMask = subnet
        copy.gateway = gateway
        copy.dhcpEnabled = dhcp
        return copy
    }

    /// Enables DHCP (disables static IP configuration).
    public func dhcp() -> PrinterConfiguration {
        var copy = self
        copy.dhcpEnabled = true
        return copy
    }

    // MARK: - Modifier Methods (Safety)

    /// Sets the maximum label length in dots.
    public func maxLabelLengthDots(_ value: Int) -> PrinterConfiguration {
        var copy = self
        copy.maxLabelLengthDots = value
        return copy
    }
}
