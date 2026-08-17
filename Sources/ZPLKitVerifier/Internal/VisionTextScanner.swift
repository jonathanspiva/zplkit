#if canImport(Vision) && !os(watchOS)
import Vision
import CoreGraphics
import Foundation

/// Internal wrapper around Vision framework's text recognition.
struct VisionTextScanner {
    /// Configuration for text scanning.
    struct Configuration {
        /// Recognition level: fast or accurate.
        var recognitionLevel: RecognizeTextRequest.RecognitionLevel = .accurate

        /// Languages to recognize, in order of preference.
        var recognitionLanguages: [String] = ["en-US"]

        /// Custom words to help recognition (e.g., product codes, SKUs).
        var customWords: [String] = []

        /// Minimum confidence threshold for results.
        var minimumConfidence: Float = 0.0

        /// Whether to use language correction.
        var usesLanguageCorrection: Bool = true
    }

    let configuration: Configuration

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Scan an image for text.
    func scan(_ image: CGImage) async throws -> [DetectedText] {
        var request = RecognizeTextRequest()

        request.recognitionLevel = configuration.recognitionLevel
        request.recognitionLanguages = configuration.recognitionLanguages.map {
            Locale.Language(identifier: $0)
        }
        request.usesLanguageCorrection = configuration.usesLanguageCorrection

        if !configuration.customWords.isEmpty {
            request.customWords = configuration.customWords
        }

        let handler = ImageRequestHandler(image)
        let observations = try await handler.perform(request)

        var detectedTexts: [DetectedText] = []
        for observation in observations {
            guard let topCandidate = observation.topCandidates(1).first else { continue }
            guard topCandidate.confidence >= configuration.minimumConfidence else { continue }

            let text = DetectedText(
                text: topCandidate.string,
                boundingBox: observation.boundingBox.cgRect,
                confidence: topCandidate.confidence
            )
            detectedTexts.append(text)
        }

        return detectedTexts
    }
}
#endif
