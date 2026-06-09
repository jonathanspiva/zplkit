import Foundation
import CoreGraphics
import Testing
@testable import ZPLKitVerifier

/// `Testing.Expectation` and the verifier's `Expectation` protocol collide by name.
/// A specific protocol import disambiguates so the result builder can name the protocol.
import protocol ZPLKitVerifier.Expectation

// MARK: - Result Builder (all builder methods)
//
// These pin every method on `VerificationBuilder` that the existing test file
// does not exercise: empty/single blocks, buildArray (for-loops), buildOptional
// (if without else), buildEither (if/else), and ordering preservation.

@Suite("VerificationBuilder methods")
struct VerificationBuilderMethodTests {

    @Test("Empty block produces zero expectations")
    func emptyBlock() {
        @VerificationBuilder
        func build() -> [any Expectation] {
        }
        #expect(build().isEmpty)
    }

    @Test("Single expectation block produces one expectation")
    func singleBlock() {
        @VerificationBuilder
        func build() -> [any Expectation] {
            Barcode(.code128)
        }
        let result = build()
        #expect(result.count == 1)
        #expect(result[0].description == "Barcode(code128)")
    }

    @Test("Block preserves declaration order")
    func ordering() {
        @VerificationBuilder
        func build() -> [any Expectation] {
            Text("FIRST")
            Barcode(.qr)
            Text("LAST")
        }
        let result = build()
        #expect(result.count == 3)
        #expect(result[0].description == "Text(containing: \"FIRST\")")
        #expect(result[1].description == "Barcode(qr)")
        #expect(result[2].description == "Text(containing: \"LAST\")")
    }

    // NOTE: The control-flow builder methods (buildArray / buildOptional /
    // buildEither / buildLimitedAvailability) cannot be exercised through DSL
    // syntax. `buildBlock` is declared as `(_ components: (any Expectation)...)`
    // (variadic of single expectations), so it cannot consume the
    // `[any Expectation]` that a `for`/`if`/`if-else` partial result produces.
    // Writing `for ... { Text(...) }` or `if cond { ... }` inside a
    // @VerificationBuilder block fails to compile:
    //   "argument type '[any Expectation]' does not conform to expected type 'Expectation'".
    // Those methods are therefore effectively dead code via the DSL. We pin them
    // by calling the static methods directly below so a future fix (changing
    // buildBlock to accept `[any Expectation]...` and flatten) is detectable, and
    // so the behavior of each method is still under test.

    @Test("buildArray static method flattens nested arrays directly")
    func buildArrayDirect() {
        let nested: [[any Expectation]] = [
            [Barcode(.code128)],
            [],
            [Text("X"), Text("Y")]
        ]
        let flat = VerificationBuilder.buildArray(nested)
        #expect(flat.count == 3)
    }

    @Test("buildOptional static method maps nil to empty")
    func buildOptionalNilDirect() {
        let none: [any Expectation]? = nil
        #expect(VerificationBuilder.buildOptional(none).isEmpty)
    }

    @Test("buildOptional static method passes a present component through")
    func buildOptionalSomeDirect() {
        let some: [any Expectation]? = [Barcode(.code128)]
        #expect(VerificationBuilder.buildOptional(some).count == 1)
    }

    @Test("buildEither(first:) returns the first component")
    func buildEitherFirstDirect() {
        let first: [any Expectation] = [Text("A")]
        #expect(VerificationBuilder.buildEither(first: first).count == 1)
    }

    @Test("buildEither(second:) returns the second component")
    func buildEitherSecondDirect() {
        let second: [any Expectation] = [Text("B"), Barcode(.qr)]
        #expect(VerificationBuilder.buildEither(second: second).count == 2)
    }

    @Test("buildExpression wraps a single expectation")
    func buildExpressionDirect() {
        let expr = VerificationBuilder.buildExpression(Barcode(.qr))
        #expect(expr.description == "Barcode(qr)")
    }

    @Test("buildBlock with no arguments yields an empty array")
    func buildBlockEmptyDirect() {
        #expect(VerificationBuilder.buildBlock().isEmpty)
    }

