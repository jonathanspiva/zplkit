import Foundation
import ZPLKit
import ZPLKitRenderer

/// Renders all ZPL fixtures using ZPLKitRenderer
/// Output goes to Tests/VisualTestHarness/output-swift/

@main
struct RenderFixtures {
    static func main() throws {
        let fileManager = FileManager.default

        // Find the package root (where Package.swift is)
        var currentDir = fileManager.currentDirectoryPath
        while !fileManager.fileExists(atPath: "\(currentDir)/Package.swift") {
            let parent = (currentDir as NSString).deletingLastPathComponent
            if parent == currentDir {
                print("Error: Could not find Package.swift")
                exit(1)
            }
            currentDir = parent
        }

        let fixturesDir = "\(currentDir)/Tests/VisualTestHarness/fixtures"
        let outputDir = "\(currentDir)/Tests/VisualTestHarness/output-swift"

        // Create output directory
        try fileManager.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

        // Get all .zpl files
        guard let files = try? fileManager.contentsOfDirectory(atPath: fixturesDir) else {
            print("Error: Could not read fixtures directory at \(fixturesDir)")
            exit(1)
        }

        let zplFiles = files.filter { $0.hasSuffix(".zpl") }.sorted()

        if zplFiles.isEmpty {
            print("No .zpl files found in fixtures/")
            return
        }

        print("Rendering \(zplFiles.count) ZPL file(s) with ZPLKitRenderer...")

        let renderer = ZPLRenderer()
        var successCount = 0
        var failCount = 0

        for file in zplFiles {
            let zplPath = "\(fixturesDir)/\(file)"
            let pngName = file.replacingOccurrences(of: ".zpl", with: ".png")
            let pngPath = "\(outputDir)/\(pngName)"

            do {
                let zpl = try String(contentsOfFile: zplPath, encoding: .utf8)

                // Output dimensions come from the ZPL's ^PW/^LL dot values.
                let (data, metrics) = try renderer.renderToPNG(zpl)
                try data.write(to: URL(fileURLWithPath: pngPath))

                let parseMs = String(format: "%.1f", metrics.parseTimeSeconds * 1000)
                let renderMs = String(format: "%.1f", metrics.renderTimeSeconds * 1000)
                print("  \u{2713} \(file) (parse: \(parseMs)ms, render: \(renderMs)ms)")
                successCount += 1
            } catch {
                print("  \u{2717} \(file): \(error)")
                failCount += 1
            }
        }

        print("\nDone. \(successCount) succeeded, \(failCount) failed.")
    }
}
