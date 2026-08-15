import Foundation

/// Errors that can occur during label verification.
public enum VerifierError: Error, LocalizedError, Sendable {
    /// The provided image could not be processed.
    case invalidImage

    /// `verify` was called with no expectations.
    ///
    /// An empty expectation list would pass vacuously ("all 0 expectations
    /// passed"), silently turning a test green while checking nothing, e.g.
    /// a builder block whose only expectation sits behind a false `if`.
    case noExpectations

    /// Vision framework failed during barcode detection.
    ///
    /// The associated value carries the underlying error thrown by Vision.
    case barcodeDetectionFailed(underlying: any Error)

    /// Vision framework failed during text recognition.
    ///
    /// The associated value carries the underlying error thrown by Vision.
    case textRecognitionFailed(underlying: any Error)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image could not be processed"
        case .noExpectations:
            return "verify was called with no expectations; use analyze(_:) for discovery"
        case .barcodeDetectionFailed(let underlying):
            return "Barcode detection failed: \(underlying.localizedDescription)"
        case .textRecognitionFailed(let underlying):
            return "Text recognition failed: \(underlying.localizedDescription)"
        }
    }

    /// The underlying error message, if available.
    public var underlyingMessage: String? {
        switch self {
        case .barcodeDetectionFailed(let error), .textRecognitionFailed(let error):
            return error.localizedDescription
        case .invalidImage, .noExpectations:
            return nil
        }
    }

    /// The underlying error, if this case carries one.
    public var underlyingError: (any Error)? {
        switch self {
        case .barcodeDetectionFailed(let error), .textRecognitionFailed(let error):
            return error
        case .invalidImage, .noExpectations:
            return nil
        }
    }
}
