import Foundation
import CoreGraphics
import Testing
@testable import ZPLKitVerifier
@testable import ZPLKit
@testable import ZPLKitRenderer

/// `Testing.Expectation` and the verifier's `Expectation` protocol collide by name.
/// A specific protocol import disambiguates so the result builder can name the protocol.
import protocol ZPLKitVerifier.Expectation

// MARK: - Expectation Construction

@Suite("Expectation Construction")
struct ExpectationConstructionTests {

    @Test("Barcode(any) description and vision hints")
    func barcodeExpectationAny() {
        let expectation = BarcodeExpectation(.code128)
        #expect(expectation.description == "Barcode(code128)")
        #expect(expectation.visionHints.symbologies == [.code128])
    }

    @Test("Barcode(containing:) description and vision hints")
    func barcodeExpectationContaining() {
        let expectation = BarcodeExpectation(.qr, containing: "example.com")
        #expect(expectation.description == "Barcode(qr, containing: \"example.com\")")
        #expect(expectation.visionHints.symbologies == [.qr])
    }

    @Test("Barcode(exactly:) description")
    func barcodeExpectationExactly() {
        let expectation = BarcodeExpectation(.code128, exactly: "ABC123")
        #expect(expectation.description == "Barcode(code128, exactly: \"ABC123\")")
    }

    @Test("Text(containing:) description and custom words")
    func textExpectationContaining() {
        let expectation = TextExpectation("FRAGILE")
        #expect(expectation.description == "Text(containing: \"FRAGILE\")")
        #expect(expectation.visionHints.customWords.contains("FRAGILE"))
    }

    @Test("Text(exactly:) description")
    func textExpectationExactly() {
        let expectation = TextExpectation(exactly: "Hello World")
        #expect(expectation.description == "Text(exactly: \"Hello World\")")
    }
}

// MARK: - Expectation Checks

@Suite("Expectation Checks")
struct ExpectationCheckTests {

    @Test("Barcode exact match passes with matched item")
    func barcodeExpectationCheckPass() {
        let expectation = BarcodeExpectation(.code128, exactly: "ABC123")
        let barcodes = [
            DetectedBarcode(
                symbology: .code128,
                payload: "ABC123",
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.2),
                confidence: 0.95
            )
        ]

        let result = expectation.check(barcodes: barcodes, textRegions: [])

