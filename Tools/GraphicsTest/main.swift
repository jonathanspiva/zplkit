import Foundation
import ZPLKit
@preconcurrency import Awesome

#if canImport(AppKit)
import AppKit

/// Test graphics rendering with FontAwesome icons
/// Generates ZPL files that can be validated with Labelary

@main
struct GraphicsTest {
    // Single icon tests - FontAwesome Solid icons
    nonisolated(unsafe) static let singleIcons: [(name: String, icon: Awesome.Solid)] = [
        ("checkmark_circle_fill", .checkCircle),
        ("xmark_circle_fill", .timesCircle),
        ("exclamationmark_triangle_fill", .exclamationTriangle),
        ("star_fill", .star),
        ("heart_fill", .heart),
        ("hand_thumbsup_fill", .thumbsUp),
        ("bolt_fill", .bolt),
        ("flame_fill", .fire),
        ("drop_fill", .tint),
        ("leaf_fill", .leaf)
    ]

    // Multi-icon combinations with text
    nonisolated(unsafe) static let multiIconLabels: [(name: String, icons: [Awesome.Solid], text: String)] = [
        ("status_ok", [.checkCircle], "Status: OK"),
        ("status_error", [.timesCircle], "Status: Error"),
        ("status_warning", [.exclamationTriangle], "Warning!"),
        ("rating_3star", [.star, .star, .star], "Rating"),
        ("liked", [.heart, .thumbsUp], "Liked!"),
        ("hot_item", [.fire, .bolt], "Hot Item"),
        ("organic", [.leaf, .tint], "Organic"),
        ("approve_reject", [.checkCircle, .timesCircle], "Choose One"),
        ("weather_sun", [.sun], "Sunny"),
        ("weather_rain", [.cloudRain], "Rainy"),
        ("fragile", [.exclamationTriangle, .exclamationTriangle], "FRAGILE"),
        ("priority", [.bolt], "Priority"),
    ]

    static func main() throws {
        let fileManager = FileManager.default

        // Find package root
        var root = fileManager.currentDirectoryPath
        while !fileManager.fileExists(atPath: "\(root)/Package.swift") {
            root = (root as NSString).deletingLastPathComponent
        }

        let outputDir = "\(root)/Tests/VisualTestHarness/fixtures"

        print("Generating FontAwesome graphics tests...\n")

        // Generate single icon tests
        print("=== Single Icon Tests ===")
        for (name, icon) in singleIcons {
            guard let cgImage = renderIcon(icon, size: 100) else {
                print("  ✗ \(name): Failed to render")
                continue
            }

            let displayName = name.replacingOccurrences(of: "_fill", with: "")
                .replacingOccurrences(of: "_", with: " ")
            let label = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
                Text(displayName, at: .dots(20, 20))
                    .font(.default, height: .dots(25))
                Graphic(cgImage, at: .dots(50, 60), width: .dots(100), invert: false)
            }

            let zpl = label.render()
            let filename = "graphic_\(name)_2x2_203.zpl"
            let path = "\(outputDir)/\(filename)"

            try zpl.write(toFile: path, atomically: true, encoding: .utf8)
            print("  ✓ \(filename)")
        }

        // Generate multi-icon tests with text
        print("\n=== Multi-Icon Tests ===")
        for (name, icons, text) in multiIconLabels {
            let label = try createMultiIconLabel(icons: icons, text: text)
            let filename = "graphic_multi_\(name)_2x1_203.zpl"
            let path = "\(outputDir)/\(filename)"

            try label.render().write(toFile: path, atomically: true, encoding: .utf8)
            print("  ✓ \(filename)")
        }

        // Generate food labels with icons
        print("\n=== Food Labels with Icons ===")
        try generateFoodLabelsWithIcons(outputDir: outputDir)

        // Generate shop labels with icons
        print("\n=== Shop Labels with Icons ===")
        try generateShopLabelsWithIcons(outputDir: outputDir)

        print("\nDone! Run 'swift run VisualTests' to render and verify.")
    }

    static func createMultiIconLabel(icons: [Awesome.Solid], text: String) throws -> ZPLLabel {
        let iconSize = 60
        let spacing = 10

        return ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
            // Text at top
            Text(text, at: .dots(20, 15))
                .font(.default, height: .dots(30))

            // Icons in a row
            for (index, icon) in icons.enumerated() {
                if let cgImage = renderIcon(icon, size: iconSize) {
                    let xPos = 20 + (index * (iconSize + spacing))
                    Graphic(cgImage, at: .dots(xPos, 55), width: .dots(iconSize), invert: false)
                }
            }
        }
    }

    static func generateFoodLabelsWithIcons(outputDir: String) throws {
        // Freezer label with snowflake
        if let snowflake = renderIcon(.snowflake, size: 50) {
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
        if let warning = renderIcon(.exclamationTriangle, size: 40) {
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
        if let heart = renderIcon(.heart, size: 40) {
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

    static func generateShopLabelsWithIcons(outputDir: String) throws {
        // Caliper bolts with torque spec
        if let wrench = renderIcon(.wrench, size: 40) {
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
        if let wrench = renderIcon(.wrench, size: 40) {
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
        if let wrench = renderIcon(.wrench, size: 40) {
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
        if let drop = renderIcon(.tint, size: 35) {
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
        if let wrench = renderIcon(.wrench, size: 40) {
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
        if let warning = renderIcon(.exclamationTriangle, size: 35) {
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
        if let flame = renderIcon(.fire, size: 40) {
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
        if let camera = renderIcon(.camera, size: 35) {
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

        // Torque spec label
        if let wrench = renderIcon(.wrench, size: 40) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(wrench, at: .dots(10, 15), width: .dots(40), invert: false)
                Text("TORQUE SPEC", at: .dots(60, 15))
                    .font(.default, height: .dots(24))
                Text("See manual", at: .dots(60, 50))
                    .font(.default, height: .dots(20))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_torque_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_torque_2x1_203.zpl")
        }

        // Caution label
        if let warning = renderIcon(.exclamationTriangle, size: 45) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(warning, at: .dots(10, 20), width: .dots(45), invert: false)
                Text("CAUTION", at: .dots(65, 20))
                    .font(.default, height: .dots(28))
                Text("Check clearance", at: .dots(65, 55))
                    .font(.default, height: .dots(20))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_caution_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_caution_2x1_203.zpl")
        }

        // Loctite reminder
        if let drop = renderIcon(.tint, size: 40) {
            let label = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
                Graphic(drop, at: .dots(10, 15), width: .dots(40), invert: false)
                Text("LOCTITE", at: .dots(60, 15))
                    .font(.default, height: .dots(26))
                Text("Blue 242", at: .dots(60, 50))
                    .font(.default, height: .dots(22))
            }
            try label.render().write(toFile: "\(outputDir)/graphic_shop_loctite_2x1_203.zpl", atomically: true, encoding: .utf8)
            print("  ✓ graphic_shop_loctite_2x1_203.zpl")
        }
    }

    static func renderIcon(_ icon: Awesome.Solid, size: Int) -> CGImage? {
        let nsImage = icon.asImage(size: CGFloat(size), color: .black, backgroundColor: .white)
        return renderToCGImage(nsImage, size: size)
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

        // Draw icon
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
        print("This tool requires macOS (AppKit) for FontAwesome rendering")
    }
}
#endif
