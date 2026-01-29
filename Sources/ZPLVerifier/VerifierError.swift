import Foundation

/// Errors that can occur during label verification.
public enum VerifierError: Error, LocalizedError, Sendable {
    /// The provided image could not be processed.
    case invalidImage

    /// Vision framework failed during barcode detection.
    case barcodeDetectionFailed(underlying: String)

    /// Vision framework failed during text recognition.
    case textRecognitionFailed(underlying: String)

    /// Vision framework failed to process the image.
    @available(*, deprecated, renamed: "barcodeDetectionFailed")
    case visionError(String)

    /// An unexpected error occurred.
    case unexpected(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image could not be processed"
        case .barcodeDetectionFailed(let underlying):
            return "Barcode detection failed: \(underlying)"
        case .textRecognitionFailed(let underlying):
            return "Text recognition failed: \(underlying)"
        case .visionError(let message):
            return "Vision framework error: \(message)"
        case .unexpected(let message):
            return "Unexpected error: \(message)"
        }
    }

    /// The underlying error message, if available.
    public var underlyingMessage: String? {
        switch self {
        case .barcodeDetectionFailed(let msg), .textRecognitionFailed(let msg), .visionError(let msg), .unexpected(let msg):
            return msg
        case .invalidImage:
            return nil
        }
    }
}