        #expect(result.passed)
        #expect(result.failureMessage == nil)
        #expect(result.matchedItem != nil)
    }

    @Test("Barcode missing symbology fails with No <symbology> message")
    func barcodeExpectationCheckFailMissingSymbology() {
        let expectation = BarcodeExpectation(.code128)
        let barcodes = [
            DetectedBarcode(
                symbology: .qr,
                payload: "data",
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
                confidence: 0.95
            )
        ]

        let result = expectation.check(barcodes: barcodes, textRegions: [])

        #expect(!result.passed)
        #expect(result.failureMessage?.contains("No code128") ?? false)
    }

    @Test("Barcode wrong payload fails and surfaces actual payload")
    func barcodeExpectationCheckFailWrongPayload() {
        let expectation = BarcodeExpectation(.code128, exactly: "ABC123")
        let barcodes = [
            DetectedBarcode(
                symbology: .code128,
                payload: "XYZ789",
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.2),
                confidence: 0.95
            )
        ]

        let result = expectation.check(barcodes: barcodes, textRegions: [])

        #expect(!result.passed)
        #expect(result.failureMessage?.contains("XYZ789") ?? false)
    }

    @Test("Barcode containing match passes on substring payload")
    func barcodeExpectationCheckContaining() {
        let expectation = BarcodeExpectation(.qr, containing: "example")
        let barcodes = [
            DetectedBarcode(
                symbology: .qr,
                payload: "https://example.com/path",
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
                confidence: 0.95
            )
        ]

        let result = expectation.check(barcodes: barcodes, textRegions: [])

        #expect(result.passed)
    }

    @Test("Text containing match passes")
    func textExpectationCheckPass() {
        let expectation = TextExpectation("FRAGILE")
        let textRegions = [
            DetectedText(
                text: "HANDLE WITH CARE - FRAGILE",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.9
            )
        ]

        let result = expectation.check(barcodes: [], textRegions: textRegions)

        #expect(result.passed)
    }

    @Test("Text containing match is case-insensitive")
    func textExpectationCheckPassCaseInsensitive() {
        let expectation = TextExpectation("fragile")
        let textRegions = [
            DetectedText(
                text: "FRAGILE",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.9
            )
        ]

        let result = expectation.check(barcodes: [], textRegions: textRegions)

        #expect(result.passed)
    }

    @Test("Text not found fails and surfaces missing text")
    func textExpectationCheckFailNotFound() {
        let expectation = TextExpectation("MISSING")
        let textRegions = [
            DetectedText(
                text: "HELLO WORLD",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.9
            )
        ]

        let result = expectation.check(barcodes: [], textRegions: textRegions)

        #expect(!result.passed)
        #expect(result.failureMessage?.contains("MISSING") ?? false)
    }

    @Test("Text exact match passes")
    func textExpectationExactlyCheckPass() {
        let expectation = TextExpectation(exactly: "Hello World")
        let textRegions = [
            DetectedText(
                text: "Hello World",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.9
            )
        ]

        let result = expectation.check(barcodes: [], textRegions: textRegions)

        #expect(result.passed)
    }

    @Test("Text exact match fails on partial match")
    func textExpectationExactlyCheckFailPartialMatch() {
        let expectation = TextExpectation(exactly: "Hello")
        let textRegions = [
            DetectedText(
                text: "Hello World",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.9
            )
        ]

        let result = expectation.check(barcodes: [], textRegions: textRegions)

        #expect(!result.passed)
    }
}

// MARK: - VisionHints

@Suite("VisionHints")
struct VisionHintsTests {

    @Test("merge([_]) unions symbologies and custom words")
    func visionHintsMerge() {
        let hints1 = VisionHints(symbologies: [.code128], customWords: ["HELLO"])
        let hints2 = VisionHints(symbologies: [.qr], customWords: ["WORLD"])

        let merged = VisionHints.merge([hints1, hints2])

        #expect(merged.symbologies == [.code128, .qr])
        #expect(merged.customWords == ["HELLO", "WORLD"])
    }

    @Test("merging(_:) deduplicates symbologies")
    func visionHintsMerging() {
        let hints1 = VisionHints(symbologies: [.code128])
        let hints2 = VisionHints(symbologies: [.code128, .qr])

        let merged = hints1.merging(hints2)

        #expect(merged.symbologies.count == 2)
        #expect(merged.symbologies.contains(.code128))
        #expect(merged.symbologies.contains(.qr))
    }
}

// MARK: - BoundsInfo

@Suite("BoundsInfo")
struct BoundsInfoTests {

    @Test("Edge detection flags left/top edges")
    func boundsInfoEdgeDetection() {
        let boxes = [
            CGRect(x: 0.0, y: 0.5, width: 0.1, height: 0.1),  // left edge
            CGRect(x: 0.5, y: 0.99, width: 0.1, height: 0.01) // top edge
        ]

        let boundsInfo = BoundsInfo.from(boundingBoxes: boxes)

        #expect(boundsInfo.hasLeftEdgeContent)
        #expect(boundsInfo.hasTopEdgeContent)
        #expect(!boundsInfo.hasRightEdgeContent)
        #expect(!boundsInfo.hasBottomEdgeContent)
        #expect(boundsInfo.hasEdgeContent)
    }

    @Test("No edge content when boxes are interior")
    func boundsInfoNoEdgeContent() {
        let boxes = [
            CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3)
        ]

        let boundsInfo = BoundsInfo.from(boundingBoxes: boxes)

