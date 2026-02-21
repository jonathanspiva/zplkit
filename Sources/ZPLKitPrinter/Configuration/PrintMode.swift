/// How printed labels are presented after printing.
///
/// Maps to ZPL command `^MM`.
@frozen public enum PrintMode: String, Sendable, Codable, CaseIterable {
    /// Tear-off mode (default). Labels advance past the tear bar.
    case tearOff = "T"

    /// Peel mode. Labels are peeled from the backing as they print.
    case peel = "P"

    /// Rewind mode. Labels are rewound onto a take-up spindle.
    case rewind = "R"

    /// Cutter mode. Labels are cut after printing.
    case cutter = "C"
}
