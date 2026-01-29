import Foundation
import ZPLKit

#if canImport(AppKit)
import AppKit

/// Test graphics rendering with SF Symbols
/// Generates ZPL files that can be validated with Labelary

@main
struct GraphicsTest {
    // Single symbol tests
    static let singleSymbols = [
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

    // Multi-symbol combinations with text
    static let multiSymbolLabels: [(name: String, symbols: [String], text: String)] = [
        ("status_ok", ["checkmark.circle.fill"], "Status: OK"),
        ("status_error", ["xmark.circle.fill"], "Status: Error"),
        ("status_warning", ["exclamationmark.triangle.fill"], "Warning!"),
        ("rating_3star", ["star.fill", "star.fill", "star.fill"], "Rating"),
        ("liked", ["heart.fill", "hand.thumbsup.fill"], "Liked!"),
        ("hot_item", ["flame.fill", "bolt.fill"], "Hot Item"),
        ("organic", ["leaf.fill", "drop.fill"], "Organic"),
        ("approve_reject", ["checkmark.circle.fill", "xmark.circle.fill"], "Choose One"),
        ("weather_sun", ["sun.max.fill"], "Sunny"),
        ("weather_rain", ["cloud.rain.fill"], "Rainy"),
        ("fragile", ["exclamationmark.triangle.fill", "exclamationmark.triangle.fill"], "FRAGILE"),
        ("priority", ["bolt.fill"], "Priority"),
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

        // Generate single symbol tests (existing)
        print("=== Single Symbol Tests ===")
        for symbolName in singleSymbols {
            guard let cgImage = renderSymbol(symbolName, size: 100) else {
                print("  ✗ \(symbolName): Symbol not found")
                continue
            }

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

        // Generate multi-symbol tests with text
        print("\n=== Multi-Symbol Tests ===")
        for (name, symbols, text) in multiSymbolLabels {
            let label = try createMultiSymbolLabel(symbols: symbols, text: text)
            let filename = "graphic_multi_\(name)_2x1_203.zpl"
            let path = "\(outputDir)/\(filename)"

            try label.render().write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            print("  ✓ \(filename)")
        }

        // Generate food labels with symbols
        print("\n=== Food Labels with Symbols ===")
        try generateFoodLabelsWithSymbols(outputDir: outputDir)

        // Generate shop labels with symbols
        print("\n=== Shop Labels with Symbols ===")
        try generateShopLabelsWithSymbols(outputDir: outputDir)

        print("\nDone! Run 'swift run VisualTests --filter graphic' to render.")
    }

    static func createMultiSymbolLabel(symbols: [String], text: String) throws -> ZPLLabel {
        let symbolSize = 60
        let spacing = 10

        return ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
            // Text at top
            Text(text, at: .dots(20, 15))
                .font(.default, height: .dots(30))

            // Symbols in a row
            for (index, symbolName) in symbols.enumerated() {
                if let cgImage = renderSymbol(symbolName, size: symbolSize) {
                    let xPos = 20 + (index * (symbolSize + spacing))
                    Graphic(cgImage, at: .dots(xPos, 55), width: .dots(symbolSize), invert: false)
                }
            }
        }
    }

    static func generateFoodLabelsWithSymbols(outputDir: String) throws {
        // Freezer label with snowflake
        if let snowflake = renderSymbol("snowflake", size: 50) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(snowflake, at: .dots(15, 25), width: .dots(50), invert: false)
                Text("Chicken Stock", at: .dots(75, 20))
                    .font(.default, height: .dots(28))
                Text("Frozen 1/28", at: .dots(75, 55))
                    .font(.default, height: .dots(22))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_food_freezer_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_food_freezer_2x1_203.zpl")
        }

        // Perishable warning
        if let warning = renderSymbol("exclamationmark.triangle.fill", size: 40) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(warning, at: .dots(15, 30), width: .dots(40), invert: false)
                Text("PERISHABLE", at: .dots(65, 20))
                    .font(.default, height: .dots(28))
                Text("Use by 2/1", at: .dots(65, 55))
                    .font(.default, height: .dots(22))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_food_perishable_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_food_perishable_2x1_203.zpl")
        }

