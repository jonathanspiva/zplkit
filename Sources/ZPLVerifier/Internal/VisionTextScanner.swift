import Vision
import CoreGraphics

/// Internal wrapper around Vision framework's text recognition.
struct VisionTextScanner {
    /// Configuration for text scanning.
    struct Configuration {
        /// Recognition level: fast or accurate.
        var recognitionLevel: VNRequestTextRecognitionLevel = .accurate

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
    func scan(_ image: CGImage) throws -> [DetectedText] {
        var detectedTexts: [DetectedText] = []
        var scanError: Error?

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                scanError = error
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                guard topCandidate.confidence >= self.configuration.minimumConfidence else { continue }

                let text = DetectedText(
                    text: topCandidate.string,
                    boundingBox: observation.boundingBox,
                    confidence: topCandidate.confidence
                )
                detectedTexts.append(text)
            }
        }

        request.recognitionLevel = configuration.recognitionLevel
        request.recognitionLanguages = configuration.recognitionLanguages
        request.usesLanguageCorrection = configuration.usesLanguageCorrection

        if !configuration.customWords.isEmpty {
            request.customWords = configuration.customWords
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        if let error = scanError {
            throw error
        }

        return detectedTexts
    }
}
