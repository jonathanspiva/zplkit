import Vision
import CoreGraphics

/// Internal wrapper around Vision framework's barcode detection.
struct VisionBarcodeScanner {
    /// Configuration for barcode scanning.
    struct Configuration {
        /// Specific symbologies to detect. If empty, all supported symbologies are detected.
        var symbologies: [BarcodeSymbology] = []

        /// Minimum confidence threshold for results.
        var minimumConfidence: Float = 0.0
    }

    let configuration: Configuration

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Scan an image for barcodes.
    func scan(_ image: CGImage) async throws -> [DetectedBarcode] {
        var request = DetectBarcodesRequest()

        // Set symbology hints if provided
        if !configuration.symbologies.isEmpty {
            request.symbologies = configuration.symbologies.map { $0.vnSymbology }
        }

        let handler = ImageRequestHandler(image)
        let observations = try await handler.perform(request)

        var detectedBarcodes: [DetectedBarcode] = []
        for observation in observations {
            guard let payload = observation.payloadString else { continue }
            guard observation.confidence >= configuration.minimumConfidence else { continue }

            guard let symbology = BarcodeSymbology(vnSymbology: observation.symbology) else {
                continue
            }

            let barcode = DetectedBarcode(
                symbology: symbology,
                payload: payload,
                boundingBox: observation.boundingBox.cgRect,
                confidence: observation.confidence
            )
            detectedBarcodes.append(barcode)
        }

        return detectedBarcodes
    }
}
