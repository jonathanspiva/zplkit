import Foundation
import CoreGraphics
import Vision

/// Analyzes rendered label images to verify barcode and text content.
///
/// ZPLVerifier uses Apple's Vision framework to detect barcodes and perform
/// OCR on rendered label images. It supports two modes:
///
/// - **Discovery mode**: Find all barcodes and text in an image
/// - **Assertion mode**: Verify that specific content exists
///
/// ## Discovery Mode
///
/// Use `analyze(_:)` to discover all content in a label:
///
/// ```swift
/// let verifier = ZPLVerifier()
/// let result = try await verifier.analyze(renderedImage)
///
/// for barcode in result.barcodes {
///     print("\(barcode.symbology): \(barcode.payload)")
/// }
/// for text in result.textRegions {
///     print(text.text)
/// }
/// ```
///
/// ## Assertion Mode
///
/// Use `verify(_:expectations:)` to check for specific content:
///
/// ```swift
/// let result = try await verifier.verify(renderedImage) {
///     Barcode(.code128, containing: "SKU-12345")
///     Text("FRAGILE")
/// }
///
/// if !result.passed {
///     print(result.summary)
/// }
/// ```
public final class ZPLVerifier: Sendable {

    /// Configuration for the verifier.
    public struct Configuration: Sendable {
        /// Text recognition accuracy level.
        public var textRecognitionLevel: TextRecognitionLevel

        /// Languages to recognize, in order of preference.
        public var recognitionLanguages: [String]

        /// Minimum confidence threshold for detection results.
        public var minimumConfidence: Float

        /// Whether to use language correction for text recognition.
        public var usesLanguageCorrection: Bool

        /// Default configuration.
        public static let `default` = Configuration(
            textRecognitionLevel: .accurate,
            recognitionLanguages: ["en-US"],
            minimumConfidence: 0.0,
            usesLanguageCorrection: true
        )

        /// Fast configuration for quick checks.
        public static let fast = Configuration(
            textRecognitionLevel: .fast,
            recognitionLanguages: ["en-US"],
            minimumConfidence: 0.0,
            usesLanguageCorrection: false
        )

        public init(
            textRecognitionLevel: TextRecognitionLevel = .accurate,
            recognitionLanguages: [String] = ["en-US"],
            minimumConfidence: Float = 0.0,
            usesLanguageCorrection: Bool = true
        ) {
            self.textRecognitionLevel = textRecognitionLevel
            self.recognitionLanguages = recognitionLanguages
            self.minimumConfidence = minimumConfidence
            self.usesLanguageCorrection = usesLanguageCorrection
        }
    }

    /// Text recognition accuracy level.
    public enum TextRecognitionLevel: Sendable {
        /// Faster but less accurate.
        case fast
        /// More accurate but slower.
        case accurate

        var vnLevel: RecognizeTextRequest.RecognitionLevel {
            switch self {
            case .fast: return .fast
            case .accurate: return .accurate
            }
        }
    }

    private let configuration: Configuration

    /// Create a new verifier with the specified configuration.
    public init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    // MARK: - Discovery Mode

    /// Analyze an image to discover all barcodes and text.
    ///
    /// An image with no detectable barcodes or text is not an error: it returns
    /// an ``AnalysisResult`` with empty `barcodes` and `textRegions`. This method
    /// throws ``VerifierError`` only when the image is invalid (zero width or
    /// height) or when the Vision framework reports a failure. If the surrounding
    /// task is cancelled, `CancellationError` is rethrown unchanged.
    ///
    /// - Parameter image: The rendered label image to analyze.
    /// - Returns: Analysis results containing all detected content.
    /// - Throws: ``VerifierError/invalidImage`` for an empty image,
    ///   ``VerifierError`` on Vision failure, or `CancellationError` on cancellation.
    public func analyze(_ image: CGImage) async throws -> AnalysisResult {
        guard image.width > 0, image.height > 0 else {
            throw VerifierError.invalidImage
        }

        let clock = ContinuousClock()
        let startTime = clock.now

        async let barcodesTask = scanBarcodes(image, hints: .empty)
        async let textRegionsTask = scanText(image, hints: .empty)
        let (barcodes, textRegions) = try await (barcodesTask, textRegionsTask)

        let allBoundingBoxes = barcodes.map(\.boundingBox) + textRegions.map(\.boundingBox)
        let boundsInfo = BoundsInfo.from(boundingBoxes: allBoundingBoxes)

        let elapsed = startTime.duration(to: clock.now).inSeconds

        return AnalysisResult(
            barcodes: barcodes,
            textRegions: textRegions,
            boundsInfo: boundsInfo,
            analysisTimeSeconds: elapsed
        )
    }