        #expect(!boundsInfo.hasEdgeContent)
        #expect(boundsInfo.affectedEdges.isEmpty)
    }

    @Test("DetectedBarcode mayBeClipped reflects edge-touching bounds")
    func detectedBarcodeMayBeClipped() {
        let clipped = DetectedBarcode(
            symbology: .code128,
            payload: "TEST",
            boundingBox: CGRect(x: 0.0, y: 0.5, width: 0.5, height: 0.2),
            confidence: 0.95
        )

        let notClipped = DetectedBarcode(
            symbology: .code128,
            payload: "TEST",
            boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.5, height: 0.2),
            confidence: 0.95
        )

        #expect(clipped.mayBeClipped)
        #expect(!notClipped.mayBeClipped)
    }
}

// MARK: - VerificationResult

@Suite("VerificationResult")
struct VerificationResultTests {

    @Test("Summary reports all passed")
    func verificationResultSummaryPassed() {
        let result = VerificationResult(
            passed: true,
            expectations: [
                ExpectationResult(description: "Test", passed: true)
            ],
            boundsInfo: BoundsInfo(),
            verificationTimeSeconds: 0.1
        )

        #expect(result.summary == "All 1 expectation(s) passed")
    }

    @Test("Summary reports first failure message")
    func verificationResultSummaryFailed() {
        let result = VerificationResult(
            passed: false,
            expectations: [
                ExpectationResult(description: "Test1", passed: true),
                ExpectationResult(description: "Test2", passed: false, failureMessage: "Not found")
            ],
            boundsInfo: BoundsInfo(),
            verificationTimeSeconds: 0.1
        )

        #expect(result.summary == "Failed: Not found")
    }

    @Test("passedExpectations / failedExpectations partition results")
    func verificationResultPassedFailedExpectations() {
        let result = VerificationResult(
            passed: false,
            expectations: [
                ExpectationResult(description: "Test1", passed: true),
                ExpectationResult(description: "Test2", passed: false),
                ExpectationResult(description: "Test3", passed: true)
            ],
            boundsInfo: BoundsInfo(),
            verificationTimeSeconds: 0.1
        )

        #expect(result.passedExpectations.count == 2)
        #expect(result.failedExpectations.count == 1)
    }
}

// MARK: - AnalysisResult

@Suite("AnalysisResult")
struct AnalysisResultTests {

    @Test("allText joins text regions with newlines")
    func analysisResultAllText() {
        let result = AnalysisResult(
            barcodes: [],
            textRegions: [
                DetectedText(text: "Hello", boundingBox: .zero, confidence: 0.9),
                DetectedText(text: "World", boundingBox: .zero, confidence: 0.9)
            ],
            boundsInfo: BoundsInfo(),
            analysisTimeSeconds: 0.1
        )

        #expect(result.allText == "Hello\nWorld")
    }

    @Test("allPayloads lists barcode payloads in order")
    func analysisResultAllPayloads() {
        let result = AnalysisResult(
            barcodes: [
                DetectedBarcode(symbology: .code128, payload: "ABC", boundingBox: .zero, confidence: 0.9),
                DetectedBarcode(symbology: .qr, payload: "XYZ", boundingBox: .zero, confidence: 0.9)
            ],
            textRegions: [],
            boundsInfo: BoundsInfo(),
            analysisTimeSeconds: 0.1
        )

        #expect(result.allPayloads == ["ABC", "XYZ"])
    }

    @Test("barcodes(of:) filters by symbology")
    func analysisResultFilterBySymbology() {
        let result = AnalysisResult(
            barcodes: [
                DetectedBarcode(symbology: .code128, payload: "ABC", boundingBox: .zero, confidence: 0.9),
                DetectedBarcode(symbology: .qr, payload: "XYZ", boundingBox: .zero, confidence: 0.9),
                DetectedBarcode(symbology: .code128, payload: "DEF", boundingBox: .zero, confidence: 0.9)
            ],
            textRegions: [],
            boundsInfo: BoundsInfo(),
            analysisTimeSeconds: 0.1
        )

        let code128Barcodes = result.barcodes(of: .code128)
        #expect(code128Barcodes.count == 2)
    }
}

