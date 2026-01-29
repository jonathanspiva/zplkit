import Foundation

/// A ZPL label that contains elements and renders to a ZPL string.
public struct ZPLLabel: Sendable {
    /// Label width in inches.
    public let width: Double

    /// Label height in inches.
    public let height: Double

    /// Target printer DPI.
    public let dpi: DPI

    /// Elements on this label.
    private let elements: [ZPLElement]

    /// Print quantity (default 1).
    private var quantity: Int = 1

    /// Default font for the label.
    private var defaultFont: (font: ZPLFont, height: Int)?

    /// Label home position offset.
    private var labelHome: (x: Int, y: Int)?

    /// Print darkness (0-30).
    private var darkness: Int?

    /// Print speed settings (print, slew, backfeed).
    private var printSpeed: (print: Int, slew: Int?, backfeed: Int?)?

    /// Creates a new label with the given dimensions and content.
    /// - Parameters:
    ///   - width: Label width in inches.
    ///   - height: Label height in inches.
    ///   - dpi: Target printer DPI (default: 203).
    ///   - content: A result builder closure that defines the label elements.
    public init(
        width: Double,
        height: Double,
        dpi: DPI = .dpi203,
        @ZPLBuilder content: () -> [ZPLElement]
    ) {
        self.width = width
        self.height = height
        self.dpi = dpi
        self.elements = content()
    }

    /// Sets the print quantity.
    public func printQuantity(_ count: Int) -> ZPLLabel {
        var copy = self
        copy.quantity = max(1, count)
        return copy
    }

    /// Sets the default font for the label.
    public func defaultFont(_ font: ZPLFont, height: Int) -> ZPLLabel {
        var copy = self
        copy.defaultFont = (font, height)
        return copy
    }

    /// Sets the label home position.
    public func labelHome(_ x: Int, _ y: Int) -> ZPLLabel {
        var copy = self
        copy.labelHome = (x, y)
        return copy
    }

    /// Sets the print darkness (0-30).
    public func printDarkness(_ level: Int) -> ZPLLabel {
        var copy = self
        copy.darkness = min(30, max(0, level))
        return copy
    }

    /// Sets the print speed.
    ///
    /// Speed values typically range from 1-14, but vary by printer model.
    /// Higher values = faster printing but potentially lower quality.
    ///
    /// - Parameters:
    ///   - speed: Print speed (inches per second, typically 1-14)
    ///   - slew: Slew speed for non-print movement (optional, defaults to print speed)
    ///   - backfeed: Backfeed speed (optional, defaults to print speed)
    public func printSpeed(_ speed: Int, slew: Int? = nil, backfeed: Int? = nil) -> ZPLLabel {
        var copy = self
        copy.printSpeed = (print: max(1, speed), slew: slew, backfeed: backfeed)
        return copy
    }

    /// Renders the label to a ZPL string with variable substitution.
    ///
    /// Variables in the label content use the `{{variableName}}` syntax.
    /// Pass a dictionary to substitute these placeholders with actual values.
    ///
    /// Example:
    /// ```swift
    /// let label = ZPLLabel(width: 4, height: 2) {
    ///     Text("Order: {{orderNumber}}", at: .init(x: 50, y: 50))
    ///     Barcode128("{{trackingNumber}}", at: .init(x: 50, y: 100))
    /// }
    /// let zpl = label.render(substituting: [
    ///     "orderNumber": "12345",
    ///     "trackingNumber": "1Z999AA10123456784"
    /// ])
    /// ```
    ///
    /// - Parameters:
    ///   - substitutions: A dictionary of variable names to values. Keys should not include the `{{}}` delimiters.
    ///   - prettyPrint: If true, adds newlines between commands for readability.
    /// - Returns: The ZPL string with all variables substituted.
    public func render(substituting substitutions: [String: String], prettyPrint: Bool = false) -> String {
        var zpl = render(prettyPrint: prettyPrint)
        for (key, value) in substitutions {
            zpl = zpl.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return zpl
    }

    /// Renders the label to a ZPL string.
    /// - Parameter prettyPrint: If true, adds newlines between commands for readability.
    /// - Returns: The ZPL string representation of this label.
    public func render(prettyPrint: Bool = false) -> String {
        let separator = prettyPrint ? "\n" : ""
        let widthDots = dpi.dots(fromInches: width)
        let heightDots = dpi.dots(fromInches: height)

        let context = ZPLRenderContext(
            dpi: dpi,
            labelWidth: widthDots,
            labelHeight: heightDots
        )

        var commands: [String] = []

        // Label start
        commands.append("^XA")

        // Label home
        if let home = labelHome {
            commands.append("^LH\(home.x),\(home.y)")
        }

        // Print width
        commands.append("^PW\(widthDots)")

        // Label length
        commands.append("^LL\(heightDots)")

        // Default font
        if let font = defaultFont {
            commands.append("^CF\(font.font.rawValue),\(font.height)")
        }

        // Print darkness
        if let darkness = darkness {
            commands.append("^MD\(darkness)")
        }

        // Print speed
        if let speed = printSpeed {
            var prCommand = "^PR\(speed.print)"
            if let slew = speed.slew {
                prCommand += ",\(slew)"
                if let backfeed = speed.backfeed {
                    prCommand += ",\(backfeed)"
                }
            } else if let backfeed = speed.backfeed {
                prCommand += ",,\(backfeed)"
            }
            commands.append(prCommand)
        }

        // Render all elements
        for element in elements {
            commands.append(element.render(context: context))
        }

        // Print quantity (if more than 1)
        if quantity > 1 {
            commands.append("^PQ\(quantity)")
        }

        // Label end
        commands.append("^XZ")

        return commands.joined(separator: separator)
    }
}
