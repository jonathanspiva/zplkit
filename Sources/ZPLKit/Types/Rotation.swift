/// Field rotation options for text and barcodes.
public enum Rotation: String, Sendable {
    case normal = "N"       // 0 degrees
    case rotated90 = "R"    // 90 degrees clockwise
    case inverted = "I"     // 180 degrees
    case rotated270 = "B"   // 270 degrees clockwise
}
