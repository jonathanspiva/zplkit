import Foundation

/// A ZPL label that contains elements and renders to a ZPL string.
///
/// `ZPLLabel` is the primary entry point for creating labels with ZPLKit.
/// Use Swift's result builder syntax to declaratively define label content.
///
/// ## Creating a Label
///
/// ```swift
/// let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
///     Text("Hello World", at: .inches(0.25, 0.25))
///         .font(.default, height: .inches(0.15))
///
///     Barcode128("ABC-123", at: .inches(0.25, 0.5))
///         .height(.inches(0.4))
///         .showText(true)
/// }
/// ```
///
/// ## Rendering to ZPL
///
/// Call ``render(prettyPrint:)`` to generate the ZPL string:
///
/// ```swift
/// let zpl = label.render()
/// // Send zpl to printer via network, USB, etc.
/// ```
///
/// ## Variable Substitution
///
/// Use `{{variable}}` placeholders for dynamic content:
///
/// ```swift
/// let template = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
///     Text("Order: {{orderNumber}}", at: .inches(0.25, 0.25))
///     Barcode128("{{tracking}}", at: .inches(0.25, 0.5))
/// }
///
/// let zpl = template.render(substituting: [
///     "orderNumber": "12345",
///     "tracking": "1Z999AA10123456784"
/// ])
/// ```
///
/// ## Topics
///
/// ### Creating Labels
/// - ``init(width:height:dpi:content:)``
///
/// ### Configuring Labels
/// - ``printQuantity(_:)``
/// - ``defaultFont(_:height:)``
/// - ``labelHome(_:_:)``
/// - ``printDarkness(_:)``
/// - ``printSpeed(_:slew:backfeed:)``
/// - ``reversePrint(_:)``
///
/// ### Rendering
/// - ``render(prettyPrint:)``
/// - ``render(substituting:prettyPrint:)``
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

    /// Reverse print mode (white on black).
    private var reversePrint: Bool = false

    /// Creates a new label with the given dimensions and content.
    ///
    /// - Parameters:
    ///   - width: Label width in inches.
    ///   - height: Label height in inches.
    ///   - dpi: Target printer DPI. Default is `.dpi203` (most common).
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

    /// Sets the number of labels to print.
    ///
    /// - Parameter count: Number of copies to print (minimum 1).
    /// - Returns: A modified label with the print quantity set.
    public func printQuantity(_ count: Int) -> ZPLLabel {
        var copy = self
        copy.quantity = max(1, count)
        return copy
    }

    /// Sets the default font for all text elements on this label.
    ///
    /// Elements without explicit font settings will use this font.
    ///
    /// - Parameters:
    ///   - font: The font to use.
    ///   - height: Font height in dots.
    /// - Returns: A modified label with the default font set.
    public func defaultFont(_ font: ZPLFont, height: Int) -> ZPLLabel {
        var copy = self
        copy.defaultFont = (font, height)
        return copy
    }

    /// Sets the label home position (origin offset).
    ///
    /// All element positions are offset by this amount.
    /// Useful for adjusting label alignment.
    ///
    /// - Parameters:
    ///   - x: Horizontal offset in dots.
    ///   - y: Vertical offset in dots.
    /// - Returns: A modified label with the home position set.
    public func labelHome(_ x: Int, _ y: Int) -> ZPLLabel {
        var copy = self
        copy.labelHome = (x, y)
        return copy
    }

    /// Sets the print darkness level.
    ///
    /// Higher values produce darker prints but may cause ink bleeding.
    /// The value is clamped to the valid range of 0-30.
    ///
    /// - Parameter level: Darkness level from 0 (lightest) to 30 (darkest).
    /// - Returns: A modified label with the darkness set.
    public func printDarkness(_ level: Int) -> ZPLLabel {
        var copy = self
        copy.darkness = min(30, max(0, level))
        return copy
    }

    /// Sets the print speed.
    ///
    /// Speed values typically range from 1-14 inches per second,
    /// but vary by printer model. Higher values print faster but
    /// may reduce quality.
    ///
    /// - Parameters:
    ///   - speed: Print speed in inches per second.
    ///   - slew: Slew speed for non-print movement. Defaults to print speed.
    ///   - backfeed: Backfeed speed. Defaults to print speed.
    /// - Returns: A modified label with the speed settings.
    public func printSpeed(_ speed: Int, slew: Int? = nil, backfeed: Int? = nil) -> ZPLLabel {
        var copy = self
        copy.printSpeed = (print: max(1, speed), slew: slew, backfeed: backfeed)
        return copy
    }

    /// Enables reverse print mode for the entire label.
    ///
    /// When enabled, all fields are printed as white on black (inverted).
    /// This affects the entire label, not individual elements.
    ///
    /// - Parameter enabled: Whether to enable reverse printing. Default is `true`.
    /// - Returns: A modified label with reverse print mode set.
    public func reversePrint(_ enabled: Bool = true) -> ZPLLabel {
        var copy = self
        copy.reversePrint = enabled
        return copy
    }

    /// Renders the label to a ZPL string with variable substitution.
    ///
    /// Variables in the label content use the `{{variableName}}` syntax.
    /// Pass a dictionary to substitute these placeholders with actual values.
    ///
    /// ```swift
    /// let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
    ///     Text("Order: {{orderNumber}}", at: .inches(0.25, 0.25))
    ///     Barcode128("{{trackingNumber}}", at: .inches(0.25, 0.5))
    /// }
    /// let zpl = label.render(substituting: [
    ///     "orderNumber": "12345",
    ///     "trackingNumber": "1Z999AA10123456784"
    /// ])
    /// ```
    ///
    /// - Parameters:
    ///   - substitutions: A dictionary mapping variable names to values.
    ///     Keys should not include the `{{}}` delimiters.
    ///   - prettyPrint: If `true`, adds newlines between commands for readability.
    /// - Returns: The ZPL string with all variables substituted.
    public func render(substituting substitutions: [String: String], prettyPrint: Bool = false) -> String {
        var zpl = render(prettyPrint: prettyPrint)
        for (key, value) in substitutions {
            zpl = zpl.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return zpl
    }

    /// Renders the label to a ZPL string.
    ///
    /// - Parameter prettyPrint: If `true`, adds newlines between commands
    ///   for readability. Default is `false` for compact output.
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

        // Reverse print (label-wide)
        if reversePrint {
            commands.append("^LRY")
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