        // Homemade with heart
        if let heart = renderSymbol("heart.fill", size: 40) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Text("Homemade", at: .dots(20, 15))
                    .font(.default, height: .dots(26))
                Graphic(heart, at: .dots(170, 10), width: .dots(40), invert: false)
                Text("Tomato Sauce", at: .dots(20, 50))
                    .font(.default, height: .dots(24))
                Text("1/28", at: .dots(20, 80))
                    .font(.default, height: .dots(20))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_food_homemade_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_food_homemade_2x1_203.zpl")
        }
    }

    static func generateShopLabelsWithSymbols(outputDir: String) throws {
        // Caliper bolts with torque spec
        if let wrench = renderSymbol("wrench.fill", size: 40) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(wrench, at: .dots(10, 15), width: .dots(40), invert: false)
                Text("Caliper Bolts (2)", at: .dots(60, 10))
                    .font(.default, height: .dots(22))
                Text("M8x35  6mm hex", at: .dots(60, 38))
                    .font(.default, height: .dots(20))
                Text("Torque: 35Nm", at: .dots(60, 65))
                    .font(.default, height: .dots(20))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_caliper_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_caliper_2x1_203.zpl")
        }

        // Axle nut
        if let wrench = renderSymbol("wrench.fill", size: 40) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(wrench, at: .dots(10, 15), width: .dots(40), invert: false)
                Text("Rear Axle Nut", at: .dots(60, 10))
                    .font(.default, height: .dots(22))
                Text("M18  27mm socket", at: .dots(60, 38))
                    .font(.default, height: .dots(20))
                Text("Torque: 100Nm", at: .dots(60, 65))
                    .font(.default, height: .dots(20))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_axle_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_axle_2x1_203.zpl")
        }

        // Triple clamp bolts
        if let wrench = renderSymbol("wrench.fill", size: 40) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(wrench, at: .dots(10, 15), width: .dots(40), invert: false)
                Text("Triple Clamp (4)", at: .dots(60, 10))
                    .font(.default, height: .dots(22))
                Text("M8x30  5mm hex", at: .dots(60, 38))
                    .font(.default, height: .dots(20))
                Text("Torque: 25Nm", at: .dots(60, 65))
                    .font(.default, height: .dots(20))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_triple_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_triple_2x1_203.zpl")
        }

        // Engine mount with Loctite
        if let drop = renderSymbol("drop.fill", size: 35) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(drop, at: .dots(10, 15), width: .dots(35), invert: false)
                Text("Engine Mount (2)", at: .dots(55, 10))
                    .font(.default, height: .dots(22))
                Text("M10x40  8mm hex", at: .dots(55, 38))
                    .font(.default, height: .dots(20))
                Text("45Nm + Loctite", at: .dots(55, 65))
                    .font(.default, height: .dots(20))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_engine_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_engine_2x1_203.zpl")
        }

        // Sprocket bolts
        if let wrench = renderSymbol("wrench.fill", size: 40) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(wrench, at: .dots(10, 15), width: .dots(40), invert: false)
                Text("Sprocket (6)", at: .dots(60, 10))
                    .font(.default, height: .dots(22))
                Text("M8x20  T40 torx", at: .dots(60, 38))
                    .font(.default, height: .dots(20))
                Text("Torque: 30Nm", at: .dots(60, 65))
                    .font(.default, height: .dots(20))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_sprocket_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_sprocket_2x1_203.zpl")
        }

        // Brake line banjo bolts
        if let warning = renderSymbol("exclamationmark.triangle.fill", size: 35) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(warning, at: .dots(10, 15), width: .dots(35), invert: false)
                Text("Banjo Bolts (2)", at: .dots(55, 10))
                    .font(.default, height: .dots(22))
                Text("M10x1.0  12mm", at: .dots(55, 38))
                    .font(.default, height: .dots(20))
                Text("20Nm + new washers", at: .dots(55, 65))
                    .font(.default, height: .dots(18))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_banjo_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_banjo_2x1_203.zpl")
        }

        // Exhaust - caution hot
        if let flame = renderSymbol("flame.fill", size: 40) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(flame, at: .dots(10, 15), width: .dots(40), invert: false)
                Text("Exhaust Studs (4)", at: .dots(60, 10))
                    .font(.default, height: .dots(22))
                Text("M8x40  12mm nut", at: .dots(60, 38))
                    .font(.default, height: .dots(20))
                Text("25Nm - Anti-seize", at: .dots(60, 65))
                    .font(.default, height: .dots(20))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_exhaust_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_exhaust_2x1_203.zpl")
        }

        // Photo taken indicator
        if let camera = renderSymbol("camera.fill", size: 35) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(camera, at: .dots(10, 30), width: .dots(35), invert: false)
                Text("Wiring Harness", at: .dots(55, 15))
                    .font(.default, height: .dots(22))
                Text("Photo reference", at: .dots(55, 45))
                    .font(.default, height: .dots(20))
                Text("taken before removal", at: .dots(55, 70))
                    .font(.default, height: .dots(18))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_photo_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_photo_2x1_203.zpl")
        }
    }

    static func renderSymbol(_ name: String, size: Int) -> CGImage? {
        guard let nsImage = NSImage(systemSymbolName: name, accessibilityDescription: nil) else {
            return nil
        }

        let config = NSImage.SymbolConfiguration(pointSize: CGFloat(size), weight: .regular)
        let configuredImage = nsImage.withSymbolConfiguration(config) ?? nsImage

        return renderToCGImage(configuredImage, size: size)
    }

    static func renderToCGImage(_ image: NSImage, size: Int) -> CGImage? {
        let targetSize = NSSize(width: size, height: size)

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
