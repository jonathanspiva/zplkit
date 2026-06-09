import Foundation

/// Expectation that a barcode of a specific type exists in the image.
public struct Barcode: Expectation {
    /// The expected barcode symbology.
    public let symbology: BarcodeSymbology

    /// The expected payload match mode.
    public let payloadMatch: PayloadMatch

    /// How to match the barcode payload.
    ///
    /// Payload matching is **case-sensitive** for both `containing` and `exactly`.
    /// A barcode payload is exact machine-readable data (tracking numbers, SKUs,
    /// case-sensitive URLs or tokens in a QR code), so `"abc"` and `"ABC"` are
    /// genuinely different payloads. This is deliberately stricter than
    /// ``Text/TextMatch/containing(_:)``, which is case-insensitive because OCR
    /// text is fuzzy.
    public enum PayloadMatch: Sendable {
        /// Match any payload.
        case any

        /// Payload must contain this substring (case-sensitive).
        case containing(String)

        /// Payload must exactly equal this string (case-sensitive).
        case exactly(String)
    }

    public var description: String {
        switch payloadMatch {
        case .any:
            return "Barcode(\(symbology.rawValue))"
        case .containing(let substring):
            return "Barcode(\(symbology.rawValue), containing: \"\(substring)\")"
        case .exactly(let value):
            return "Barcode(\(symbology.rawValue), exactly: \"\(value)\")"
        }
    }

    public var visionHints: VisionHints {
        VisionHints(symbologies: [symbology])
    }

    /// Create an expectation for a barcode of the specified symbology with any payload.
    public init(_ symbology: BarcodeSymbology) {
        self.symbology = symbology
        self.payloadMatch = .any
    }

    /// Create an expectation for a barcode containing a substring in its payload.
    ///
    /// Matching is case-sensitive (see ``PayloadMatch``).
    public init(_ symbology: BarcodeSymbology, containing substring: String) {
        self.symbology = symbology
        self.payloadMatch = .containing(substring)
    }

    /// Create an expectation for a barcode with an exact payload.
    public init(_ symbology: BarcodeSymbology, exactly value: String) {
        self.symbology = symbology
        self.payloadMatch = .exactly(value)
    }

    public func check(
        barcodes: [DetectedBarcode],
        textRegions: [DetectedText]
    ) -> ExpectationResult {
        let matchingType = barcodes.filter { $0.symbology == symbology }

        if matchingType.isEmpty {
            return ExpectationResult(
                description: description,
                passed: false,
                failureMessage: "No \(symbology.rawValue) barcode found"
            )
        }

        switch payloadMatch {
        case .any:
            return ExpectationResult(
                description: description,
                passed: true,
                matchedItem: .barcode(matchingType[0])
            )

        case .containing(let substring):
            if let match = matchingType.first(where: { $0.payload.contains(substring) }) {
                return ExpectationResult(
                    description: description,
                    passed: true,
                    matchedItem: .barcode(match)
                )
            }
            let found = matchingType.map { $0.payload }.joined(separator: ", ")
            return ExpectationResult(
                description: description,
                passed: false,
                failureMessage: "No \(symbology.rawValue) barcode containing \"\(substring)\". Found: \(found)"
            )

        case .exactly(let value):
            if let match = matchingType.first(where: { $0.payload == value }) {
                return ExpectationResult(
                    description: description,
                    passed: true,
                    matchedItem: .barcode(match)
                )
            }
            let found = matchingType.map { $0.payload }.joined(separator: ", ")
            return ExpectationResult(
                description: description,
                passed: false,
                failureMessage: "No \(symbology.rawValue) barcode with payload \"\(value)\". Found: \(found)"
            )
        }
    }
}