    // MARK: - Assertion Mode

    /// Verify that an image contains expected content.
    ///
    /// An image with no detectable content is not an error: expectations simply
    /// report as not satisfied in the returned ``VerificationResult``. This method
    /// throws ``VerifierError`` only when the image is invalid (zero width or
    /// height) or when the Vision framework reports a failure. If the surrounding
    /// task is cancelled, `CancellationError` is rethrown unchanged.
    ///
    /// - Parameters:
    ///   - image: The rendered label image to verify.
    ///   - expectations: A builder closure specifying what content to expect.
    /// - Returns: Verification results indicating which expectations passed or failed.
    /// - Throws: ``VerifierError/invalidImage`` for an empty image,
    ///   ``VerifierError`` on Vision failure, or `CancellationError` on cancellation.
    public func verify(
        _ image: CGImage,
        @VerificationBuilder expectations: () -> [any Expectation]
    ) async throws -> VerificationResult {
        let expectationList = expectations()
        return try await verify(image, expectations: expectationList)
    }

    /// Verify that an image contains expected content.
    ///
    /// - Parameters:
    ///   - image: The rendered label image to verify.
    ///   - expectations: Array of expectations to check.
    /// - Returns: Verification results indicating which expectations passed or failed.
    /// - Throws: ``VerifierError/invalidImage`` for an empty image,
    ///   ``VerifierError/noExpectations`` for an empty expectation list (which
    ///   would otherwise pass vacuously), ``VerifierError`` on Vision failure,
    ///   or `CancellationError` on cancellation.
    public func verify(
        _ image: CGImage,
        expectations: [any Expectation]
    ) async throws -> VerificationResult {
        guard image.width > 0, image.height > 0 else {
            throw VerifierError.invalidImage
        }
        guard !expectations.isEmpty else {
            throw VerifierError.noExpectations
        }

        let clock = ContinuousClock()
        let startTime = clock.now

        // Merge hints from all expectations
        let hints = VisionHints.merge(expectations.map(\.visionHints))

        // Scan with optimized hints, concurrently — the two scans are independent.
        async let barcodesTask = scanBarcodes(image, hints: hints)
        async let textRegionsTask = scanText(image, hints: hints)
        let (barcodes, textRegions) = try await (barcodesTask, textRegionsTask)

        // Check each expectation
        let results = expectations.map { expectation in
            expectation.check(barcodes: barcodes, textRegions: textRegions)
        }

        let allPassed = results.allSatisfy(\.passed)

        let allBoundingBoxes = barcodes.map(\.boundingBox) + textRegions.map(\.boundingBox)
        let boundsInfo = BoundsInfo.from(boundingBoxes: allBoundingBoxes)

        let elapsed = startTime.duration(to: clock.now).inSeconds

        return VerificationResult(
            passed: allPassed,
            expectations: results,
            boundsInfo: boundsInfo,
            verificationTimeSeconds: elapsed
        )
    }

    // MARK: - Private

    private func scanBarcodes(_ image: CGImage, hints: VisionHints) async throws -> [DetectedBarcode] {
        let scannerConfig = VisionBarcodeScanner.Configuration(
            symbologies: Array(hints.symbologies),
            minimumConfidence: configuration.minimumConfidence
        )
        let scanner = VisionBarcodeScanner(configuration: scannerConfig)

        do {
            return try await scanner.scan(image)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw VerifierError.barcodeDetectionFailed(underlying: error)
        }
    }

    private func scanText(_ image: CGImage, hints: VisionHints) async throws -> [DetectedText] {
        let scannerConfig = VisionTextScanner.Configuration(
            recognitionLevel: configuration.textRecognitionLevel.vnLevel,
            recognitionLanguages: configuration.recognitionLanguages,
            customWords: Array(hints.customWords),
            minimumConfidence: configuration.minimumConfidence,
            usesLanguageCorrection: configuration.usesLanguageCorrection
        )
        let scanner = VisionTextScanner(configuration: scannerConfig)

        do {
            return try await scanner.scan(image)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw VerifierError.textRecognitionFailed(underlying: error)
        }
    }
}

private extension Duration {
    /// This `Duration` expressed as a fractional number of seconds.
    var inSeconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1_000_000_000_000_000_000
    }
}
