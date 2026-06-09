/// A reusable ZPL label template with `{{variable}}` placeholders.
///
/// `ZPLTemplate` mirrors ``ZPLLabel``'s declarative construction but is intended
/// to be defined once and rendered many times with different substitution
/// values. Internally it holds a ``ZPLLabel`` and delegates rendering to
/// ``ZPLLabel/render(substituting:prettyPrint:)``, which performs the
/// `{{variable}}` substitution with proper ZPL escaping of the supplied values.
///
/// ```swift
/// let template = ZPLTemplate(width: 4, height: 6, dpi: .dpi203) {
///     Text("FROM: {{sender_name}}", at: .inches(0.2, 0.2))
///         .font(.default, height: .inches(0.1))
///     Barcode128("{{tracking_number}}", at: .inches(0.2, 1.7))?
///         .height(.inches(0.7))
/// }
///
/// let zpl = template.render(with: [
///     "sender_name": "ACME",
///     "tracking_number": "1Z999"
/// ])
/// ```
public struct ZPLTemplate: Sendable {
    /// The underlying label that backs this template.
    private let label: ZPLLabel

    /// Creates a template with the given dimensions and content.
    ///
    /// - Parameters:
    ///   - width: Label width in inches.
    ///   - height: Label height in inches.
    ///   - dpi: Target printer DPI. Default is `.dpi203` (most common).
    ///   - content: A result builder closure that defines the label elements.
    ///     Use `{{variableName}}` placeholders for values supplied at render time.
    public init(
        width: Double,
        height: Double,
        dpi: DPI = .dpi203,
        @ZPLBuilder content: () -> [ZPLElement]
    ) {
        self.label = ZPLLabel(width: width, height: height, dpi: dpi, content: content)
    }

    /// Renders the template to ZPL, substituting `{{variable}}` placeholders.
    ///
    /// - Parameters:
    ///   - substitutions: A dictionary mapping variable names (without the
    ///     `{{}}` delimiters) to their values. Values are escaped so ZPL control
    ///     characters cannot corrupt or inject into the command stream.
    ///   - prettyPrint: If `true`, adds newlines between commands for
    ///     readability. Default is `false` for compact output.
    /// - Returns: The ZPL string with all variables substituted.
    public func render(with substitutions: [String: String], prettyPrint: Bool = false) -> String {
        label.render(substituting: substitutions, prettyPrint: prettyPrint)
    }
}
