import Foundation

/// Results from verifying a rendered label against expectations.
public struct VerificationResult: Sendable {
    /// Whether all expectations passed.
    public let passed: Bool

    /// Individual results for each expectation.
    public let expectations: [ExpectationResult]

    /// Information about content near label edges.
    public let boundsInfo: BoundsInfo

    /// Time taken to verify the image, in seconds.
    public let verificationTimeSeconds: Double

    public init(
        passed: Bool,
        expectations: [ExpectationResult],
        boundsInfo: BoundsInfo,
        verificationTimeSeconds: Double
    ) {
        self.passed = passed
        self.expectations = expectations
        self.boundsInfo = boundsInfo
        self.verificationTimeSeconds = verificationTimeSeconds
    }

    /// Human-readable summary of verification results.
    public var summary: String {
        if passed {
            return "All \(expectations.count) expectation(s) passed"
        }

        let failed = expectations.filter { !$0.passed }
        let messages = failed.map { $0.failureMessage ?? $0.description }
        return "Failed: " + messages.joined(separator: "; ")
    }

    /// All expectations that passed.
    public var passedExpectations: [ExpectationResult] {
        expectations.filter { $0.passed }
    }

    /// All expectations that failed.
    public var failedExpectations: [ExpectationResult] {
        expectations.filter { !$0.passed }
    }
}

/// Result for a single expectation check.
public struct ExpectationResult: Sendable {
    /// Description of what was expected.
    public let description: String

    /// Whether the expectation was satisfied.
    public let passed: Bool

    /// Human-readable failure message if the expectation failed.
    public let failureMessage: String?

    /// The matched item, if any.
    public let matchedItem: MatchedItem?

    public init(
        description: String,
        passed: Bool,
        failureMessage: String? = nil,
        matchedItem: MatchedItem? = nil
    ) {
        self.description = description
        self.passed = passed
        self.failureMessage = failureMessage
        self.matchedItem = matchedItem
    }

    /// An item that matched an expectation.
    public enum MatchedItem: Sendable {
        case barcode(DetectedBarcode)
        case text(DetectedText)
    }
}
