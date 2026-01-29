import Foundation

/// Errors that can occur during label verification.
public enum VerifierError: Error, LocalizedError, Sendable {
    /// The provided image could not be processed.
    case invalidImage

    /// Vision framework failed to process the image.
    case visionError(String)

    /// An unexpected error occurred.
    case unexpected(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The provided image could not be processed"
        case .visionError(let message):
            return "Vision framework error: \(message)"
        case .unexpected(let message):
            return "Unexpected error: \(message)"
        }
    }
}
