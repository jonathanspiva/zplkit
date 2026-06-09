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
    ///
    /// `^FX` comments are terminated by the next caret or tilde command and do
    /// not support `^FH` hex escaping, so caret (`^`), tilde (`~`), and other
    /// control characters in the text are replaced with spaces to ensure the
    /// comment can never break out and execute as a live ZPL command.
    /// - Parameter text: The comment text (will not be printed).
    public init(_ text: String) {
        self.text = Comment.sanitize(text)
    }

    /// Replaces ZPL command-introducing and control characters with spaces.
    private static func sanitize(_ text: String) -> String {
        String(text.map { char in
            if char == "^" || char == "~" || char.isNewline {
                return " "
            }
            if let ascii = char.asciiValue, ascii < 0x20 || ascii == 0x7F {
                return " "
            }
            return char
        })
    }

    public func render(context: ZPLRenderContext) -> String {
        // ^FX is the ZPL comment command. Text after ^FX is ignored until the
        // next caret or tilde command. The text was sanitized at init so it
        // contains no caret/tilde/control characters that could terminate it.
        return "^FX \(text) ^FS"
    }
}
