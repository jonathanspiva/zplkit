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
    func scan(_ image: CGImage) throws -> [DetectedBarcode] {
        var detectedBarcodes: [DetectedBarcode] = []
        var scanError: Error?

        let request = VNDetectBarcodesRequest { request, error in
            if let error = error {
                scanError = error
                return
            }

            guard let observations = request.results as? [VNBarcodeObservation] else {
                return
            }

            for observation in observations {
                guard let payload = observation.payloadStringValue else { continue }
                guard observation.confidence >= self.configuration.minimumConfidence else { continue }

                guard let symbology = BarcodeSymbology(vnSymbology: observation.symbology) else {
                    continue
                }

                let barcode = DetectedBarcode(
                    symbology: symbology,
                    payload: payload,
                    boundingBox: observation.boundingBox,
                    confidence: observation.confidence
                )
                detectedBarcodes.append(barcode)
            }
        }

        // Set symbology hints if provided
        if !configuration.symbologies.isEmpty {
            request.symbologies = configuration.symbologies.map { $0.vnSymbology }
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        if let error = scanError {
            throw error
        }

        return detectedBarcodes
    }
}
