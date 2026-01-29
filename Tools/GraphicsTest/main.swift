import Foundation
import ZPLKit

#if canImport(AppKit)
import AppKit

/// Test graphics rendering with SF Symbols
/// Generates ZPL files that can be validated with Labelary

@main
struct GraphicsTest {
    static let symbols = [
        "checkmark.circle.fill",
        "xmark.circle.fill",
        "exclamationmark.triangle.fill",
        "star.fill",
        "heart.fill",
        "hand.thumbsup.fill",
        "bolt.fill",
        "flame.fill",
        "drop.fill",
        "leaf.fill"
    ]

    static func main() throws {
        let fileManager = FileManager.default

        // Find package root
        var root = fileManager.currentDirectoryPath
        while !fileManager.fileExists(atPath: "\(root)/Package.swift") {
            root = (root as NSString).deletingLastPathComponent
        }

        let outputDir = "\(root)/Tests/VisualTestHarness/fixtures"

        print("Generating SF Symbol graphics tests...\n")

        for symbolName in symbols {
            guard let nsImage = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
                print("  ✗ \(symbolName): Symbol not found")
                continue
            }

            // Configure for solid black rendering
            let config = NSImage.SymbolConfiguration(pointSize: 100, weight: .regular)
            let configuredImage = nsImage.withSymbolConfiguration(config) ?? nsImage

            // Render to CGImage
            guard let cgImage = renderSymbolToCGImage(configuredImage, size: 100) else {
                print("  ✗ \(symbolName): Failed to render")
                continue
            }

            // Create ZPL label with the symbol
            let label = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
                Text(symbolName.replacingOccurrences(of: ".fill", with: ""), at: .dots(20, 20))
                    .font(.default, height: .dots(25))
                Graphic(cgImage, at: .dots(50, 60), width: .dots(100), invert: false)
            }

            let zpl = label.render()
            let safeName = symbolName.replacingOccurrences(of: ".", with: "_")
            let filename = "graphic_\(safeName)_2x2_203.zpl"
            let path = "\(outputDir)/\(filename)"

            try zpl.write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            print("  ✓ \(filename)")
        }

        print("\nDone! Run 'swift run VisualTests --labelary' to validate with Labelary.")
    }

    static func renderSymbolToCGImage(_ image: NSImage, size: Int) -> CGImage? {
        let targetSize = NSSize(width: size, height: size)

        // Create a bitmap representation
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: size,
            pixelsHigh: size,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        // White background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: targetSize).fill()

        // Draw symbol in black
        NSColor.black.setFill()
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: .zero,
            operation: .sourceOver,
            fraction: 1.0
        )

        NSGraphicsContext.restoreGraphicsState()

        return rep.cgImage
    }
}
#else
@main
struct GraphicsTest {
    static func main() {
        print("This tool requires macOS (AppKit) for SF Symbols")
    }
}
#endif
