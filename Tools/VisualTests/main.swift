import Foundation
import ZPLKit
import ZPLKitRenderer
import ZPLKitVerifier
import CoreGraphics
import ImageIO

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Swift-native visual test harness for ZPLKit
/// Renders all fixtures and generates HTML comparison
///
/// Usage:
///   swift run VisualTests                      # Render all with verification
///   swift run VisualTests --labelary           # Also fetch Labelary renders
///   swift run VisualTests --score              # Score against reference images
///   swift run VisualTests --filter graphic     # Only files matching "graphic"

enum LabelaryError: Error, CustomStringConvertible {
    case httpError(statusCode: Int)
    case rateLimited
    case noData

    var description: String {
        switch self {
        case .httpError(let code): return "HTTP \(code)"
        case .rateLimited: return "Rate limited (429)"
        case .noData: return "No data returned"
        }
    }
}

struct ScoreResult {
    let fixture: String
    let matchPercentage: Double
    let totalPixels: Int
    let differentPixels: Int
    let hasDiff: Bool
}

struct VerificationSummary {
    let detectedBarcodes: Int
    let detectedText: Int
    let expectedBarcodes: Int
    let passedExpectations: Int
    let failedExpectations: [String]
    let detectedBarcodesList: [String]
    let detectedTextList: [String]
    let hasEdgeContent: Bool

    var allPassed: Bool {
        expectedBarcodes == 0 || failedExpectations.isEmpty
    }

    var hasExpectations: Bool {
        expectedBarcodes > 0
    }
}

struct FixtureMetadata: Codable {
    let description: String
    let category: String
    let features: [String]
    let size: String
    let dpi: Int
    let referenceSource: String?
    var expectedBarcodes: [ExpectedBarcode]?
}

struct ExpectedBarcode: Codable {
    let symbology: String
    let payload: String
}

@main
struct VisualTests {
    static let fixturesDir = "Tests/VisualTestHarness/fixtures"
    static let outputDir = "Tests/VisualTestHarness/output-swift"
    static let labelaryDir = "Tests/VisualTestHarness/output-labelary"
    static let referenceDir = "Tests/VisualTestHarness/reference"
    static let diffDir = "Tests/VisualTestHarness/output-diff"
    static let htmlPath = "Tests/VisualTestHarness/comparison.html"
    static let fixturesJsonPath = "Tests/VisualTestHarness/fixtures.json"

