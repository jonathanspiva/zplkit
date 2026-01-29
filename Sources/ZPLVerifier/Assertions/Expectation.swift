import Foundation

/// A verification expectation for label content.
public protocol Expectation: Sendable {
    /// Human-readable description of this expectation.
    var description: String { get }

    /// Check if this expectation is satisfied by the detected content.
    func check(
        barcodes: [DetectedBarcode],
        textRegions: [DetectedText]
    ) -> ExpectationResult

    /// Hints for Vision framework to optimize detection.
    var visionHints: VisionHints { get }
}
