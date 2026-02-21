/// The type of media (label stock) installed in the printer.
///
/// This controls whether the printer uses its thermal print head alone
/// (direct thermal) or presses a ribbon against the media (thermal transfer).
///
/// Maps to ZPL command `^MT`.
@frozen public enum MediaType: String, Sendable, Codable, CaseIterable {
    /// Direct thermal media (heat-sensitive, no ribbon needed).
    case directThermal = "D"

    /// Thermal transfer media (requires ribbon).
    case thermalTransfer = "T"
}
