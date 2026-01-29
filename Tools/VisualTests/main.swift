import Foundation
import ZPLKit
import ZPLKitRenderer
import CoreGraphics
import ImageIO

#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Swift-native visual test harness for ZPLKit
/// Renders all fixtures and generates HTML comparison
///
/// Usage:
///   swift run VisualTests                      # Render all (fast, local)
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

struct FixtureMetadata: Codable {
    let description: String
    let category: String
    let features: [String]
    let size: String
    let dpi: Int
    let referenceSource: String?
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

        for file in zplFiles {
            let zplPath = "\(fixturesPath)/\(file)"
            let pngName = file.replacingOccurrences(of: ".zpl", with: ".png")
            let pngPath = "\(outputPath)/\(pngName)"

            do {
                let zpl = try String(contentsOfFile: zplPath, encoding: .utf8)
                let dpi = parseDPI(from: file)

                let (data, metrics) = try renderer.renderToPNG(zpl, dpi: dpi)
                try data.write(to: URL(fileURLWithPath: pngPath))

                let parseMs = metrics.parseTimeSeconds * 1000
                let renderMs = metrics.renderTimeSeconds * 1000
                results.append((file, dpi, parseMs, renderMs))

                print("  ✓ \(file) (\(String(format: "%.1f", parseMs + renderMs))ms)")
            } catch {
                print("  ✗ \(file): \(error)")
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

        if includeScore {
            print("\n=== Scoring against reference images ===\n")

            // Check if reference directory exists and has images
            guard fileManager.fileExists(atPath: referencePath) else {
                print("Error: Reference directory not found at \(referenceDir)")
                print("Run with --labelary first, then copy output-labelary/ to reference/")
                exit(1)
            }

            for file in zplFiles {
                let pngName = file.replacingOccurrences(of: ".zpl", with: ".png")
                let swiftPath = "\(outputPath)/\(pngName)"
                let refPath = "\(referencePath)/\(pngName)"
                let diffImagePath = "\(diffPath)/\(pngName)"

                guard fileManager.fileExists(atPath: refPath) else {
                    print("  ⊘ \(file): No reference image")
                    continue
                }

                guard fileManager.fileExists(atPath: swiftPath) else {
                    print("  ⊘ \(file): No rendered image")
                    continue
                }

                if let result = compareImages(swiftPath: swiftPath, referencePath: refPath, diffOutputPath: diffImagePath, fixtureName: file) {
                    scores.append(result)
                    let icon = result.matchPercentage >= 99.0 ? "✓" : (result.matchPercentage >= 90.0 ? "○" : "✗")
                    print("  \(icon) \(file): \(String(format: "%.1f", result.matchPercentage))% match (\(result.differentPixels) pixels differ)")
                } else {
                    print("  ✗ \(file): Failed to compare")
                }
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
            metadata: fixturesMetadata
        )
        try html.write(toFile: htmlFullPath, atomically: true, encoding: .utf8)
        print("Created \(htmlPath)")

        // Summary
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
            }
        }

        if includeScore && !scores.isEmpty {
            let avgScore = scores.reduce(0.0) { $0 + $1.matchPercentage } / Double(scores.count)
            let perfectMatches = scores.filter { $0.matchPercentage >= 99.9 }.count
            let goodMatches = scores.filter { $0.matchPercentage >= 95.0 }.count

            print("\n  ═══════════════════════════════════")
            print("  ACCURACY SCORE: \(String(format: "%.1f", avgScore))%")
            print("  ═══════════════════════════════════")
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
    }

    static func parseDPI(from filename: String) -> DPI {
        if filename.contains("_600") { return .dpi600 }
        if filename.contains("_300") { return .dpi300 }
        if filename.contains("_152") { return .dpi152 }
        return .dpi203
    }

    static func parseDimensions(from filename: String) -> (width: Double, height: Double) {
        // Parse dimensions from filename like "shipping_4x6_203.zpl"
        let pattern = #"(\d+)x(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: filename, range: NSRange(filename.startIndex..., in: filename)) {
            if let widthRange = Range(match.range(at: 1), in: filename),
               let heightRange = Range(match.range(at: 2), in: filename),
               let width = Double(filename[widthRange]),
               let height = Double(filename[heightRange]) {
                return (width, height)
            }
        }
        return (4, 6) // Default
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
        case .dpi203: dpmm = "8dpmm"
        case .dpi300: dpmm = "12dpmm"
        case .dpi600: dpmm = "24dpmm"
        }

        let urlString = "http://api.labelary.com/v1/printers/\(dpmm)/labels/\(width)x\(height)/0/"
        guard let url = URL(string: urlString) else { throw LabelaryError.noData }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("image/png", forHTTPHeaderField: "Accept")
        request.httpBody = zpl.data(using: .utf8)

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

        guard let context = CGContext(
            data: &pixels,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Fill with white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Draw image (will be scaled if sizes don't match)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        return pixels
    }

    static func saveDiffImage(pixels: [UInt8], width: Int, height: Int, to path: String) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var mutablePixels = pixels

        guard let context = CGContext(
            data: &mutablePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage() else {
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

    // MARK: - HTML Generation

    static func generateHTML(fixtures: [String], results: [(name: String, dpi: DPI, parseMs: Double, renderMs: Double)], includeLabelary: Bool, labelaryFailures: Set<String> = [], includeScore: Bool = false, scores: [ScoreResult] = [], metadata: [String: FixtureMetadata] = [:]) -> String {
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

            // Category badge
            let categoryBadge = "<span class=\"category-badge cat-\(category)\">\(category)</span>"

            rows += """
            <div class="fixture" data-category="\(category)" data-size="\(size)" data-dpi="\(dpi)" data-features="\(features)">
                <div class="fixture-header">
                    <div class="fixture-title">
                        <span class="fixture-name">\(file)</span>
                        \(categoryBadge)
                    </div>
                    <span class="fixture-meta">\(scoreHtml) \(timeStr)</span>
                </div>
                <div class="fixture-description">\(description)</div>
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
