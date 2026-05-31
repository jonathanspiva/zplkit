import Foundation

/// Errors that can occur during label verification.
public enum VerifierError: Error, LocalizedError, Sendable {
    /// The provided image could not be processed.
    case invalidImage

    /// Vision framework failed during barcode detection.
    ///
    /// The associated value carries the underlying error thrown by Vision.
    case barcodeDetectionFailed(underlying: any Error)

    /// Vision framework failed during text recognition.
    ///
    /// The associated value carries the underlying error thrown by Vision.
    case textRecognitionFailed(underlying: any Error)

    /// An unexpected error occurred.
    case unexpected(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image could not be processed"
        case .barcodeDetectionFailed(let underlying):
            return "Barcode detection failed: \(underlying.localizedDescription)"
        case .textRecognitionFailed(let underlying):
            return "Text recognition failed: \(underlying.localizedDescription)"
        case .unexpected(let message):
            return "Unexpected error: \(message)"
        }
    }

    /// The underlying error message, if available.
    public var underlyingMessage: String? {
        switch self {
        case .barcodeDetectionFailed(let error), .textRecognitionFailed(let error):
            return error.localizedDescription
        case .unexpected(let msg):
            return msg
        case .invalidImage:
            return nil
        }
    }

    /// The underlying error, if this case carries one.
    public var underlyingError: (any Error)? {
        switch self {
        case .barcodeDetectionFailed(let error), .textRecognitionFailed(let error):
            return error
        case .unexpected, .invalidImage:
            return nil
        }
    }
}
