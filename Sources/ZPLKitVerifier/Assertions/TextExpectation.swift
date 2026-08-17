#if canImport(Vision) && !os(watchOS)
import Foundation

/// Expectation that specific text exists in the image.
///
/// Named `TextExpectation` (not `Text`) so it never collides with ``ZPLKit/Text``
/// in code that imports both modules for the build → render → verify workflow.
public struct TextExpectation: Expectation {
    /// How to match the text.
    public let textMatch: TextMatch

    /// How to match the text content.
    public enum TextMatch: Sendable {
        /// Text must contain this substring (case-insensitive).
        case containing(String)

        /// Text must exactly equal this string.
        case exactly(String)
    }

    public var description: String {
        switch textMatch {
        case .containing(let substring):
            return "Text(containing: \"\(substring)\")"
        case .exactly(let value):
            return "Text(exactly: \"\(value)\")"
        }
    }

    /// Vision recognition hints derived from the expected text.
    ///
    /// "Significant" words from the expectation are passed to Vision as custom
    /// words to bias OCR toward the strings we expect. Only words of **3 or more
    /// characters** are included: shorter tokens are too generic to be useful as
    /// custom-word hints and risk biasing recognition toward noise. As a result,
    /// very short expectations such as `Text("OK")` contribute no custom-word
    /// hint (matching still works at check time; only the recognition hint is
    /// skipped).
    public var visionHints: VisionHints {
        switch textMatch {
        case .containing(let substring):
            // Add significant words (>= 3 chars) as custom words for better recognition.
            let words = substring.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
                .map(String.init)
                .filter { $0.count >= 3 }
            return VisionHints(customWords: Set(words))
        case .exactly(let value):
            let words = value.split(whereSeparator: { $0.isWhitespace || $0.isPunctuation })
                .map(String.init)
                .filter { $0.count >= 3 }
            return VisionHints(customWords: Set(words))
        }
    }

    /// Create an expectation for text containing a substring (case-insensitive).
    public init(_ substring: String) {
        self.textMatch = .containing(substring)
    }

    /// Create an expectation for an exact text match.
    public init(exactly value: String) {
        self.textMatch = .exactly(value)
    }

    public func check(
        barcodes: [DetectedBarcode],
        textRegions: [DetectedText]
    ) -> ExpectationResult {
        switch textMatch {
        case .containing(let substring):
            if let match = textRegions.first(where: {
                $0.text.localizedCaseInsensitiveContains(substring)
            }) {
                return ExpectationResult(
                    description: description,
                    passed: true,
                    matchedItem: .text(match)
                )
            }
            let found = textRegions.map { $0.text }.joined(separator: ", ")
            let foundMsg = found.isEmpty ? "(no text detected)" : found
            return ExpectationResult(
                description: description,
                passed: false,
                failureMessage: "No text containing \"\(substring)\". Found: \(foundMsg)"
            )

        case .exactly(let value):
            if let match = textRegions.first(where: { $0.text == value }) {
                return ExpectationResult(
                    description: description,
                    passed: true,
                    matchedItem: .text(match)
                )
            }
            let found = textRegions.map { $0.text }.joined(separator: ", ")
            let foundMsg = found.isEmpty ? "(no text detected)" : found
            return ExpectationResult(
                description: description,
                passed: false,
                failureMessage: "No text exactly matching \"\(value)\". Found: \(foundMsg)"
            )
        }
    }
}
#endif
