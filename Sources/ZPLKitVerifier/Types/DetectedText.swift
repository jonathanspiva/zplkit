#if canImport(Vision) && !os(watchOS)
import Foundation

/// A text region detected in a rendered label image.
public struct DetectedText: Sendable, Hashable, Codable, CustomStringConvertible {
    /// The recognized text string.
    public let text: String

    /// The bounding box in normalized coordinates (0.0-1.0).
    /// Origin is at bottom-left, matching Vision framework conventions.
    public let boundingBox: CGRect

    /// Confidence score from 0.0 to 1.0.
    public let confidence: Float

    /// Whether this text region may be clipped by the image edge.
    ///
    /// Returns `true` if the bounding box extends within 2% of any edge.
    public var mayBeClipped: Bool {
        let threshold: CGFloat = 0.02
        return boundingBox.minX < threshold ||
               boundingBox.minY < threshold ||
               boundingBox.maxX > (1.0 - threshold) ||
               boundingBox.maxY > (1.0 - threshold)
    }

    public init(
        text: String,
        boundingBox: CGRect,
        confidence: Float
    ) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }

    public var description: String {
        "\"\(text)\""
    }
}
#endif
