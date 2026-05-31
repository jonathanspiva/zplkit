/// One-way printer commands that can be sent over the network.
///
/// These commands are "fire and forget" - they don't return data.
/// Send the command string to the printer via TCP port 9100.
///
/// ```swift
/// let command = PrinterCommand.printNetworkConfig
/// connection.send(Data(command.zpl.utf8))
/// ```
public enum PrinterCommand: String, Sendable {
    /// Print the printer's network configuration on a label (`~WL`).
    ///
    /// Prints a label showing IP address, subnet mask, gateway, and other network settings.
    case printNetworkConfig = "~WL"

    /// Run media calibration (`~JC`).
    ///
    /// Calibrates the printer for the current media (label size, gap detection).
    /// The printer will feed several labels during calibration.
    case calibrate = "~JC"

    /// Reset the printer (`~JR`).
    ///
    /// Performs a power-on reset. The printer will restart and reload settings.
    case reset = "~JR"

    /// Cancel the current print job (`~JA`).
    ///
    /// Cancels any format currently being processed or printed.
    case cancelJob = "~JA"

    /// The ZPL command string to send to the printer.
    public var zpl: String { rawValue }
}
