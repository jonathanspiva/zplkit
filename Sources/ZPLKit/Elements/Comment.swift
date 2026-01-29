/// A comment element that adds non-printing text to the ZPL for documentation.
///
/// Comments are useful for debugging and documenting label templates.
/// They are ignored by the printer and do not appear on the printed label.
///
/// Example:
/// ```swift
/// ZPLLabel(width: 4, height: 2) {
///     Comment("Header section")
///     Text("Title", at: .inches(0.25, 0.25))
///     Comment("Barcode section")
///     Barcode128("12345", at: .inches(0.25, 0.5))
/// }
/// ```
public struct Comment: ZPLElement, Equatable, Hashable {
    private let text: String

    /// Creates a comment with the given text.
    /// - Parameter text: The comment text (will not be printed).
    public init(_ text: String) {
        self.text = text
    }

    public func render(context: ZPLRenderContext) -> String {
        // ^FX is the ZPL comment command
        // Text after ^FX is ignored until the next ^FS or caret command
        return "^FX \(text) ^FS"
    }
}
