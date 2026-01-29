import XCTest
@testable import ZPLVerifier
@testable import ZPLKit
@testable import ZPLKitRenderer

final class ZPLVerifierTests: XCTestCase {

    // MARK: - Expectation Unit Tests

    func testBarcodeExpectationAny() {
        let expectation = Barcode(.code128)

        XCTAssertEqual(expectation.description, "Barcode(code128)")
        XCTAssertEqual(expectation.visionHints.symbologies, [.code128])
    }

    func testBarcodeExpectationContaining() {
        let expectation = Barcode(.qr, containing: "example.com")

        XCTAssertEqual(expectation.description, "Barcode(qr, containing: \"example.com\")")
        XCTAssertEqual(expectation.visionHints.symbologies, [.qr])
    }

    func testBarcodeExpectationExactly() {
        let expectation = Barcode(.code128, exactly: "ABC123")

        XCTAssertEqual(expectation.description, "Barcode(code128, exactly: \"ABC123\")")
    }

    func testTextExpectationContaining() {
        let expectation = Text("FRAGILE")

        XCTAssertEqual(expectation.description, "Text(containing: \"FRAGILE\")")
        XCTAssertTrue(expectation.visionHints.customWords.contains("FRAGILE"))
    }

    func testTextExpectationExactly() {
        let expectation = Text(exactly: "Hello World")

        XCTAssertEqual(expectation.description, "Text(exactly: \"Hello World\")")
    }

    // MARK: - Expectation Check Tests

    func testBarcodeExpectationCheckPass() {
        let expectation = Barcode(.code128, exactly: "ABC123")

        let barcodes = [
            DetectedBarcode(
                symbology: .code128,
                payload: "ABC123",
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.2),
                confidence: 0.95
            )
        ]

        let result = expectation.check(barcodes: barcodes, textRegions: [])

