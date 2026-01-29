import Foundation
import ZPLKit
import ZPLKitRenderer

/// Swift-native visual test harness for ZPLKit
/// Renders all fixtures and generates HTML comparison
///
/// Usage:
///   swift run VisualTests                      # Render all (fast, local)
///   swift run VisualTests --labelary           # Also fetch Labelary renders
///   swift run VisualTests --filter graphic     # Only files matching "graphic"
///   swift run VisualTests --filter graphic --labelary

@main
struct VisualTests {
    static let fixturesDir = "Tests/VisualTestHarness/fixtures"
    static let outputDir = "Tests/VisualTestHarness/output-swift"
    static let labelaryDir = "Tests/VisualTestHarness/output-labelary"
    static let htmlPath = "Tests/VisualTestHarness/comparison.html"

    static func main() async throws {
        let args = CommandLine.arguments
        let includeLabelary = args.contains("--labelary")

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
        let htmlFullPath = "\(root)/\(htmlPath)"

        // Create output directories
        try fileManager.createDirectory(atPath: outputPath, withIntermediateDirectories: true)
        if includeLabelary {
            try fileManager.createDirectory(atPath: labelaryPath, withIntermediateDirectories: true)
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
        if includeLabelary {
            print("\n=== Fetching from Labelary API ===")
            print("(Rate limited to 2 req/sec)\n")

            for file in zplFiles {
                let zplPath = "\(fixturesPath)/\(file)"
                let pngName = file.replacingOccurrences(of: ".zpl", with: ".png")
                let pngPath = "\(labelaryPath)/\(pngName)"

                do {
                    let zpl = try String(contentsOfFile: zplPath, encoding: .utf8)
                    let dpi = parseDPI(from: file)
                    let (width, height) = parseDimensions(from: file)

                    if let data = try await fetchLabelary(zpl: zpl, dpi: dpi, width: width, height: height) {
                        try data.write(to: URL(fileURLWithPath: pngPath))
                        print("  ✓ \(file)")
                    } else {
                        print("  ✗ \(file): No data returned")
                    }

                    // Rate limit
                    try await Task.sleep(nanoseconds: 500_000_000)
                } catch {
                    print("  ✗ \(file): \(error)")
                }
            }
        }

        // Generate HTML
        print("\n=== Generating comparison.html ===")
        let html = generateHTML(fixtures: zplFiles, results: results, includeLabelary: includeLabelary)
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

    static func fetchLabelary(zpl: String, dpi: DPI, width: Double, height: Double) async throws -> Data? {
        // Labelary uses dots per mm (dpmm) not DPI
        let dpmm: String
        switch dpi {
        case .dpi152: dpmm = "6dpmm"
        case .dpi203: dpmm = "8dpmm"
        case .dpi300: dpmm = "12dpmm"
        case .dpi600: dpmm = "24dpmm"
        }

        let urlString = "http://api.labelary.com/v1/printers/\(dpmm)/labels/\(width)x\(height)/0/"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("image/png", forHTTPHeaderField: "Accept")
        request.httpBody = zpl.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return nil
        }

        return data
    }

    static func generateHTML(fixtures: [String], results: [(name: String, dpi: DPI, parseMs: Double, renderMs: Double)], includeLabelary: Bool) -> String {
        let resultsDict = Dictionary(uniqueKeysWithValues: results.map { ($0.name, $0) })

        var rows = ""
        for file in fixtures {
            let pngName = file.replacingOccurrences(of: ".zpl", with: ".png")
            let result = resultsDict[file]
            let timeStr = result.map { String(format: "%.1fms", $0.parseMs + $0.renderMs) } ?? "—"

            rows += """
            <div class="fixture">
                <div class="fixture-header">
                    <span class="fixture-name">\(file)</span>
                    <span class="fixture-time">\(timeStr)</span>
                </div>
                <div class="renders">
                    <div class="render">
                        <div class="render-label">ZPLKitRenderer</div>
                        <img src="output-swift/\(pngName)" alt="\(file)">
                    </div>
            """

            if includeLabelary {
                rows += """
                    <div class="render">
                        <div class="render-label">Labelary</div>
                        <img src="output-labelary/\(pngName)" alt="\(file)">
                    </div>
            """
            }

            rows += """
                </div>
            </div>
            """
        }

        let totalTime = results.reduce(0) { $0 + $1.parseMs + $1.renderMs }
        let avgTime = results.isEmpty ? 0 : totalTime / Double(results.count)

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
                    background: #f5f5f5;
                }
                h1 { margin: 0 0 10px 0; }
                .summary {
                    background: #e8f4fd;
                    padding: 15px;
                    border-radius: 8px;
                    margin-bottom: 20px;
                }
                .summary span { margin-right: 30px; }
                .fixture {
                    background: white;
                    border-radius: 8px;
                    margin-bottom: 15px;
                    overflow: hidden;
                    box-shadow: 0 1px 3px rgba(0,0,0,0.1);
                }
                .fixture-header {
                    background: #333;
                    color: white;
                    padding: 10px 15px;
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                }
                .fixture-name { font-family: monospace; font-size: 14px; }
                .fixture-time { font-size: 12px; color: #aaa; }
                .renders {
                    display: flex;
                    gap: 20px;
                    padding: 15px;
                    flex-wrap: wrap;
                }
                .render {
                    flex: 1;
                    min-width: 300px;
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
                .filter-bar {
                    margin-bottom: 15px;
                }
                .filter-bar input {
                    padding: 8px 12px;
                    font-size: 14px;
                    border: 1px solid #ddd;
                    border-radius: 4px;
                    width: 300px;
                }
            </style>
        </head>
        <body>
            <h1>ZPLKit Visual Tests</h1>
            <div class="summary">
                <span><strong>\(fixtures.count)</strong> fixtures</span>
                <span><strong>\(String(format: "%.1f", totalTime))ms</strong> total render time</span>
                <span><strong>\(String(format: "%.2f", avgTime))ms</strong> average</span>
            </div>
            <div class="filter-bar">
                <input type="text" id="filter" placeholder="Filter fixtures..." oninput="filterFixtures()">
            </div>
            <div id="fixtures">
                \(rows)
            </div>
            <script>
                function filterFixtures() {
                    const filter = document.getElementById('filter').value.toLowerCase();
                    document.querySelectorAll('.fixture').forEach(f => {
                        const name = f.querySelector('.fixture-name').textContent.toLowerCase();
                        f.style.display = name.includes(filter) ? '' : 'none';
                    });
                }
            </script>
        </body>
        </html>
        """
    }
}
