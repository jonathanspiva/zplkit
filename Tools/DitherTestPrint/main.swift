import CoreGraphics
import Foundation
import ImageIO
import ZPLKit
import ZPLKitPrinter

// Load the car photo
let imagePath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "/Users/jonathanspiva/code/personal-technology/test-images/car.jpeg"

let imageURL = URL(fileURLWithPath: imagePath)
guard let dataProvider = CGDataProvider(url: imageURL as CFURL),
      let source = CGImageSourceCreateWithDataProvider(dataProvider, nil),
      let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    print("Failed to load image from \(imagePath)")
    exit(1)
}

print("Loaded image: \(cgImage.width)x\(cgImage.height)")

// Both printers are 203 DPI, 4" wide labels
// ZM400: 4x6 labels, GX420t: 4x2 labels (direct thermal)
let printers: [(name: String, host: String, labelHeight: Double)] = [
    ("ZM400", "192.168.7.4", 6.0),
    ("GX420t", "192.168.7.5", 2.0),
]

for printer in printers {
    let labelW = 4.0
    let labelH = printer.labelHeight

    // Use aspectFill + floydSteinberg for best photo output
    let label = ZPLLabel(width: labelW, height: labelH, dpi: .dpi203) {
        Graphic(cgImage, at: .dots(0, 0), width: .inches(labelW), height: .inches(labelH))
            .dither(.floydSteinberg)
            .contentMode(.aspectFill)
    }

    let zpl = label.render()
    let kb = String(format: "%.1f", Double(zpl.utf8.count) / 1024.0)
    print("\(printer.name) (\(printer.host)): \(labelW)x\(labelH)\" label, \(kb) KB ZPL")

    let zplPrinter = ZPLPrinter(host: printer.host)
    let start = Date()
    try await zplPrinter.send(zpl)
    let elapsed = String(format: "%.2f", Date().timeIntervalSince(start))
    print("  Sent in \(elapsed)s")

    // Pause between prints
    if printer.host != printers.last?.host {
        try await Task.sleep(nanoseconds: 1_000_000_000)
    }
}

print("Done!")
