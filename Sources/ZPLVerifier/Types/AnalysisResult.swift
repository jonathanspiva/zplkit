import Foundation

/// Results from analyzing a rendered label image in discovery mode.
///
/// Discovery mode finds all barcodes and text in an image without
/// any expectations about what should be present.
public struct AnalysisResult: Sendable {
    /// All barcodes detected in the image.
    public let barcodes: [DetectedBarcode]

    /// All text regions detected in the image.
    public let textRegions: [DetectedText]

    /// Information about content near label edges.
    public let boundsInfo: BoundsInfo

    /// Time taken to analyze the image, in seconds.
    public let analysisTimeSeconds: Double

    public init(
        barcodes: [DetectedBarcode],
        textRegions: [DetectedText],
        boundsInfo: BoundsInfo,
        analysisTimeSeconds: Double
    ) {
        self.barcodes = barcodes
        self.textRegions = textRegions
        self.boundsInfo = boundsInfo
        self.analysisTimeSeconds = analysisTimeSeconds
    }

    /// All detected text concatenated, separated by newlines.
    public var allText: String {
        textRegions.map { $0.text }.joined(separator: "\n")
    }

    /// All barcode payloads.
    public var allPayloads: [String] {
        barcodes.map { $0.payload }
    }

    /// Barcodes of a specific symbology.
    public func barcodes(of symbology: BarcodeSymbology) -> [DetectedBarcode] {
        barcodes.filter { $0.symbology == symbology }
    }

    /// Text regions containing a specific substring.
    public func textRegions(containing substring: String) -> [DetectedText] {
        textRegions.filter { $0.text.localizedCaseInsensitiveContains(substring) }
    }
}