        XCTAssertTrue(result.passed)
        XCTAssertNil(result.failureMessage)
        XCTAssertNotNil(result.matchedItem)
    }

    func testBarcodeExpectationCheckFailMissingSymbology() {
        let expectation = Barcode(.code128)

        let barcodes = [
            DetectedBarcode(
                symbology: .qr,
                payload: "data",
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
                confidence: 0.95
            )
        ]

        let result = expectation.check(barcodes: barcodes, textRegions: [])

        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.failureMessage?.contains("No code128") ?? false)
    }

    func testBarcodeExpectationCheckFailWrongPayload() {
        let expectation = Barcode(.code128, exactly: "ABC123")

        let barcodes = [
            DetectedBarcode(
                symbology: .code128,
                payload: "XYZ789",
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.2),
                confidence: 0.95
            )
        ]

        let result = expectation.check(barcodes: barcodes, textRegions: [])

        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.failureMessage?.contains("XYZ789") ?? false)
    }

    func testBarcodeExpectationCheckContaining() {
        let expectation = Barcode(.qr, containing: "example")

        let barcodes = [
            DetectedBarcode(
                symbology: .qr,
                payload: "https://example.com/path",
                boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
                confidence: 0.95
            )
        ]

        let result = expectation.check(barcodes: barcodes, textRegions: [])

        XCTAssertTrue(result.passed)
    }

    func testTextExpectationCheckPass() {
        let expectation = Text("FRAGILE")

        let textRegions = [
            DetectedText(
                text: "HANDLE WITH CARE - FRAGILE",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.9
            )
        ]

        let result = expectation.check(barcodes: [], textRegions: textRegions)

        XCTAssertTrue(result.passed)
    }

    func testTextExpectationCheckPassCaseInsensitive() {
        let expectation = Text("fragile")

        let textRegions = [
            DetectedText(
                text: "FRAGILE",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.9
            )
        ]

        let result = expectation.check(barcodes: [], textRegions: textRegions)

        XCTAssertTrue(result.passed)
    }

    func testTextExpectationCheckFailNotFound() {
        let expectation = Text("MISSING")

        let textRegions = [
            DetectedText(
                text: "HELLO WORLD",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.9
            )
        ]

        let result = expectation.check(barcodes: [], textRegions: textRegions)

        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.failureMessage?.contains("MISSING") ?? false)
    }

    func testTextExpectationExactlyCheckPass() {
        let expectation = Text(exactly: "Hello World")

        let textRegions = [
            DetectedText(
                text: "Hello World",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.9
            )
        ]

        let result = expectation.check(barcodes: [], textRegions: textRegions)

        XCTAssertTrue(result.passed)
    }

    func testTextExpectationExactlyCheckFailPartialMatch() {
        let expectation = Text(exactly: "Hello")

        let textRegions = [
            DetectedText(
                text: "Hello World",
                boundingBox: CGRect(x: 0.1, y: 0.5, width: 0.8, height: 0.1),
                confidence: 0.9
            )
        ]

        let result = expectation.check(barcodes: [], textRegions: textRegions)

        XCTAssertFalse(result.passed)
    }

    // MARK: - VisionHints Tests

    func testVisionHintsMerge() {
        let hints1 = VisionHints(symbologies: [.code128], customWords: ["HELLO"])
        let hints2 = VisionHints(symbologies: [.qr], customWords: ["WORLD"])

        let merged = VisionHints.merge([hints1, hints2])

        XCTAssertEqual(merged.symbologies, [.code128, .qr])
        XCTAssertEqual(merged.customWords, ["HELLO", "WORLD"])
    }

    func testVisionHintsMerging() {
        let hints1 = VisionHints(symbologies: [.code128])
        let hints2 = VisionHints(symbologies: [.code128, .qr])

        let merged = hints1.merging(hints2)

        XCTAssertEqual(merged.symbologies.count, 2)
        XCTAssertTrue(merged.symbologies.contains(.code128))
        XCTAssertTrue(merged.symbologies.contains(.qr))
    }

    // MARK: - BoundsInfo Tests

    func testBoundsInfoEdgeDetection() {
        let boxes = [
            CGRect(x: 0.0, y: 0.5, width: 0.1, height: 0.1),  // left edge
            CGRect(x: 0.5, y: 0.99, width: 0.1, height: 0.01) // top edge
        ]

        let boundsInfo = BoundsInfo.from(boundingBoxes: boxes)

        XCTAssertTrue(boundsInfo.hasLeftEdgeContent)
        XCTAssertTrue(boundsInfo.hasTopEdgeContent)
        XCTAssertFalse(boundsInfo.hasRightEdgeContent)
        XCTAssertFalse(boundsInfo.hasBottomEdgeContent)
        XCTAssertTrue(boundsInfo.hasEdgeContent)
    }

    func testBoundsInfoNoEdgeContent() {
        let boxes = [
            CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3)
        ]

        let boundsInfo = BoundsInfo.from(boundingBoxes: boxes)

        XCTAssertFalse(boundsInfo.hasEdgeContent)
        XCTAssertTrue(boundsInfo.affectedEdges.isEmpty)
    }

    func testDetectedBarcodeMayBeClipped() {
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

        XCTAssertTrue(clipped.mayBeClipped)
        XCTAssertFalse(notClipped.mayBeClipped)
    }

    // MARK: - VerificationResult Tests

    func testVerificationResultSummaryPassed() {
        let result = VerificationResult(
            passed: true,
            expectations: [
                ExpectationResult(description: "Test", passed: true)
            ],
            boundsInfo: BoundsInfo(),
            verificationTimeSeconds: 0.1
        )

        XCTAssertEqual(result.summary, "All 1 expectation(s) passed")
    }

    func testVerificationResultSummaryFailed() {
        let result = VerificationResult(
            passed: false,
            expectations: [
                ExpectationResult(description: "Test1", passed: true),
                ExpectationResult(description: "Test2", passed: false, failureMessage: "Not found")
            ],
            boundsInfo: BoundsInfo(),
            verificationTimeSeconds: 0.1
        )

        XCTAssertEqual(result.summary, "Failed: Not found")
    }

    func testVerificationResultPassedFailedExpectations() {
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

        XCTAssertEqual(result.passedExpectations.count, 2)
        XCTAssertEqual(result.failedExpectations.count, 1)
    }

    // MARK: - AnalysisResult Tests

    func testAnalysisResultAllText() {
        let result = AnalysisResult(
            barcodes: [],
            textRegions: [
                DetectedText(text: "Hello", boundingBox: .zero, confidence: 0.9),
                DetectedText(text: "World", boundingBox: .zero, confidence: 0.9)
            ],
            boundsInfo: BoundsInfo(),
            analysisTimeSeconds: 0.1
        )

        XCTAssertEqual(result.allText, "Hello\nWorld")
    }

    func testAnalysisResultAllPayloads() {
        let result = AnalysisResult(
            barcodes: [
                DetectedBarcode(symbology: .code128, payload: "ABC", boundingBox: .zero, confidence: 0.9),
                DetectedBarcode(symbology: .qr, payload: "XYZ", boundingBox: .zero, confidence: 0.9)
            ],
            textRegions: [],
            boundsInfo: BoundsInfo(),
            analysisTimeSeconds: 0.1
        )

        XCTAssertEqual(result.allPayloads, ["ABC", "XYZ"])
    }

    func testAnalysisResultFilterBySymbology() {
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
        XCTAssertEqual(code128Barcodes.count, 2)
    }

    // MARK: - Result Builder Tests

    func testVerificationBuilder() {
        @VerificationBuilder
        func buildExpectations() -> [any Expectation] {
            Barcode(.code128)
            Text("HELLO")
        }

        let expectations = buildExpectations()
        XCTAssertEqual(expectations.count, 2)
    }

    func testVerificationBuilderMultipleExpectations() {
        @VerificationBuilder
        func buildExpectations() -> [any Expectation] {
            Barcode(.code128)
            Barcode(.qr)
            Text("HELLO")
        }

        let expectations = buildExpectations()
        XCTAssertEqual(expectations.count, 3)
    }

    // MARK: - Integration Tests

    func testVerifierAnalyzeQRCode() throws {
        let testData = "https://zplkit.example.com"
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode(testData, at: .dots(100, 100))
                .magnification(8)
        }

        let zpl = label.render()
        let renderer = ZPLRenderer()
        let renderResult = try renderer.render(zpl, dpi: .dpi203)

        let verifier = ZPLVerifier()
        let result = try verifier.analyze(renderResult.image)

        XCTAssertGreaterThan(result.barcodes.count, 0)
        XCTAssertTrue(result.barcodes.contains(where: { $0.symbology == .qr }))
        XCTAssertTrue(result.allPayloads.contains(where: { $0.contains(testData) }))
    }

    func testVerifierAnalyzeCode128() throws {
        let testData = "ABC123"
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128(testData, at: .dots(50, 50))?
                .height(.dots(100))
                .moduleWidth(3)
        }

        let zpl = label.render()
        let renderer = ZPLRenderer()
        let renderResult = try renderer.render(zpl, dpi: .dpi203)

        let verifier = ZPLVerifier()
        let result = try verifier.analyze(renderResult.image)

        XCTAssertTrue(result.barcodes.contains(where: { $0.payload == testData }))
    }

    func testVerifierVerifyBarcode() throws {
        let testData = "TEST123"
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128(testData, at: .dots(50, 50))?
                .height(.dots(100))
                .moduleWidth(3)
        }

        let zpl = label.render()
        let renderer = ZPLRenderer()
        let renderResult = try renderer.render(zpl, dpi: .dpi203)

        let verifier = ZPLVerifier()
        let result = try verifier.verify(renderResult.image) {
            Barcode(.code128, exactly: testData)
        }

        XCTAssertTrue(result.passed, result.summary)
    }

    func testVerifierVerifyBarcodeContaining() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("SKU-12345-ABC", at: .dots(50, 50))?
                .height(.dots(100))
                .moduleWidth(3)
        }

        let zpl = label.render()
        let renderer = ZPLRenderer()
        let renderResult = try renderer.render(zpl, dpi: .dpi203)

        let verifier = ZPLVerifier()
        let result = try verifier.verify(renderResult.image) {
            Barcode(.code128, containing: "12345")
        }

        XCTAssertTrue(result.passed, result.summary)
    }

    func testVerifierVerifyMissingBarcode() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("ABC123", at: .dots(50, 50))?
                .height(.dots(100))
                .moduleWidth(3)
        }

        let zpl = label.render()
        let renderer = ZPLRenderer()
        let renderResult = try renderer.render(zpl, dpi: .dpi203)

        let verifier = ZPLVerifier()
        let result = try verifier.verify(renderResult.image) {
            Barcode(.qr)  // Looking for QR but only Code128 present
        }

        XCTAssertFalse(result.passed)
        XCTAssertTrue(result.summary.contains("No qr"))
    }

    func testVerifierVerifyMultipleExpectations() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            Barcode128("SKU-001", at: .dots(50, 50))?
                .height(.dots(80))
                .moduleWidth(3)
            QRCode("https://example.com", at: .dots(50, 200))
                .magnification(6)
        }

        let zpl = label.render()
        let renderer = ZPLRenderer()
        let renderResult = try renderer.render(zpl, dpi: .dpi203)

        let verifier = ZPLVerifier()
        let result = try verifier.verify(renderResult.image) {
            Barcode(.code128, containing: "SKU")
            Barcode(.qr, containing: "example")
        }

        XCTAssertTrue(result.passed, result.summary)
        XCTAssertEqual(result.expectations.count, 2)
    }

    func testVerifierVerifyText() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            ZPLKit.Text("SHIPPING LABEL", at: .dots(50, 50))
                .font(.default, height: .dots(50), width: .dots(50))
        }

        let zpl = label.render()
        let renderer = ZPLRenderer()
        let renderResult = try renderer.render(zpl, dpi: .dpi203)

        let verifier = ZPLVerifier()
        let result = try verifier.verify(renderResult.image) {
            Text("SHIPPING")
        }

        XCTAssertTrue(result.passed, result.summary)
    }

    func testVerifierConfigurationFast() throws {
        let label = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
            QRCode("FAST-TEST", at: .dots(100, 100))
                .magnification(8)
        }

        let zpl = label.render()
        let renderer = ZPLRenderer()
        let renderResult = try renderer.render(zpl, dpi: .dpi203)

        let verifier = ZPLVerifier(configuration: .fast)
        let result = try verifier.analyze(renderResult.image)

        XCTAssertGreaterThan(result.barcodes.count, 0)
    }

    func testVerifierAnalysisTime() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("TEST", at: .dots(50, 50))?
                .height(.dots(100))
        }

        let zpl = label.render()
        let renderer = ZPLRenderer()
        let renderResult = try renderer.render(zpl, dpi: .dpi203)

        let verifier = ZPLVerifier()
        let result = try verifier.analyze(renderResult.image)

        XCTAssertGreaterThan(result.analysisTimeSeconds, 0)
    }

    func testVerifierVerificationTime() throws {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Barcode128("TEST", at: .dots(50, 50))?
                .height(.dots(100))
        }

        let zpl = label.render()
        let renderer = ZPLRenderer()
        let renderResult = try renderer.render(zpl, dpi: .dpi203)

        let verifier = ZPLVerifier()
        let result = try verifier.verify(renderResult.image) {
            Barcode(.code128)
        }

        XCTAssertGreaterThan(result.verificationTimeSeconds, 0)
    }
}