// MARK: - Result Builder

@Suite("VerificationBuilder")
struct ResultBuilderTests {

    @Test("Two expectations collect into an array")
    func verificationBuilder() {
        @VerificationBuilder
        func buildExpectations() -> [any Expectation] {
            BarcodeExpectation(.code128)
            TextExpectation("HELLO")
        }

        #expect(buildExpectations().count == 2)
    }

    @Test("Multiple expectations collect into an array")
    func verificationBuilderMultipleExpectations() {
        @VerificationBuilder
        func buildExpectations() -> [any Expectation] {
            BarcodeExpectation(.code128)
            BarcodeExpectation(.qr)
            TextExpectation("HELLO")
        }

        #expect(buildExpectations().count == 3)
    }
}

// MARK: - VerifierError

@Suite("VerifierError")
struct VerifierErrorTests {

    /// Stub error used to exercise the underlying-error contract on VerifierError.
    private struct StubError: Error, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    @Test("invalidImage has fixed description and no underlying message")
    func verifierErrorInvalidImage() {
        let invalidImage = VerifierError.invalidImage
        #expect(invalidImage.errorDescription == "The provided image could not be processed")
        #expect(invalidImage.underlyingMessage == nil)
    }

    @Test("barcodeDetectionFailed wraps underlying error and message")
    func verifierErrorBarcodeDetectionFailed() {
        let underlying = StubError(message: "No barcodes found")
        let error = VerifierError.barcodeDetectionFailed(underlying: underlying)
        #expect(error.errorDescription?.contains("Barcode detection failed") ?? false)
        #expect(error.underlyingMessage == "No barcodes found")
        #expect(error.underlyingError is StubError)
    }

    @Test("textRecognitionFailed wraps underlying error and message")
    func verifierErrorTextRecognitionFailed() {
        let underlying = StubError(message: "OCR failed")
        let error = VerifierError.textRecognitionFailed(underlying: underlying)
        #expect(error.errorDescription?.contains("Text recognition failed") ?? false)
        #expect(error.underlyingMessage == "OCR failed")
        #expect(error.underlyingError is StubError)
    }

    @Test("unexpected carries the provided message")
    func verifierErrorUnexpected() {
        let error = VerifierError.unexpected("Something went wrong")
        #expect(error.errorDescription?.contains("Unexpected error") ?? false)
        #expect(error.underlyingMessage == "Something went wrong")
    }
}

// MARK: - BarcodeSymbology

@Suite("BarcodeSymbology")
struct BarcodeSymbologyTests {

    // description mapping per representative case.
    @Test(arguments: [
        (BarcodeSymbology.qr, "QR Code"),
        (.code128, "Code 128"),
        (.ean13, "EAN-13"),
        (.aztec, "Aztec"),
        (.pdf417, "PDF417"),
        (.dataMatrix, "Data Matrix"),
        (.i2of5, "Interleaved 2 of 5")
    ])
    func symbologyDescription(symbology: BarcodeSymbology, expected: String) {
        #expect(symbology.description == expected)
    }

    // rawValue mapping per representative case.
    @Test(arguments: [
        (BarcodeSymbology.qr, "qr"),
        (.code128, "code128"),
        (.ean13, "ean13")
    ])
    func symbologyRawValue(symbology: BarcodeSymbology, expected: String) {
        #expect(symbology.rawValue == expected)
    }

    @Test("Codable round-trips through JSON")
    func symbologyCodable() throws {
        let symbology = BarcodeSymbology.code128
        let data = try JSONEncoder().encode(symbology)
        let decoded = try JSONDecoder().decode(BarcodeSymbology.self, from: data)
        #expect(decoded == symbology)
    }