    @Test("buildLimitedAvailability passes the component through unchanged")
    func buildLimitedAvailabilityDirect() {
        let component: [any Expectation] = [Barcode(.qr), Text("Z")]
        let result = VerificationBuilder.buildLimitedAvailability(component)
        #expect(result.count == 2)
    }
}

// MARK: - Text matching: case sensitivity and substring semantics
//
// Pins the documented design: `Text(containing:)` is case-insensitive,
// `Text(exactly:)` is case-sensitive and whole-string. Includes near-misses
// that MUST fail to catch false-passes.

@Suite("Text matching semantics")
struct TextMatchingTests {

    @Test("containing: matches a case-mismatched substring (case-insensitive by design)")
    func containingCaseInsensitive() {
        let expectation = Text("fragile")
        let regions = [DetectedText(text: "HANDLE WITH CARE - FRAGILE", boundingBox: .zero, confidence: 1)]
        #expect(expectation.check(barcodes: [], textRegions: regions).passed)
    }

    @Test("containing: matches when expectation is upper and detection is lower")
    func containingCaseInsensitiveReverse() {
        let expectation = Text("FRAGILE")
        let regions = [DetectedText(text: "fragile item", boundingBox: .zero, confidence: 1)]
        #expect(expectation.check(barcodes: [], textRegions: regions).passed)
    }

    @Test("containing: scans across multiple regions and matches the right one")
    func containingMultipleRegions() {
        let expectation = Text("WORLD")
        let regions = [
            DetectedText(text: "hello", boundingBox: .zero, confidence: 1),
            DetectedText(text: "big world here", boundingBox: .zero, confidence: 1)
        ]
        #expect(expectation.check(barcodes: [], textRegions: regions).passed)
    }

    @Test("containing: fails when substring is absent (near-miss)")
    func containingNearMissFails() {
        let expectation = Text("FRAGILE")
        let regions = [DetectedText(text: "FRAGILITY", boundingBox: .zero, confidence: 1)]
        // "FRAGILE" is not a substring of "FRAGILITY".
        let result = expectation.check(barcodes: [], textRegions: regions)
        #expect(!result.passed)
    }

    @Test("containing: with no detected text reports (no text detected)")
    func containingNoTextDetected() {
        let expectation = Text("ANYTHING")
        let result = expectation.check(barcodes: [], textRegions: [])
        #expect(!result.passed)
        #expect(result.failureMessage?.contains("(no text detected)") ?? false)
    }

    @Test("exactly: is case-sensitive and fails on case mismatch (near-miss)")
    func exactlyCaseSensitiveFails() {
        let expectation = Text(exactly: "Hello World")
        let regions = [DetectedText(text: "hello world", boundingBox: .zero, confidence: 1)]
        // exactly: uses == which is case-sensitive; lowercased detection must fail.
        #expect(!expectation.check(barcodes: [], textRegions: regions).passed)
    }

    @Test("exactly: matches an identical string")
    func exactlyMatches() {
        let expectation = Text(exactly: "Hello World")
        let regions = [DetectedText(text: "Hello World", boundingBox: .zero, confidence: 1)]
        #expect(expectation.check(barcodes: [], textRegions: regions).passed)
    }

    @Test("exactly: fails when detection has extra surrounding text (whole-string match)")
    func exactlyRejectsSuperstring() {
        let expectation = Text(exactly: "LABEL")
        let regions = [DetectedText(text: "SHIPPING LABEL", boundingBox: .zero, confidence: 1)]
        #expect(!expectation.check(barcodes: [], textRegions: regions).passed)
    }

    @Test("matched item is the detected text on a passing containing: check")
    func containingMatchedItem() {
        let expectation = Text("OK")
        let detection = DetectedText(text: "STATUS OK", boundingBox: .zero, confidence: 1)
        let result = expectation.check(barcodes: [], textRegions: [detection])
        #expect(result.passed)
        if case .text(let matched)? = result.matchedItem {
            #expect(matched.text == "STATUS OK")
        } else {
            Issue.record("Expected a matched text item")
        }
    }
}

// MARK: - Barcode matching: symbology and payload near-misses
//
// Explicitly asserts that symbology mismatch and payload mismatch FAIL, and
// that .any only validates symbology presence.

