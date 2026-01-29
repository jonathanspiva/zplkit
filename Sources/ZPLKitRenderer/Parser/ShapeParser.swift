import Foundation

/// Internal parsers for shape commands (^GB, ^GC, ^GE, ^GD)
enum ShapeParser {

    static func parseBox(_ params: String, x: Int, y: Int) -> ParsedBox? {
        let parts = params.split(separator: ",")
        guard parts.count >= 2 else { return nil }

        let width = Int(parts[0]) ?? 0
        let height = Int(parts[1]) ?? 0
        let thickness = parts.count > 2 ? (Int(parts[2]) ?? 1) : 1
        let color = parts.count > 3 ? String(parts[3]) : "B"
        let cornerRadius = parts.count > 4 ? (Int(parts[4]) ?? 0) : 0

        return ParsedBox(x: x, y: y, width: width, height: height, thickness: thickness, color: color, cornerRadius: cornerRadius)
    }

    static func parseCircle(_ params: String, x: Int, y: Int) -> ParsedCircle? {
        let parts = params.split(separator: ",")
        guard !parts.isEmpty else { return nil }

        let diameter = Int(parts[0]) ?? 0
        let thickness = parts.count > 1 ? (Int(parts[1]) ?? 1) : 1
        let color = parts.count > 2 ? String(parts[2]) : "B"

        return ParsedCircle(x: x, y: y, diameter: diameter, thickness: thickness, color: color)
    }

    static func parseEllipse(_ params: String, x: Int, y: Int) -> ParsedEllipse? {
        let parts = params.split(separator: ",")
        guard parts.count >= 2 else { return nil }

        let width = Int(parts[0]) ?? 0
        let height = Int(parts[1]) ?? 0
        let thickness = parts.count > 2 ? (Int(parts[2]) ?? 1) : 1
        let color = parts.count > 3 ? String(parts[3]) : "B"

        return ParsedEllipse(x: x, y: y, width: width, height: height, thickness: thickness, color: color)
    }

    static func parseDiagonalLine(_ params: String, x: Int, y: Int) -> ParsedDiagonalLine? {
        let parts = params.split(separator: ",")
        guard parts.count >= 2 else { return nil }

        let width = Int(parts[0]) ?? 0
        let height = Int(parts[1]) ?? 0
        let thickness = parts.count > 2 ? (Int(parts[2]) ?? 1) : 1
        let color = parts.count > 3 ? String(parts[3]) : "B"
        let direction = parts.count > 4 ? String(parts[4]) : "R"

        return ParsedDiagonalLine(x: x, y: y, width: width, height: height, thickness: thickness, color: color, direction: direction)
    }
}