    // Every local case must round-trip cleanly through Vision and back.
    @Test(arguments: BarcodeSymbology.allCases)
    func symbologyVisionRoundTripIsComplete(symbology: BarcodeSymbology) {
        let roundTripped = BarcodeSymbology(vnSymbology: symbology.vnSymbology)
        #expect(roundTripped == symbology,
                "\(symbology) did not round-trip through Vision.BarcodeSymbology")
    }

    // Symbologies that were previously dropped by the scanner must map and describe.
    @Test(arguments: [
        BarcodeSymbology.codabar, .gs1DataBar, .gs1DataBarExpanded, .gs1DataBarLimited,
        .microPDF417, .microQR, .msiPlessey
    ])
    func symbologyNewlyAddedMapped(symbology: BarcodeSymbology) {
        #expect(BarcodeSymbology(vnSymbology: symbology.vnSymbology) != nil,
                "\(symbology) is dropped by init?(vnSymbology:)")
        #expect(!symbology.description.isEmpty)
    }

    @Test("CaseIterable exposes expected cases and count")
    func symbologyCaseIterable() {
        #expect(BarcodeSymbology.allCases.count > 10)
        #expect(BarcodeSymbology.allCases.contains(.qr))
        #expect(BarcodeSymbology.allCases.contains(.code128))
    }
}

// MARK: - Detected* Codable

@Suite("Detected Types Codable")
struct DetectedCodableTests {

    @Test("DetectedBarcode round-trips through JSON")
    func detectedBarcodeCodable() throws {
        let barcode = DetectedBarcode(
            symbology: .code128,
            payload: "TEST123",
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.5, height: 0.3),
            confidence: 0.95
        )

        let data = try JSONEncoder().encode(barcode)
        let decoded = try JSONDecoder().decode(DetectedBarcode.self, from: data)

        #expect(decoded.symbology == barcode.symbology)
        #expect(decoded.payload == barcode.payload)
        #expect(decoded.confidence == barcode.confidence)
    }

    @Test("DetectedText round-trips through JSON")
    func detectedTextCodable() throws {
        let text = DetectedText(
            text: "HELLO WORLD",
            boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
            confidence: 0.9
        )

        let data = try JSONEncoder().encode(text)
        let decoded = try JSONDecoder().decode(DetectedText.self, from: data)

        #expect(decoded.text == text.text)
        #expect(decoded.confidence == text.confidence)
    }
}

// MARK: - Integration (Vision)

@Suite("Verifier Integration")
struct VerifierIntegrationTests {

    @Test("analyze decodes a rendered QR code")
    func verifierAnalyzeQRCode() async throws {
        let testData = "https://zplkit.example.com"
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode(testData, at: .dots(100, 100))
                .magnification(8)
        }

        let renderResult = try ZPLRenderer().render(label.render())

        let verifier = ZPLVerifier()
        let result = try await verifier.analyze(renderResult.image)