@Suite("Barcode matching semantics")
struct BarcodeMatchingTests {

    private func bc(_ sym: BarcodeSymbology, _ payload: String) -> DetectedBarcode {
        DetectedBarcode(symbology: sym, payload: payload, boundingBox: .zero, confidence: 1)
    }

    @Test("any: passes when symbology is present regardless of payload")
    func anyPasses() {
        let result = Barcode(.qr).check(barcodes: [bc(.qr, "whatever")], textRegions: [])
        #expect(result.passed)
    }

    @Test("any: fails when symbology is absent")
    func anyMissingSymbology() {
        let result = Barcode(.qr).check(barcodes: [bc(.code128, "x")], textRegions: [])
        #expect(!result.passed)
        #expect(result.failureMessage?.contains("No qr") ?? false)
    }

    @Test("exactly: fails when only the symbology differs (right payload, wrong type)")
    func exactlyWrongSymbology() {
        // Payload matches, but symbology does not: must fail.
        let result = Barcode(.qr, exactly: "ABC").check(barcodes: [bc(.code128, "ABC")], textRegions: [])
        #expect(!result.passed)
        #expect(result.failureMessage?.contains("No qr") ?? false)
    }

    @Test("exactly: fails on payload mismatch even with correct symbology (near-miss)")
    func exactlyWrongPayload() {
        let result = Barcode(.code128, exactly: "ABC123").check(barcodes: [bc(.code128, "ABC124")], textRegions: [])
        #expect(!result.passed)
        #expect(result.failureMessage?.contains("ABC124") ?? false)
    }

    @Test("exactly: is case-sensitive on payload (near-miss)")
    func exactlyCaseSensitivePayload() {
        let result = Barcode(.code128, exactly: "abc").check(barcodes: [bc(.code128, "ABC")], textRegions: [])
        #expect(!result.passed)
    }

    @Test("containing: payload substring is CASE-SENSITIVE (uses String.contains, not localized)")
    func containingPayloadCaseSensitive() {
        // BarcodeExpectation uses payload.contains(substring) which is case-sensitive,
        // UNLIKE Text(containing:) which is case-insensitive. Pin this asymmetry so a
        // regression toward case-insensitive barcode matching is caught.
        let result = Barcode(.qr, containing: "abc").check(barcodes: [bc(.qr, "XYZABC123")], textRegions: [])
        #expect(!result.passed)
    }

    @Test("containing: matches a case-exact substring")
    func containingPayloadMatches() {
        let result = Barcode(.qr, containing: "ABC").check(barcodes: [bc(.qr, "XYZABC123")], textRegions: [])
        #expect(result.passed)
    }

    @Test("exactly: picks the matching barcode among several of the same symbology")
    func exactlyAmongMany() {
        let barcodes = [bc(.code128, "WRONG1"), bc(.code128, "RIGHT"), bc(.code128, "WRONG2")]
        let result = Barcode(.code128, exactly: "RIGHT").check(barcodes: barcodes, textRegions: [])
        #expect(result.passed)
        if case .barcode(let matched)? = result.matchedItem {
            #expect(matched.payload == "RIGHT")
        } else {
            Issue.record("Expected a matched barcode item")
        }
    }

    @Test("containing: failure message lists all candidate payloads")
    func containingFailureListsCandidates() {
        let barcodes = [bc(.code128, "FOO"), bc(.code128, "BAR")]
        let result = Barcode(.code128, containing: "ZZZ").check(barcodes: barcodes, textRegions: [])
        #expect(!result.passed)
        #expect(result.failureMessage?.contains("FOO") ?? false)
        #expect(result.failureMessage?.contains("BAR") ?? false)
    }
}

// MARK: - BoundsInfo coordinate mapping (Vision bottom-left origin)
//
// Vision uses a normalized, bottom-left origin. So a box near maxY≈1.0 is the
// TOP edge of the image, and a box near minY≈0.0 is the BOTTOM edge. These
// tests pin that mapping so a future flip (a classic origin bug) is caught.

@Suite("BoundsInfo coordinate mapping")
struct BoundsInfoMappingTests {

