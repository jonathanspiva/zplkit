/// Action the printer performs on power-up or head close.
///
/// Maps to ZPL commands `^MF` (power-up action) and head close action.
@frozen public enum PowerUpAction: String, Sendable, Codable, CaseIterable {
    /// No media motion on power-up.
    case noMotion = "N"

    /// Feed media to the first web (gap/mark) after the print head.
    case feedToWeb = "F"

    /// Run a full media and ribbon sensor calibration.
    case calibrate = "C"

    /// Run a short calibration (fewer labels fed).
    case shortCalibrate = "S"

    /// Feed one label length, then calibrate.
    case feedCalibrate = "L"
}
