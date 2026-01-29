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