    @Test("maxY near 1.0 maps to the TOP edge, not bottom")
    func maxYIsTop() {
        // Box sitting at the top of the image in Vision coords.
        let box = CGRect(x: 0.4, y: 0.97, width: 0.2, height: 0.03)
        let info = BoundsInfo.from(boundingBoxes: [box])
        #expect(info.hasTopEdgeContent)
        #expect(!info.hasBottomEdgeContent)
    }

    @Test("minY near 0.0 maps to the BOTTOM edge, not top")
    func minYIsBottom() {
        let box = CGRect(x: 0.4, y: 0.0, width: 0.2, height: 0.01)
        let info = BoundsInfo.from(boundingBoxes: [box])
        #expect(info.hasBottomEdgeContent)
        #expect(!info.hasTopEdgeContent)
    }

    @Test("minX near 0.0 maps to the LEFT edge")
    func minXIsLeft() {
        let box = CGRect(x: 0.0, y: 0.5, width: 0.05, height: 0.05)
        let info = BoundsInfo.from(boundingBoxes: [box])
        #expect(info.hasLeftEdgeContent)
        #expect(!info.hasRightEdgeContent)
    }

    @Test("maxX near 1.0 maps to the RIGHT edge")
    func maxXIsRight() {
        let box = CGRect(x: 0.96, y: 0.5, width: 0.04, height: 0.05)
        let info = BoundsInfo.from(boundingBoxes: [box])
        #expect(info.hasRightEdgeContent)
        #expect(!info.hasLeftEdgeContent)
    }

    @Test("threshold boundary: just inside 2% margin is NOT flagged")
    func thresholdJustInside() {
        // minY = 0.025 > 0.02 threshold, maxY = 0.975 < 0.98 threshold.
        let box = CGRect(x: 0.025, y: 0.025, width: 0.95, height: 0.95)
        let info = BoundsInfo.from(boundingBoxes: [box])
        #expect(!info.hasEdgeContent)
    }

    @Test("custom threshold widens edge detection")
    func customThreshold() {
        let box = CGRect(x: 0.5, y: 0.9, width: 0.05, height: 0.05) // maxY = 0.95
        let strict = BoundsInfo.from(boundingBoxes: [box], threshold: 0.02) // 0.95 < 0.98
        let loose = BoundsInfo.from(boundingBoxes: [box], threshold: 0.1)   // 0.95 > 0.90
        #expect(!strict.hasTopEdgeContent)
        #expect(loose.hasTopEdgeContent)
    }

    @Test("a box spanning the full image flags all four edges")
    func fullSpanAllEdges() {
        let box = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 1.0)
        let info = BoundsInfo.from(boundingBoxes: [box])
        #expect(info.affectedEdges.count == 4)
        #expect(Set(info.affectedEdges) == Set(BoundsInfo.Edge.allCases))
    }

    @Test("empty bounding-box list flags no edges")
    func emptyBoxes() {
        let info = BoundsInfo.from(boundingBoxes: [])
        #expect(!info.hasEdgeContent)
        #expect(info.affectedEdges.isEmpty)
    }

    @Test("affectedEdges order is top, bottom, left, right")
    func affectedEdgesOrder() {
        let info = BoundsInfo(
            hasTopEdgeContent: true,
            hasBottomEdgeContent: true,
            hasLeftEdgeContent: true,
            hasRightEdgeContent: true
        )
        #expect(info.affectedEdges == [.top, .bottom, .left, .right])
    }
}

// MARK: - DetectedText / DetectedBarcode pure logic

@Suite("DetectedText logic")
struct DetectedTextLogicTests {

    @Test("mayBeClipped is true when touching the left edge")
    func clippedLeft() {
        let t = DetectedText(text: "X", boundingBox: CGRect(x: 0.0, y: 0.5, width: 0.1, height: 0.1), confidence: 1)
        #expect(t.mayBeClipped)
    }

    @Test("mayBeClipped is true when extending past the top edge (maxY > 0.98)")
    func clippedTop() {
        let t = DetectedText(text: "X", boundingBox: CGRect(x: 0.4, y: 0.95, width: 0.1, height: 0.05), confidence: 1)
        #expect(t.mayBeClipped)
    }