    static func main() async throws {
        let args = CommandLine.arguments
        let includeLabelary = args.contains("--labelary")
        let includeScore = args.contains("--score")

        // Parse filter option
        var filterPattern: String? = nil
        if let filterIndex = args.firstIndex(of: "--filter"), filterIndex + 1 < args.count {
            filterPattern = args[filterIndex + 1]
        }

        // Parse minimum accuracy score (used by CI to fail on regressions)
        var minScore: Double? = nil
        if let minScoreIndex = args.firstIndex(of: "--min-score"), minScoreIndex + 1 < args.count {
            minScore = Double(args[minScoreIndex + 1])
        }

        let fileManager = FileManager.default

        // Find package root
        var root = fileManager.currentDirectoryPath
        while !fileManager.fileExists(atPath: "\(root)/Package.swift") {
            let parent = (root as NSString).deletingLastPathComponent
            if parent == root {
                print("Error: Could not find Package.swift")
                exit(1)
            }
            root = parent
        }

        let fixturesPath = "\(root)/\(fixturesDir)"
        let outputPath = "\(root)/\(outputDir)"
        let labelaryPath = "\(root)/\(labelaryDir)"
        let referencePath = "\(root)/\(referenceDir)"
        let diffPath = "\(root)/\(diffDir)"
        let htmlFullPath = "\(root)/\(htmlPath)"
        let fixturesJsonFullPath = "\(root)/\(fixturesJsonPath)"

        // Load fixtures metadata
        var fixturesMetadata: [String: FixtureMetadata] = [:]
        if let jsonData = fileManager.contents(atPath: fixturesJsonFullPath),
           let metadata = try? JSONDecoder().decode([String: FixtureMetadata].self, from: jsonData) {
            fixturesMetadata = metadata
            print("Loaded metadata for \(metadata.count) fixtures")
        } else {
            print("Warning: Could not load fixtures.json, filtering will be limited")
        }

        // Create output directories
        try fileManager.createDirectory(atPath: outputPath, withIntermediateDirectories: true)
        if includeLabelary {
            try fileManager.createDirectory(atPath: labelaryPath, withIntermediateDirectories: true)
        }
        if includeScore {
            try fileManager.createDirectory(atPath: diffPath, withIntermediateDirectories: true)
        }

        // Get fixture files
        guard let files = try? fileManager.contentsOfDirectory(atPath: fixturesPath) else {
            print("Error: Could not read fixtures directory")
            exit(1)
        }

        var zplFiles = files.filter { $0.hasSuffix(".zpl") }.sorted()

        // Apply filter if specified
        if let pattern = filterPattern {
            zplFiles = zplFiles.filter { $0.contains(pattern) }
            print("Found \(zplFiles.count) ZPL fixtures matching '\(pattern)'\n")
        } else {
            print("Found \(zplFiles.count) ZPL fixtures\n")
        }

        // Render with ZPLKitRenderer
        print("=== Rendering with ZPLKitRenderer ===")
        let renderer = ZPLRenderer()
        var results: [(name: String, dpi: DPI, parseMs: Double, renderMs: Double)] = []
        var renderFailures: [String] = []

        for file in zplFiles {
            let zplPath = "\(fixturesPath)/\(file)"
            let pngName = file.replacingOccurrences(of: ".zpl", with: ".png")
            let pngPath = "\(outputPath)/\(pngName)"

            do {
                let zpl = try String(contentsOfFile: zplPath, encoding: .utf8)
                let dpi = parseDPI(from: file)

                let (data, metrics) = try renderer.renderToPNG(zpl)
                try data.write(to: URL(fileURLWithPath: pngPath))

                let parseMs = metrics.parseTimeSeconds * 1000
                let renderMs = metrics.renderTimeSeconds * 1000
                results.append((file, dpi, parseMs, renderMs))

                print("  ✓ \(file) (\(String(format: "%.1f", parseMs + renderMs))ms)")
            } catch {
                print("  ✗ \(file): \(error)")
                renderFailures.append(file)
                // Remove any stale PNG from a previous run so the verify and
                // score phases can't silently use outdated output.
                try? fileManager.removeItem(atPath: pngPath)
            }
        }

        // Verify all rendered images with ZPLVerifier
        var verificationResults: [String: VerificationSummary] = [:]
        print("\n=== Verifying with ZPLVerifier ===")
        let verifier = ZPLVerifier()

        for file in zplFiles {
            let pngName = file.replacingOccurrences(of: ".zpl", with: ".png")
            let pngPath = "\(outputPath)/\(pngName)"
            let name = file.replacingOccurrences(of: ".zpl", with: "")

            guard let image = loadCGImage(from: pngPath) else {
                print("  ⊘ \(file): Could not load rendered image")
                continue
            }

            // Get expected barcodes from metadata
            let expectedBarcodes = fixturesMetadata[name]?.expectedBarcodes ?? []

            do {
                // Discovery mode - find all barcodes and text
                let analysis = try await verifier.analyze(image)

                // Check expectations if we have them
                var passedExpectations = 0
                var failedExpectations: [String] = []

                for expected in expectedBarcodes {
                    let found = analysis.barcodes.contains { barcode in
                        barcode.symbology.rawValue == expected.symbology &&
                        (barcode.payload == expected.payload || barcode.payload.contains(expected.payload))
                    }
                    if found {
                        passedExpectations += 1
                    } else {
                        failedExpectations.append("\(expected.symbology): \(expected.payload)")
                    }
                }

                // Build detected items lists
                let detectedBarcodesList = analysis.barcodes.map { "\($0.symbology.rawValue): \($0.payload)" }
                let detectedTextList = analysis.textRegions.map { $0.text }

                let summary = VerificationSummary(
                    detectedBarcodes: analysis.barcodes.count,
                    detectedText: analysis.textRegions.count,
                    expectedBarcodes: expectedBarcodes.count,
                    passedExpectations: passedExpectations,
                    failedExpectations: failedExpectations,
                    detectedBarcodesList: detectedBarcodesList,
                    detectedTextList: detectedTextList,
                    hasEdgeContent: analysis.boundsInfo.hasEdgeContent
                )
                verificationResults[file] = summary

                if expectedBarcodes.isEmpty {
                    print("  ○ \(file): \(analysis.barcodes.count) barcodes, \(analysis.textRegions.count) text regions")
                } else if failedExpectations.isEmpty {
                    print("  ✓ \(file): \(passedExpectations)/\(expectedBarcodes.count) barcodes verified")
                } else {
                    print("  ✗ \(file): \(passedExpectations)/\(expectedBarcodes.count) passed")
                }
            } catch {
                print("  ✗ \(file): Verification error - \(error.localizedDescription)")
            }
        }

        // Optionally fetch from Labelary
        var labelarySuccesses = 0
        var labelaryFailures: [(file: String, error: String)] = []

        if includeLabelary {
            print("\n=== Fetching from Labelary API ===")
            print("(Rate: ~2.8 req/sec, 3 retries on 429)\n")

            for file in zplFiles {
                let zplPath = "\(fixturesPath)/\(file)"
                let pngName = file.replacingOccurrences(of: ".zpl", with: ".png")
                let pngPath = "\(labelaryPath)/\(pngName)"

                do {
                    let zpl = try String(contentsOfFile: zplPath, encoding: .utf8)
                    let dpi = parseDPI(from: file)
                    let (width, height) = parseDimensions(from: file)

                    let data = try await fetchLabelaryWithRetry(zpl: zpl, dpi: dpi, width: width, height: height)
                    try data.write(to: URL(fileURLWithPath: pngPath))
                    print("  ✓ \(file)")
                    labelarySuccesses += 1
                } catch {
                    let errorMsg = (error as? LabelaryError)?.description ?? error.localizedDescription
                    print("  ✗ \(file): \(errorMsg)")
                    labelaryFailures.append((file, errorMsg))
                }

                // Rate limit: 350ms = ~2.8 req/sec (under Labelary's 3/sec limit)
                try await Task.sleep(nanoseconds: 350_000_000)
            }
        }

        // Score against reference images
        var scores: [ScoreResult] = []
        var referenceSizeFailure = false

        if includeScore {
            print("\n=== Scoring against reference images ===\n")

            // Check if reference directory exists and has images
            guard fileManager.fileExists(atPath: referencePath) else {
                print("Error: Reference directory not found at \(referenceDir)")
                print("Run with --labelary first, then copy output-labelary/ to reference/")
                exit(1)
            }

            var skippedNoReference = 0
            var referenceSizeMismatches: [String] = []
            for file in zplFiles {
                let pngName = file.replacingOccurrences(of: ".zpl", with: ".png")
                let swiftPath = "\(outputPath)/\(pngName)"
                let refPath = "\(referencePath)/\(pngName)"
                let diffImagePath = "\(diffPath)/\(pngName)"

                guard fileManager.fileExists(atPath: refPath) else {
                    print("  ⊘ \(file): No reference image")
                    skippedNoReference += 1
                    continue
                }

                // A reference rendered at the wrong label size makes its score
                // meaningless, and nothing else in this tool notices. Twelve
                // references sat at 812x1218 (the 4x6 parseDimensions fallback)
                // for months because of that silence, and because they were
                // compared against correctly-sized renders, they scored *high*,
                // inflating the overall accuracy number. Verify the geometry.
                if let refSize = pngPixelSize(at: refPath) {
                    let (wIn, hIn) = parseDimensions(from: file)
                    let dpi = Double(parseDPI(from: file).rawValue)
                    let expected = (w: wIn * dpi, h: hIn * dpi)
                    // Generous tolerance: Labelary sizes from dots/mm, so e.g.
                    // 4in @ 300dpi comes back 1216px rather than 1200px.
                    let dw = abs(Double(refSize.width) - expected.w) / expected.w
                    let dh = abs(Double(refSize.height) - expected.h) / expected.h
                    if dw > 0.05 || dh > 0.05 {
                        print("  ✗ \(file): reference is \(refSize.width)x\(refSize.height), expected ~\(Int(expected.w))x\(Int(expected.h)); regenerate it")
                        referenceSizeMismatches.append(file)
                        continue
                    }
                }

                // A fixture that failed to render (or compare) scores 0% so a
                // regression LOWERS the average instead of silently shrinking
                // the denominator and raising it.
                guard fileManager.fileExists(atPath: swiftPath) else {
                    scores.append(ScoreResult(fixture: file, matchPercentage: 0, totalPixels: 0, differentPixels: 0, hasDiff: true))
                    print("  ✗ \(file): No rendered image (scored 0%)")
                    continue
                }

                if let result = compareImages(swiftPath: swiftPath, referencePath: refPath, diffOutputPath: diffImagePath, fixtureName: file) {
                    scores.append(result)
                    let icon = result.matchPercentage >= 99.0 ? "✓" : (result.matchPercentage >= 90.0 ? "○" : "✗")
                    print("  \(icon) \(file): \(String(format: "%.1f", result.matchPercentage))% match (\(result.differentPixels) pixels differ)")
                } else {
                    scores.append(ScoreResult(fixture: file, matchPercentage: 0, totalPixels: 0, differentPixels: 0, hasDiff: true))
                    print("  ✗ \(file): Failed to compare (scored 0%)")
                }
            }
            if skippedNoReference > 0 {
                print("  (\(skippedNoReference) fixture(s) skipped: no reference image)")
            }
            if !referenceSizeMismatches.isEmpty {
                print("\n  ✗ \(referenceSizeMismatches.count) reference(s) rendered at the wrong label size:")
                for file in referenceSizeMismatches { print("      \(file)") }
                print("  Regenerate them: swift run -c release VisualTests --labelary,")
                print("  then copy Tests/VisualTestHarness/output-labelary/<name>.png over reference/.")
                referenceSizeFailure = true
            }
        }

        // Generate HTML
        print("\n=== Generating comparison.html ===")
        let html = generateHTML(
            fixtures: zplFiles,
            results: results,
            includeLabelary: includeLabelary,
            labelaryFailures: Set(labelaryFailures.map { $0.file }),
            includeScore: includeScore,
            scores: scores,
            metadata: fixturesMetadata,
            verification: verificationResults
        )
        try html.write(toFile: htmlFullPath, atomically: true, encoding: .utf8)
        print("Created \(htmlPath)")

        // Summary
        var exitCode: Int32 = 0
        if referenceSizeFailure { exitCode = 1 }
        if !renderFailures.isEmpty {
            print("\n  ✗ \(renderFailures.count) fixture(s) failed to render: \(renderFailures.joined(separator: ", "))")
            exitCode = 1
        }
        let totalParseMs = results.reduce(0) { $0 + $1.parseMs }
        let totalRenderMs = results.reduce(0) { $0 + $1.renderMs }
        print("\nSummary:")
        print("  Fixtures: \(results.count)")
        print("  Total parse time: \(String(format: "%.1f", totalParseMs))ms")
        print("  Total render time: \(String(format: "%.1f", totalRenderMs))ms")
        print("  Average per label: \(String(format: "%.2f", (totalParseMs + totalRenderMs) / Double(results.count)))ms")

        if includeLabelary {
            print("  Labelary: \(labelarySuccesses)/\(zplFiles.count) succeeded")
            if !labelaryFailures.isEmpty {
                print("  ⚠️  \(labelaryFailures.count) Labelary fetches failed (comparison will show Swift renders only)")
                // --score reads the committed reference/ PNGs, so a broken
                // Labelary fetch does NOT move the accuracy number; it just
                // empties the Labelary column of comparison.html and leaves no
                // way to refresh reference/. That silence is exactly how the
                // PR #11 encoding regression survived three weeks of green CI,
                // so fetch health gets its own gate. Tolerate a few transient
                // errors; 429s are already retried in fetchLabelaryWithRetry.
                let failureRate = Double(labelaryFailures.count) / Double(zplFiles.count)
                if failureRate > 0.10 {
                    print("  ✗ \(String(format: "%.0f", failureRate * 100))% of Labelary fetches failed (>10%); comparison is not meaningful")
                    let distinct = Set(labelaryFailures.map(\.error)).sorted()
                    for reason in distinct.prefix(5) {
                        print("      reason: \(reason)")
                    }
                    exitCode = 1
                }
            }
        }

        if includeScore && !scores.isEmpty {
            let avgScore = scores.reduce(0.0) { $0 + $1.matchPercentage } / Double(scores.count)
            let perfectMatches = scores.filter { $0.matchPercentage >= 99.9 }.count
            let goodMatches = scores.filter { $0.matchPercentage >= 95.0 }.count

            print("\n  ═══════════════════════════════════")
            print("  ACCURACY SCORE: \(String(format: "%.1f", avgScore))%")
            print("  ═══════════════════════════════════")
            if let minScore, avgScore < minScore {
                print("  ✗ Accuracy below --min-score \(String(format: "%.1f", minScore))%")
                exitCode = 1
            }
            print("  Perfect (≥99.9%): \(perfectMatches)/\(scores.count)")
            print("  Good (≥95%): \(goodMatches)/\(scores.count)")

            // Show worst performers
            let worstScores = scores.sorted { $0.matchPercentage < $1.matchPercentage }.prefix(5)
            if let worst = worstScores.first, worst.matchPercentage < 95.0 {
                print("\n  Needs improvement:")
                for score in worstScores where score.matchPercentage < 95.0 {
                    print("    • \(score.fixture): \(String(format: "%.1f", score.matchPercentage))%")
                }
            }
        }

        if !verificationResults.isEmpty {
            let withExpectations = verificationResults.filter { $0.value.hasExpectations }
            let allPassed = withExpectations.filter { $0.value.allPassed }
            let totalExpected = withExpectations.values.reduce(0) { $0 + $1.expectedBarcodes }
            let totalPassed = withExpectations.values.reduce(0) { $0 + $1.passedExpectations }
            let totalDetected = verificationResults.values.reduce(0) { $0 + $1.detectedBarcodes }
            let totalTextRegions = verificationResults.values.reduce(0) { $0 + $1.detectedText }

            print("\n  ═══════════════════════════════════")
            print("  VERIFICATION SUMMARY")
            print("  ═══════════════════════════════════")
            print("  Barcodes detected: \(totalDetected)")
            print("  Text regions detected: \(totalTextRegions)")
            print("  Fixtures with expectations: \(withExpectations.count)")
            if !withExpectations.isEmpty {
                let passRate = Double(totalPassed) / Double(totalExpected) * 100
                print("  Expectations passed: \(totalPassed)/\(totalExpected) (\(String(format: "%.0f", passRate))%)")
                print("  Fixtures fully verified: \(allPassed.count)/\(withExpectations.count)")
            }

            // Show failures
            let failures = withExpectations.filter { !$0.value.allPassed }
            if !failures.isEmpty {
                print("\n  Failed verifications:")
                for (file, summary) in failures.sorted(by: { $0.key < $1.key }).prefix(10) {
                    print("    • \(file): missing \(summary.failedExpectations.joined(separator: ", "))")
                }
                if failures.count > 10 {
                    print("    ... and \(failures.count - 10) more")
                }
            }
        }

        // Exit nonzero on render failures or a below-threshold score so CI can
        // actually fail; this tool previously always exited 0.
        if exitCode != 0 {
            exit(exitCode)
        }
    }

