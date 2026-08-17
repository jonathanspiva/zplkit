#if canImport(Vision) && !os(watchOS)
import Foundation

/// A barcode detected in a rendered label image.
public struct DetectedBarcode: Sendable, Hashable, Codable, CustomStringConvertible {
    /// The barcode symbology type.
    public let symbology: BarcodeSymbology

    /// The decoded payload string.
    public let payload: String

    /// The bounding box in normalized coordinates (0.0-1.0).
    /// Origin is at bottom-left, matching Vision framework conventions.
    public let boundingBox: CGRect

    /// Confidence score from 0.0 to 1.0.
    public let confidence: Float

    /// Whether this barcode may be clipped by the image edge.
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
        symbology: BarcodeSymbology,
        payload: String,
        boundingBox: CGRect,
        confidence: Float
    ) {
        self.symbology = symbology
        self.payload = payload
        self.boundingBox = boundingBox
        self.confidence = confidence
    }

    public var description: String {
        "\(symbology): \(payload)"
    }
}
#endif
