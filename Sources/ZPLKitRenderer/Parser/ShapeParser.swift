import Foundation

/// Internal parsers for shape commands (^GB, ^GC, ^GE, ^GD)
enum ShapeParser {

    static func parseBox(_ params: String, x: Int, y: Int) -> ParsedBox? {
        let parts = ZPLParser.splitParams(params)
        guard parts.count >= 2 else { return nil }

        let width = Int(parts[0]) ?? 0
        let height = Int(parts[1]) ?? 0
        let thickness = parts[safe: 2].flatMap(Int.init) ?? 1
        let color = nonEmpty(parts[safe: 3]) ?? "B"
        let cornerRadius = parts[safe: 4].flatMap(Int.init) ?? 0

        return ParsedBox(x: x, y: y, width: width, height: height, thickness: thickness, color: color, cornerRadius: cornerRadius)
    }

    static func parseCircle(_ params: String, x: Int, y: Int) -> ParsedCircle? {
        let parts = ZPLParser.splitParams(params)
        guard !parts.isEmpty else { return nil }

        let diameter = Int(parts[0]) ?? 0
        let thickness = parts[safe: 1].flatMap(Int.init) ?? 1
        let color = nonEmpty(parts[safe: 2]) ?? "B"

        return ParsedCircle(x: x, y: y, diameter: diameter, thickness: thickness, color: color)
    }

    static func parseEllipse(_ params: String, x: Int, y: Int) -> ParsedEllipse? {
        let parts = ZPLParser.splitParams(params)
        guard parts.count >= 2 else { return nil }

        let width = Int(parts[0]) ?? 0
        let height = Int(parts[1]) ?? 0
        let thickness = parts[safe: 2].flatMap(Int.init) ?? 1
        let color = nonEmpty(parts[safe: 3]) ?? "B"

        return ParsedEllipse(x: x, y: y, width: width, height: height, thickness: thickness, color: color)
    }

    static func parseDiagonalLine(_ params: String, x: Int, y: Int) -> ParsedDiagonalLine? {
        let parts = ZPLParser.splitParams(params)
        guard parts.count >= 2 else { return nil }

        let width = Int(parts[0]) ?? 0
        let height = Int(parts[1]) ?? 0
        let thickness = parts[safe: 2].flatMap(Int.init) ?? 1
        let color = nonEmpty(parts[safe: 3]) ?? "B"
        let direction = nonEmpty(parts[safe: 4]) ?? "R"

        return ParsedDiagonalLine(x: x, y: y, width: width, height: height, thickness: thickness, color: color, direction: direction)
    }

    /// Empty parameter slots mean "use the default".
    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