    /// Reads a PNG's pixel dimensions straight from its IHDR chunk.
    ///
    /// Deliberately avoids decoding the image: this runs for every fixture on
    /// every scored run, and only the geometry is needed.
    static func pngPixelSize(at path: String) -> (width: Int, height: Int)? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        // 8-byte signature + 4 length + 4 "IHDR" + 4 width + 4 height
        guard let header = try? handle.read(upToCount: 24), header.count == 24 else { return nil }
        guard header.starts(with: [0x89, 0x50, 0x4E, 0x47]) else { return nil }
        func beInt(_ range: Range<Int>) -> Int {
            header[range].reduce(0) { ($0 << 8) | Int($1) }
        }
        return (beInt(16..<20), beInt(20..<24))
    }

    static func parseDPI(from filename: String) -> DPI {
        if filename.contains("_600") { return .dpi600 }
        if filename.contains("_300") { return .dpi300 }
        if filename.contains("_152") { return .dpi152 }
        return .dpi203
    }

    static func parseDimensions(from filename: String) -> (width: Double, height: Double) {
        // Parse dimensions from a filename like "shipping_4x6_203.zpl" or
        // "simple_mini_1x0.5_203.zpl".
        //
        // The fractional part is REQUIRED in this pattern. It used to be
        // `(\d+)x(\d+)`, which cannot match a decimal: "1x0.5" matched the
        // "1x0" prefix and yielded a zero-height label, so Labelary rejected
        // the request with HTTP 400. That silently cost the 13 fixtures with
        // 0.5/0.75-inch heights their reference renders (verified 2026-08-14).
        // The surrounding underscores anchor the match to the dimension field
        // so the trailing DPI segment can't be mistaken for it.
        let pattern = #"_(\d+(?:\.\d+)?)x(\d+(?:\.\d+)?)_"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) {
            if let widthRange = Range(match.range(at: 1), in: filename),
               let heightRange = Range(match.range(at: 2), in: filename),
               let width = Double(filename[widthRange]),
               let height = Double(filename[heightRange]) {
                return (width, height)
            }
        }
        // Falling back here means the Labelary render is requested at the wrong
        // size, so the reference silently disagrees with the fixture. Say so
        // instead of quietly returning 4x6.
        print("    ⚠️  Could not parse dimensions from '\(filename)'; defaulting to 4x6")
        return (4, 6)
    }

    static func fetchLabelaryWithRetry(zpl: String, dpi: DPI, width: Double, height: Double, maxRetries: Int = 3) async throws -> Data {
        var lastError: Error = LabelaryError.noData

        for attempt in 0..<maxRetries {
            do {
                return try await fetchLabelary(zpl: zpl, dpi: dpi, width: width, height: height)
            } catch LabelaryError.rateLimited {
                lastError = LabelaryError.rateLimited
                if attempt < maxRetries - 1 {
                    let backoffSeconds = Double(attempt + 1) // 1s, 2s
                    print("    ↻ Rate limited, retrying in \(Int(backoffSeconds))s...")
                    try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
                }
            } catch {
                throw error
            }
        }

        throw lastError
    }

    static func fetchLabelary(zpl: String, dpi: DPI, width: Double, height: Double) async throws -> Data {
        // Labelary uses dots per mm (dpmm) not DPI
        let dpmm: String
        switch dpi {
        case .dpi152: dpmm = "6dpmm"
        case .dpi200: dpmm = "8dpmm"
        case .dpi203: dpmm = "8dpmm"
        case .dpi300: dpmm = "12dpmm"
        case .dpi600: dpmm = "24dpmm"
        }

        let urlString = "https://api.labelary.com/v1/printers/\(dpmm)/labels/\(width)x\(height)/0/"
        guard let url = URL(string: urlString) else { throw LabelaryError.noData }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("image/png", forHTTPHeaderField: "Accept")
        // Send the ZPL as RAW bytes. Despite the form-urlencoded content type
        // (which Labelary requires, since text/plain is rejected with a 415), the
        // API does not form-decode the body: it reads it verbatim as the ZPL
        // program.
        //
        // The trap (recorded so it isn't repeated): on 2026-07-24 PR #11
        // percent-encoded this body, on the theory that a raw "+" would decode
        // to a space and "%XX"/"&" would be mangled. That premise is wrong, and
        // the change broke EVERY fetch. Labelary answered "404 ERROR:
        // Requested 1st label but ZPL generated no labels" for all 124
        // fixtures, because a fully percent-encoded body contains no "=" and
        // parses as one empty form field. CI stayed green because --score
        // reads the committed reference/ PNGs, not these fetches, so the only
        // visible symptom was a comparison.html with an empty Labelary column.
        // Verified 2026-08-14: posting raw bytes round-trips "+", "%25", and
        // "&" to visibly distinct renders, so no encoding is needed.
        request.httpBody = Data(zpl.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LabelaryError.noData
        }

        switch httpResponse.statusCode {
        case 200:
            if data.isEmpty { throw LabelaryError.noData }
            return data
        case 429:
            throw LabelaryError.rateLimited
        default:
            throw LabelaryError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    // MARK: - Image Comparison

    static func compareImages(swiftPath: String, referencePath: String, diffOutputPath: String, fixtureName: String) -> ScoreResult? {
        guard let swiftImage = loadCGImage(from: swiftPath),
              let refImage = loadCGImage(from: referencePath) else {
            return nil
        }

        let swiftWidth = swiftImage.width
        let swiftHeight = swiftImage.height
        let refWidth = refImage.width
        let refHeight = refImage.height

        // Use the larger dimensions to handle size mismatches
        let width = max(swiftWidth, refWidth)
        let height = max(swiftHeight, refHeight)
        let totalPixels = width * height

        // Get pixel data
        guard let swiftPixels = getPixelData(from: swiftImage, targetWidth: width, targetHeight: height),
              let refPixels = getPixelData(from: refImage, targetWidth: width, targetHeight: height) else {
            return nil
        }

        // Compare pixels and build diff image
        var differentPixels = 0
        var diffPixels = [UInt8](repeating: 255, count: width * height * 4) // RGBA

        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * width + x) * 4

                let swiftR = swiftPixels[idx]
                let swiftG = swiftPixels[idx + 1]
                let swiftB = swiftPixels[idx + 2]

                let refR = refPixels[idx]
                let refG = refPixels[idx + 1]
                let refB = refPixels[idx + 2]

                // Check if pixels match (with small tolerance for antialiasing)
                let tolerance: UInt8 = 2
                let rDiff = abs(Int(swiftR) - Int(refR))
                let gDiff = abs(Int(swiftG) - Int(refG))
                let bDiff = abs(Int(swiftB) - Int(refB))

                if rDiff > Int(tolerance) || gDiff > Int(tolerance) || bDiff > Int(tolerance) {
                    differentPixels += 1
                    // Red for different pixels
                    diffPixels[idx] = 255     // R
                    diffPixels[idx + 1] = 0   // G
                    diffPixels[idx + 2] = 0   // B
                    diffPixels[idx + 3] = 255 // A
                } else {
                    // Grayscale version of original for matching pixels
                    let gray = UInt8((Int(swiftR) + Int(swiftG) + Int(swiftB)) / 3)
                    diffPixels[idx] = gray
                    diffPixels[idx + 1] = gray
                    diffPixels[idx + 2] = gray
                    diffPixels[idx + 3] = 255
                }
            }
        }

        // Save diff image
        saveDiffImage(pixels: diffPixels, width: width, height: height, to: diffOutputPath)

        let matchPercentage = Double(totalPixels - differentPixels) / Double(totalPixels) * 100.0

        return ScoreResult(
            fixture: fixtureName,
            matchPercentage: matchPercentage,
            totalPixels: totalPixels,
            differentPixels: differentPixels,
            hasDiff: differentPixels > 0
        )
    }

    static func loadCGImage(from path: String) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        return image
    }

    static func getPixelData(from image: CGImage, targetWidth: Int, targetHeight: Int) -> [UInt8]? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixels = [UInt8](repeating: 255, count: targetWidth * targetHeight * 4)

        // Keep every draw inside withUnsafeMutableBytes: `&pixels` is only
        // valid for the duration of the CGContext initializer call, so writing
        // through the stored pointer afterwards is undefined behavior.
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: targetWidth,
                    height: targetHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: targetWidth * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return false
            }

            // Fill with white background
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

            // Anchor at the TOP-left: labels share a top-left origin, so a
            // height mismatch must not vertically offset the whole comparison
            // (CoreGraphics rects are bottom-left anchored).
            context.draw(image, in: CGRect(x: 0, y: targetHeight - image.height,
                                           width: image.width, height: image.height))
            return true
        }

        return drawn ? pixels : nil
    }

    static func saveDiffImage(pixels: [UInt8], width: Int, height: Int, to path: String) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var mutablePixels = pixels

        // See getPixelData: the buffer pointer must stay valid for the whole
        // context lifetime, so create AND consume the context inside the closure.
        let made = mutablePixels.withUnsafeMutableBytes { raw -> CGImage? in
            guard let base = raw.baseAddress,
                  let context = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else {
                return nil
            }
            return context.makeImage()
        }
        guard let cgImage = made else {
            return
        }

        let url = URL(fileURLWithPath: path) as CFURL

        #if canImport(UniformTypeIdentifiers)
        let imageType = UTType.png.identifier as CFString
        #else
        let imageType = "public.png" as CFString
        #endif

        guard let destination = CGImageDestinationCreateWithURL(url, imageType, 1, nil) else {
            return
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)
    }

    // MARK: - Expectation Extraction

    static func extractExpectationsFromZPL(
        fixturesPath: String,
        metadata: [String: FixtureMetadata],
        fileManager: FileManager
    ) throws -> [String: FixtureMetadata] {
        var updatedMetadata = metadata

        guard let files = try? fileManager.contentsOfDirectory(atPath: fixturesPath) else {
            return metadata
        }

        let zplFiles = files.filter { $0.hasSuffix(".zpl") }.sorted()

        for file in zplFiles {
            let zplPath = "\(fixturesPath)/\(file)"
            let name = file.replacingOccurrences(of: ".zpl", with: "")

            guard let zpl = try? String(contentsOfFile: zplPath, encoding: .utf8) else {
                continue
            }

            do {
                let parsed = try ZPLParser.parse(zpl)
                var expectedBarcodes: [ExpectedBarcode] = []

                for element in parsed.elements {
                    if case .barcode(let barcode) = element {
                        let symbology = mapBarcodeTypeToSymbology(barcode.type)
                        let payload = cleanBarcodePayload(barcode.data, type: barcode.type)

                        // Skip empty payloads
                        guard !payload.isEmpty else { continue }

                        expectedBarcodes.append(ExpectedBarcode(
                            symbology: symbology,
                            payload: payload
                        ))
                    }
                }

                // Update metadata
                if var meta = updatedMetadata[name] {
                    meta.expectedBarcodes = expectedBarcodes.isEmpty ? nil : expectedBarcodes
                    updatedMetadata[name] = meta
                    if !expectedBarcodes.isEmpty {
                        print("  \(file): \(expectedBarcodes.count) barcodes")
                    }
                }
            } catch {
                print("  ⊘ \(file): Parse error - \(error.localizedDescription)")
            }
        }

        return updatedMetadata
    }

    static func mapBarcodeTypeToSymbology(_ type: ParsedBarcode.BarcodeType) -> String {
        switch type {
        case .code128: return "code128"
        case .code39: return "code39"
        case .qrCode: return "qr"
        case .dataMatrix: return "dataMatrix"
        case .pdf417: return "pdf417"
        case .interleaved2of5: return "i2of5"
        case .ean13: return "ean13"
        case .ean8: return "ean8"
        case .upcA: return "ean13"  // UPC-A often decoded as EAN-13
        case .upcE: return "upce"
        case .aztec: return "aztec"
        case .intelligentMail: return "intelligentMail"
        }
    }

    static func cleanBarcodePayload(_ data: String, type: ParsedBarcode.BarcodeType) -> String {
        var payload = data

        // QR codes have mode prefix like "MA," or "HA,"
        if type == .qrCode {
            if payload.count > 3 && payload.dropFirst(2).first == "," {
                payload = String(payload.dropFirst(3))
            }
        }

        return payload
    }

    // MARK: - HTML Generation

    static func generateHTML(fixtures: [String], results: [(name: String, dpi: DPI, parseMs: Double, renderMs: Double)], includeLabelary: Bool, labelaryFailures: Set<String> = [], includeScore: Bool = false, scores: [ScoreResult] = [], metadata: [String: FixtureMetadata] = [:], verification: [String: VerificationSummary] = [:]) -> String {
        let resultsDict = Dictionary(uniqueKeysWithValues: results.map { ($0.name, $0) })
        let scoresDict = Dictionary(uniqueKeysWithValues: scores.map { ($0.fixture, $0) })

        // Collect unique values for filters
        var categories = Set<String>()
        var sizes = Set<String>()
        var dpis = Set<Int>()
        var allFeatures = Set<String>()

        for file in fixtures {
            let name = file.replacingOccurrences(of: ".zpl", with: "")
            if let meta = metadata[name] {
                categories.insert(meta.category)
                sizes.insert(meta.size)
                dpis.insert(meta.dpi)
                allFeatures.formUnion(meta.features)
            }
        }

        var rows = ""
        for file in fixtures {
            let name = file.replacingOccurrences(of: ".zpl", with: "")
            let pngName = file.replacingOccurrences(of: ".zpl", with: ".png")
            let result = resultsDict[file]
            let score = scoresDict[file]
            let meta = metadata[name]
            let verify = verification[file]
            let timeStr = result.map { String(format: "%.1fms", $0.parseMs + $0.renderMs) } ?? "—"
            let labelaryFailed = labelaryFailures.contains(file)

            // Data attributes for filtering
            let category = meta?.category ?? "unknown"
            let size = meta?.size ?? "unknown"
            let dpi = meta?.dpi ?? 203
            let features = (meta?.features ?? []).joined(separator: " ")
            let description = meta?.description ?? ""

            let scoreHtml: String
            if let s = score {
                let scoreClass = s.matchPercentage >= 99.0 ? "score-good" : (s.matchPercentage >= 90.0 ? "score-ok" : "score-bad")
                scoreHtml = "<span class=\"score \(scoreClass)\">\(String(format: "%.1f", s.matchPercentage))%</span>"
            } else {
                scoreHtml = ""
            }

            // Verification badge
            let verifyBadge: String
            if let v = verify {
                if v.hasExpectations {
                    if v.allPassed {
                        verifyBadge = "<span class=\"verify-badge verify-pass\">✓ \(v.passedExpectations)/\(v.expectedBarcodes)</span>"
                    } else {
                        verifyBadge = "<span class=\"verify-badge verify-fail\">✗ \(v.passedExpectations)/\(v.expectedBarcodes)</span>"
                    }
                } else {
                    verifyBadge = "<span class=\"verify-badge verify-none\">\(v.detectedBarcodes)bc/\(v.detectedText)txt</span>"
                }
            } else {
                verifyBadge = ""
            }

            // Category badge
            let categoryBadge = "<span class=\"category-badge cat-\(category)\">\(category)</span>"

            // Verification panel HTML
            let verificationPanelHtml: String
            if let v = verify {
                var panelContent = ""

                // Status line
                if v.hasExpectations {
                    if v.allPassed {
                        panelContent += "<div class=\"verify-status verify-pass\">✓ All \(v.expectedBarcodes) expected barcode(s) verified</div>"
                    } else {
                        panelContent += "<div class=\"verify-status verify-fail\">✗ \(v.passedExpectations)/\(v.expectedBarcodes) expected barcodes found</div>"
                        panelContent += "<div class=\"verify-missing\"><strong>Missing:</strong> \(v.failedExpectations.joined(separator: ", "))</div>"
                    }
                }

                // Detected barcodes
                if !v.detectedBarcodesList.isEmpty {
                    panelContent += "<div class=\"verify-detected\"><strong>Detected barcodes:</strong> \(v.detectedBarcodesList.joined(separator: ", "))</div>"
                }

                // Detected text (collapsible if long)
                if !v.detectedTextList.isEmpty {
                    let textPreview = v.detectedTextList.prefix(5).joined(separator: " | ")
                    let moreText = v.detectedTextList.count > 5 ? " ... +\(v.detectedTextList.count - 5) more" : ""
                    panelContent += "<div class=\"verify-detected\"><strong>Detected text:</strong> \(textPreview)\(moreText)</div>"
                }

                if v.hasEdgeContent {
                    panelContent += "<div class=\"verify-warning\">⚠ Content near edge (may be clipped)</div>"
                }

                verificationPanelHtml = "<div class=\"verification-panel\">\(panelContent)</div>"
            } else {
                verificationPanelHtml = ""
            }

            rows += """
            <div class="fixture" data-category="\(category)" data-size="\(size)" data-dpi="\(dpi)" data-features="\(features)">
                <div class="fixture-header">
                    <div class="fixture-title">
                        <span class="fixture-name">\(file)</span>
                        \(categoryBadge)
                    </div>
                    <span class="fixture-meta">\(verifyBadge) \(scoreHtml) \(timeStr)</span>
                </div>
                <div class="fixture-description">\(description)</div>
                \(verificationPanelHtml)
                <div class="renders">
                    <div class="render">
                        <div class="render-label">ZPLKitRenderer</div>
                        <img src="output-swift/\(pngName)" alt="\(file)" loading="lazy">
                    </div>
            """

            if includeLabelary {
                if labelaryFailed {
                    rows += """
                    <div class="render">
                        <div class="render-label">Labelary</div>
                        <div class="render-error">Failed to fetch from Labelary</div>
                    </div>
            """
                } else {
                    rows += """
                    <div class="render">
                        <div class="render-label">Labelary</div>
                        <img src="output-labelary/\(pngName)" alt="\(file)" loading="lazy">
                    </div>
            """
                }
            }

            if includeScore {
                rows += """
                    <div class="render">
                        <div class="render-label">Reference</div>
                        <img src="reference/\(pngName)" alt="\(file) reference" loading="lazy">
                    </div>
                    <div class="render">
                        <div class="render-label">Diff</div>
                        <img src="output-diff/\(pngName)" alt="\(file) diff" loading="lazy">
                    </div>
            """
            }

            rows += """
                </div>
            </div>
            """
        }

        // Generate category chips
        let categoryChips = categories.sorted().map { cat in
            "<button class=\"chip\" data-filter=\"category\" data-value=\"\(cat)\">\(cat)</button>"
        }.joined(separator: "\n                    ")

        // Generate size options
        let sizeOptions = ["<option value=\"\">All sizes</option>"] + sizes.sorted().map { size in
            "<option value=\"\(size)\">\(size)</option>"
        }

        // Generate DPI options
        let dpiOptions = ["<option value=\"\">All DPIs</option>"] + dpis.sorted().map { dpi in
            "<option value=\"\(dpi)\">\(dpi) DPI</option>"
        }

        let totalTime = results.reduce(0) { $0 + $1.parseMs + $1.renderMs }
        let avgTime = results.isEmpty ? 0 : totalTime / Double(results.count)

        let overallScoreHtml: String
        if !scores.isEmpty {
            let avgScore = scores.reduce(0.0) { $0 + $1.matchPercentage } / Double(scores.count)
            let scoreClass = avgScore >= 99.0 ? "score-good" : (avgScore >= 90.0 ? "score-ok" : "score-bad")
            overallScoreHtml = "<span class=\"overall-score \(scoreClass)\"><strong>\(String(format: "%.1f", avgScore))%</strong> accuracy</span>"
        } else {
            overallScoreHtml = ""
        }

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>ZPLKit Visual Tests</title>
            <style>
                * { box-sizing: border-box; }
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    margin: 0;
                    padding: 20px;
                    background: #888;
                }
                h1 { margin: 0 0 10px 0; color: white; }
                a { color: #adf; }
                .summary {
                    background: #ccc;
                    padding: 15px;
                    border-radius: 8px;
                    margin-bottom: 15px;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    flex-wrap: wrap;
                    gap: 10px;
                }
                .summary-stats { color: #333; }
                .summary-stats span { margin-right: 30px; }
                .overall-score {
                    font-size: 18px;
                    padding: 8px 16px;
                    border-radius: 4px;
                }
                .filter-section {
                    background: #ccc;
                    padding: 15px;
                    border-radius: 8px;
                    margin-bottom: 15px;
                }
                .filter-row {
                    display: flex;
                    flex-wrap: wrap;
                    gap: 10px;
                    align-items: center;
                    margin-bottom: 10px;
                }
                .filter-row:last-child { margin-bottom: 0; }
                .filter-label {
                    font-size: 12px;
                    font-weight: 600;
                    color: #666;
                    min-width: 70px;
                }
                .filter-bar input[type="text"] {
                    padding: 8px 12px;
                    font-size: 14px;
                    border: 1px solid #ddd;
                    border-radius: 4px;
                    width: 250px;
                }
                .filter-bar select {
                    padding: 8px 12px;
                    font-size: 14px;
                    border: 1px solid #ddd;
                    border-radius: 4px;
                    background: white;
                }
                .chips {
                    display: flex;
                    flex-wrap: wrap;
                    gap: 6px;
                }
                .chip {
                    padding: 5px 12px;
                    font-size: 13px;
                    border: 1px solid #ddd;
                    border-radius: 16px;
                    background: white;
                    cursor: pointer;
                    transition: all 0.15s;
                }
                .chip:hover { background: #f0f0f0; }
                .chip.active {
                    background: #333;
                    color: white;
                    border-color: #333;
                }
                .chip-clear {
                    background: #f8f8f8;
                    color: #999;
                    border-style: dashed;
                }
                .chip-clear:hover { background: #eee; }
                .visible-count {
                    font-size: 13px;
                    color: #666;
                    margin-left: auto;
                }
                .fixture {
                    background: #ddd;
                    border-radius: 8px;
                    margin-bottom: 15px;
                    overflow: hidden;
                    box-shadow: 0 2px 6px rgba(0,0,0,0.2);
                }
                .fixture.hidden { display: none; }
                .fixture-header {
                    background: #333;
                    color: white;
                    padding: 10px 15px;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    flex-wrap: wrap;
                    gap: 8px;
                }
                .fixture-title {
                    display: flex;
                    align-items: center;
                    gap: 10px;
                }
                .fixture-name { font-family: monospace; font-size: 14px; }
                .fixture-meta { font-size: 12px; color: #aaa; display: flex; align-items: center; gap: 10px; }
                .fixture-description {
                    padding: 10px 15px;
                    font-size: 13px;
                    color: #444;
                    background: #ccc;
                }
                .category-badge {
                    font-size: 11px;
                    padding: 2px 8px;
                    border-radius: 10px;
                    text-transform: uppercase;
                    font-weight: 600;
                }
                .cat-barcode { background: #e3f2fd; color: #1565c0; }
                .cat-shipping { background: #fff3e0; color: #e65100; }
                .cat-retail { background: #f3e5f5; color: #7b1fa2; }
                .cat-warehouse { background: #e8f5e9; color: #2e7d32; }
                .cat-inventory { background: #e0f7fa; color: #00838f; }
                .cat-food { background: #fce4ec; color: #c2185b; }
                .cat-graphic { background: #ede7f6; color: #512da8; }
                .cat-shapes { background: #fff8e1; color: #ff8f00; }
                .cat-features { background: #e8eaf6; color: #3949ab; }
                .cat-asset { background: #efebe9; color: #5d4037; }
                .cat-shop { background: #eceff1; color: #455a64; }
                .cat-simple { background: #f5f5f5; color: #616161; }
                .cat-medical { background: #ffebee; color: #c62828; }
                .cat-unknown { background: #eee; color: #666; }
                .score {
                    padding: 2px 8px;
                    border-radius: 3px;
                    font-weight: 600;
                }
                .score-good { background: #28a745; color: white; }
                .score-ok { background: #ffc107; color: #333; }
                .score-bad { background: #dc3545; color: white; }
                .verify-badge {
                    padding: 2px 8px;
                    border-radius: 3px;
                    font-weight: 600;
                    font-size: 11px;
                }
                .verify-pass { background: #28a745; color: white; }
                .verify-fail { background: #dc3545; color: white; }
                .verify-none { background: #6c757d; color: white; }
                .verification-panel {
                    padding: 10px 15px;
                    background: #e9ecef;
                    border-top: 1px solid #ccc;
                    font-size: 12px;
                }
                .verify-status {
                    font-weight: 600;
                    margin-bottom: 5px;
                }
                .verify-status.verify-pass { color: #28a745; }
                .verify-status.verify-fail { color: #dc3545; }
                .verify-missing {
                    color: #dc3545;
                    margin-bottom: 5px;
                }
                .verify-detected {
                    color: #495057;
                    margin-bottom: 3px;
                    word-break: break-word;
                }
                .verify-warning {
                    color: #856404;
                    background: #fff3cd;
                    padding: 3px 8px;
                    border-radius: 3px;
                    display: inline-block;
                    margin-top: 5px;
                }
                .renders {
                    display: flex;
                    gap: 20px;
                    padding: 15px;
                    flex-wrap: wrap;
                    background: #ddd;
                }
                .render {
                    flex: 1;
                    min-width: 200px;
                }
                .render-label {
                    font-size: 12px;
                    color: #666;
                    margin-bottom: 5px;
                    font-weight: 600;
                }
                .render img {
                    max-width: 100%;
                    border: 1px solid #ddd;
                    background: white;
                }
                .render-error {
                    padding: 20px;
                    background: #fff3cd;
                    border: 1px solid #ffc107;
                    border-radius: 4px;
                    color: #856404;
                    font-size: 14px;
                }
            </style>
        </head>
        <body>
            <h1>ZPLKit Visual Tests <a href="https://github.com/jonathanspiva/ZPLKit" style="font-size: 14px; font-weight: normal;">github.com/jonathanspiva/ZPLKit</a></h1>
            <div class="summary">
                <div class="summary-stats">
                    <span><strong>\(fixtures.count)</strong> fixtures</span>
                    <span><strong>\(String(format: "%.1f", totalTime))ms</strong> total render time</span>
                    <span><strong>\(String(format: "%.2f", avgTime))ms</strong> average</span>
                </div>
                \(overallScoreHtml)
            </div>
            <div class="filter-section">
                <div class="filter-row filter-bar">
                    <span class="filter-label">Search:</span>
                    <input type="text" id="textFilter" placeholder="Filter by name or description..." oninput="applyFilters()">
                    <select id="sizeFilter" onchange="applyFilters()">
                        \(sizeOptions.joined(separator: "\n                        "))
                    </select>
                    <select id="dpiFilter" onchange="applyFilters()">
                        \(dpiOptions.joined(separator: "\n                        "))
                    </select>
                    <span class="visible-count" id="visibleCount"></span>
                </div>
                <div class="filter-row">
                    <span class="filter-label">Category:</span>
                    <div class="chips">
                        <button class="chip chip-clear" onclick="clearCategory()">All</button>
                        \(categoryChips)
                    </div>
                </div>
            </div>
            <div id="fixtures">
                \(rows)
            </div>
            <script>
                let activeCategory = null;

                function applyFilters() {
                    const textFilter = document.getElementById('textFilter').value.toLowerCase();
                    const sizeFilter = document.getElementById('sizeFilter').value;
                    const dpiFilter = document.getElementById('dpiFilter').value;

                    let visible = 0;
                    document.querySelectorAll('.fixture').forEach(f => {
                        const name = f.querySelector('.fixture-name').textContent.toLowerCase();
                        const desc = f.querySelector('.fixture-description')?.textContent.toLowerCase() || '';
                        const category = f.dataset.category;
                        const size = f.dataset.size;
                        const dpi = f.dataset.dpi;

                        const matchesText = !textFilter || name.includes(textFilter) || desc.includes(textFilter);
                        const matchesCategory = !activeCategory || category === activeCategory;
                        const matchesSize = !sizeFilter || size === sizeFilter;
                        const matchesDpi = !dpiFilter || dpi === dpiFilter;

                        if (matchesText && matchesCategory && matchesSize && matchesDpi) {
                            f.classList.remove('hidden');
                            visible++;
                        } else {
                            f.classList.add('hidden');
                        }
                    });

                    document.getElementById('visibleCount').textContent = visible + ' shown';
                }

                function clearCategory() {
                    activeCategory = null;
                    document.querySelectorAll('.chip[data-filter="category"]').forEach(c => c.classList.remove('active'));
                    applyFilters();
                }

                document.querySelectorAll('.chip[data-filter="category"]').forEach(chip => {
                    chip.addEventListener('click', () => {
                        const value = chip.dataset.value;
                        if (activeCategory === value) {
                            clearCategory();
                        } else {
                            activeCategory = value;
                            document.querySelectorAll('.chip[data-filter="category"]').forEach(c => c.classList.remove('active'));
                            chip.classList.add('active');
                            applyFilters();
                        }
                    });
                });

                // Initialize count
                applyFilters();
            </script>
        </body>
        </html>
        """
    }
}