    @Test("mayBeClipped is false for a centered interior box")
    func notClipped() {
        let t = DetectedText(text: "X", boundingBox: CGRect(x: 0.3, y: 0.3, width: 0.3, height: 0.3), confidence: 1)
        #expect(!t.mayBeClipped)
    }

    @Test("description quotes the text")
    func description() {
        let t = DetectedText(text: "HELLO", boundingBox: .zero, confidence: 1)
        #expect(t.description == "\"HELLO\"")
    }

    @Test("Equatable / Hashable distinguishes differing text")
    func equality() {
        let a = DetectedText(text: "A", boundingBox: .zero, confidence: 1)
        let b = DetectedText(text: "B", boundingBox: .zero, confidence: 1)
        let a2 = DetectedText(text: "A", boundingBox: .zero, confidence: 1)
        #expect(a == a2)
        #expect(a != b)
        #expect(Set([a, b, a2]).count == 2)
    }
}

@Suite("DetectedBarcode logic")
struct DetectedBarcodeLogicTests {

    @Test("description renders 'symbology: payload'")
    func description() {
        let b = DetectedBarcode(symbology: .qr, payload: "DATA", boundingBox: .zero, confidence: 1)
        // BarcodeSymbology.description (human-readable) is interpolated, not rawValue.
        #expect(b.description == "QR Code: DATA")
    }

    @Test("mayBeClipped reflects right-edge proximity")
    func clippedRight() {
        let b = DetectedBarcode(symbology: .code128, payload: "X",
                                boundingBox: CGRect(x: 0.6, y: 0.4, width: 0.4, height: 0.2), confidence: 1)
        #expect(b.mayBeClipped) // maxX = 1.0 > 0.98
    }
}

// MARK: - AnalysisResult helpers (case-insensitive text filter)

@Suite("AnalysisResult helpers")
struct AnalysisResultHelperTests {

    private func makeResult(
        barcodes: [DetectedBarcode] = [],
        textRegions: [DetectedText] = []
    ) -> AnalysisResult {
        AnalysisResult(barcodes: barcodes, textRegions: textRegions,
                       boundsInfo: BoundsInfo(), analysisTimeSeconds: 0.1)
    }

    @Test("textRegions(containing:) is case-insensitive")
    func textRegionsContainingCaseInsensitive() {
        let result = makeResult(textRegions: [
            DetectedText(text: "FRAGILE", boundingBox: .zero, confidence: 1),
            DetectedText(text: "heavy", boundingBox: .zero, confidence: 1)
        ])
        #expect(result.textRegions(containing: "fragile").count == 1)
        #expect(result.textRegions(containing: "HEAVY").count == 1)
        #expect(result.textRegions(containing: "missing").isEmpty)
    }

    @Test("allText is empty string when no regions")
    func allTextEmpty() {
        #expect(makeResult().allText == "")
    }

    @Test("allPayloads is empty when no barcodes")
    func allPayloadsEmpty() {
        #expect(makeResult().allPayloads.isEmpty)
    }

    @Test("barcodes(of:) returns empty for an absent symbology")
    func barcodesOfAbsent() {
        let result = makeResult(barcodes: [
            DetectedBarcode(symbology: .qr, payload: "x", boundingBox: .zero, confidence: 1)
        ])
        #expect(result.barcodes(of: .code128).isEmpty)
    }
}

// MARK: - VerificationResult aggregation

@Suite("VerificationResult aggregation")
struct VerificationResultAggregationTests {

    @Test("Empty expectations summary reports 'All 0 expectation(s) passed' when passed")
    func emptyPassed() {
        let result = VerificationResult(passed: true, expectations: [],
                                        boundsInfo: BoundsInfo(), verificationTimeSeconds: 0.0)
        #expect(result.summary == "All 0 expectation(s) passed")
        #expect(result.passedExpectations.isEmpty)
        #expect(result.failedExpectations.isEmpty)
    }