        #expect(result.barcodes.count > 0)
        #expect(result.barcodes.contains(where: { $0.symbology == .qr }))
        #expect(result.allPayloads.contains(where: { $0.contains(testData) }))
    }

    @Test("analyze decodes a rendered Code 128 payload")
    func verifierAnalyzeCode128() async throws {
        let testData = "ABC123"
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128(testData, at: .dots(50, 50))?
                .height(.dots(100))
                .moduleWidth(3)
        }

        let renderResult = try ZPLRenderer().render(label.render())

        let verifier = ZPLVerifier()
        let result = try await verifier.analyze(renderResult.image)

        #expect(result.barcodes.contains(where: { $0.payload == testData }))
    }

    @Test("verify passes for exact Code 128 barcode")
    func verifierVerifyBarcode() async throws {
        let testData = "TEST123"
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128(testData, at: .dots(50, 50))?
                .height(.dots(100))
                .moduleWidth(3)
        }

        let renderResult = try ZPLRenderer().render(label.render())

        let verifier = ZPLVerifier()
        let result = try await verifier.verify(renderResult.image) {
            BarcodeExpectation(.code128, exactly: testData)
        }

        #expect(result.passed, "\(result.summary)")
    }

    @Test("verify passes for containing Code 128 barcode")
    func verifierVerifyBarcodeContaining() async throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("SKU-12345-ABC", at: .dots(50, 50))?
                .height(.dots(100))
                .moduleWidth(3)
        }

        let renderResult = try ZPLRenderer().render(label.render())

        let verifier = ZPLVerifier()
        let result = try await verifier.verify(renderResult.image) {
            BarcodeExpectation(.code128, containing: "12345")
        }

        #expect(result.passed, "\(result.summary)")
    }

    @Test("verify fails when expected barcode symbology is absent")
    func verifierVerifyMissingBarcode() async throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("ABC123", at: .dots(50, 50))?
                .height(.dots(100))
                .moduleWidth(3)
        }

        let renderResult = try ZPLRenderer().render(label.render())

        let verifier = ZPLVerifier()
        let result = try await verifier.verify(renderResult.image) {
            BarcodeExpectation(.qr)  // Looking for QR but only Code128 present
        }

        #expect(!result.passed)
        #expect(result.summary.contains("No qr"))
    }

    @Test("verify passes for multiple expectations")
    func verifierVerifyMultipleExpectations() async throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Barcode128("SKU-001", at: .dots(50, 50))?
                .height(.dots(80))
                .moduleWidth(3)
            QRCode("https://example.com", at: .dots(50, 200))
                .magnification(6)
        }

        let renderResult = try ZPLRenderer().render(label.render())

        let verifier = ZPLVerifier()
        let result = try await verifier.verify(renderResult.image) {
            BarcodeExpectation(.code128, containing: "SKU")
            BarcodeExpectation(.qr, containing: "example")
        }

        #expect(result.passed, "\(result.summary)")
        #expect(result.expectations.count == 2)
    }

    @Test("verify passes for recognized text")
    func verifierVerifyText() async throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            ZPLKit.Text("SHIPPING LABEL", at: .dots(50, 50))
                .font(.default, height: .dots(50), width: .dots(50))
        }

        let renderResult = try ZPLRenderer().render(label.render())

        let verifier = ZPLVerifier()
        let result = try await verifier.verify(renderResult.image) {
            TextExpectation("SHIPPING")
        }

        #expect(result.passed, "\(result.summary)")
    }

    @Test("fast configuration still decodes a barcode")
    func verifierConfigurationFast() async throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("FAST-TEST", at: .dots(100, 100))
                .magnification(8)
        }

        let renderResult = try ZPLRenderer().render(label.render())

        let verifier = ZPLVerifier(configuration: .fast)
        let result = try await verifier.analyze(renderResult.image)

        #expect(result.barcodes.count > 0)
    }

    @Test("analyze reports a positive analysis time")
    func verifierAnalysisTime() async throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("TEST", at: .dots(50, 50))?
                .height(.dots(100))
        }

        let renderResult = try ZPLRenderer().render(label.render())

        let verifier = ZPLVerifier()
        let result = try await verifier.analyze(renderResult.image)

        #expect(result.analysisTimeSeconds > 0)
    }

    @Test("verify reports a positive verification time")
    func verifierVerificationTime() async throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("TEST", at: .dots(50, 50))?
                .height(.dots(100))
        }

        let renderResult = try ZPLRenderer().render(label.render())

        let verifier = ZPLVerifier()
        let result = try await verifier.verify(renderResult.image) {
            BarcodeExpectation(.code128)
        }

        #expect(result.verificationTimeSeconds > 0)
    }
}


// MARK: - Input Validation

@Suite("Verifier Input Validation")
struct VerifierInputValidationTests {

    @Test("verify with an empty expectation list throws noExpectations")
    func verifyEmptyExpectationsThrows() async throws {
        // An empty list used to pass vacuously ("all 0 expectations passed"),
        // silently turning a caller's test green while checking nothing.
        let context = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let image = context.makeImage()!

        let verifier = ZPLVerifier()
        do {
            _ = try await verifier.verify(image, expectations: [])
            Issue.record("expected noExpectations to be thrown")
        } catch let error as VerifierError {
            guard case .noExpectations = error else {
                Issue.record("expected noExpectations, got \(error)")
                return
            }
        }
    }
}
