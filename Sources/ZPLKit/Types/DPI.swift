/// DPI presets matching common Zebra printers.
public enum DPI: Int, Sendable {
    case dpi152 = 152   // 6 dpmm
    case dpi203 = 203   // 8 dpmm (most common)
    case dpi300 = 300   // 12 dpmm
    case dpi600 = 600   // 24 dpmm

    /// Converts inches to dots at this DPI.
    public func dots(fromInches inches: Double) -> Int {
        Int((inches * Double(rawValue)).rounded())
    }

    /// Converts millimeters to dots at this DPI.
    public func dots(fromMM mm: Double) -> Int {
        let inches = mm / 25.4
        return dots(fromInches: inches)
    }
}