    @Test("Multiple failures are joined with '; ' in summary")
    func multipleFailuresJoined() {
        let result = VerificationResult(
            passed: false,
            expectations: [
                ExpectationResult(description: "A", passed: false, failureMessage: "missing A"),
                ExpectationResult(description: "B", passed: false, failureMessage: "missing B")
            ],
            boundsInfo: BoundsInfo(),
            verificationTimeSeconds: 0.0
        )
        #expect(result.summary == "Failed: missing A; missing B")
    }

    @Test("Summary falls back to description when a failed expectation has no message")
    func failureNoMessageFallsBackToDescription() {
        let result = VerificationResult(
            passed: false,
            expectations: [
                ExpectationResult(description: "DESC-FALLBACK", passed: false, failureMessage: nil)
            ],
            boundsInfo: BoundsInfo(),
            verificationTimeSeconds: 0.0
        )
        #expect(result.summary == "Failed: DESC-FALLBACK")
    }

    @Test("description property equals summary")
    func descriptionEqualsSummary() {
        let result = VerificationResult(passed: true, expectations: [],
                                        boundsInfo: BoundsInfo(), verificationTimeSeconds: 0.0)
        #expect(result.description == result.summary)
    }
}

// MARK: - BarcodeSymbology pure conversions

@Suite("BarcodeSymbology grouped descriptions")
struct BarcodeSymbologyGroupingTests {

    // Several distinct cases collapse to one human-readable description.
    @Test(arguments: [
        BarcodeSymbology.code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum
    ])
    func code39Variants(symbology: BarcodeSymbology) {
        #expect(symbology.description == "Code 39")
    }

    @Test(arguments: [BarcodeSymbology.code93, .code93i])
    func code93Variants(symbology: BarcodeSymbology) {
        #expect(symbology.description == "Code 93")
    }

    @Test(arguments: [BarcodeSymbology.i2of5, .i2of5Checksum])
    func i2of5Variants(symbology: BarcodeSymbology) {
        #expect(symbology.description == "Interleaved 2 of 5")
    }

    @Test("rawValue is the case name and round-trips via RawRepresentable")
    func rawValueRoundTrip() {
        for symbology in BarcodeSymbology.allCases {
            let reconstructed = BarcodeSymbology(rawValue: symbology.rawValue)
            #expect(reconstructed == symbology)
        }
    }

    @Test("No symbology has an empty description")
    func noEmptyDescriptions() {
        for symbology in BarcodeSymbology.allCases {
            #expect(!symbology.description.isEmpty)
        }
    }
}

// MARK: - VisionHints derivation from expectations

@Suite("VisionHints derivation")
struct VisionHintsDerivationTests {

    @Test("Text(containing:) drops words shorter than 3 chars from custom words")
    func shortWordsDropped() {
        let hints = Text("OK go now").visionHints
        // "OK" (2) and "go" (2) are dropped; "now" (3) is kept.
        #expect(!hints.customWords.contains("OK"))
        #expect(!hints.customWords.contains("go"))
        #expect(hints.customWords.contains("now"))
    }

    @Test("Text(exactly:) splits on whitespace and punctuation for custom words")
    func exactlySplitsPunctuation() {
        let hints = Text(exactly: "SKU-12345, ABCDEF").visionHints
        #expect(hints.customWords.contains("12345"))
        #expect(hints.customWords.contains("ABCDEF"))
        #expect(hints.customWords.contains("SKU"))
    }

    @Test("Very short text expectation yields no custom words")
    func tinyTextNoHints() {
        #expect(Text("OK").visionHints.customWords.isEmpty)
    }

    @Test("Barcode visionHints carries only the symbology, no custom words")
    func barcodeHints() {
        let hints = Barcode(.pdf417, exactly: "PAYLOAD").visionHints
        #expect(hints.symbologies == [.pdf417])
        #expect(hints.customWords.isEmpty)
    }

    @Test("VisionHints.empty has no symbologies or words")
    func emptyHints() {
        #expect(VisionHints.empty.symbologies.isEmpty)
        #expect(VisionHints.empty.customWords.isEmpty)
    }

    @Test("merge of an empty list yields empty hints")
    func mergeEmptyList() {
        let merged = VisionHints.merge([])
        #expect(merged.symbologies.isEmpty)
        #expect(merged.customWords.isEmpty)
    }
}
