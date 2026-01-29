import Foundation

/// Expectation that specific text exists in the image.
public struct Text: Expectation {
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

    public var visionHints: VisionHints {
        switch textMatch {
        case .containing(let substring):
            // Add significant words as custom words for better recognition
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
