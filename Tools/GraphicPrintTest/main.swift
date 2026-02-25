import CoreGraphics
import CoreText
import Foundation
import ZPLKit
import ZPLKitPrinter

// MARK: - Render a 4x2 label entirely as a bitmap graphic

let host = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "192.168.7.4"
let dpi = 203
let widthDots = 812   // 4 inches at 203 DPI
let heightDots = 406  // 2 inches at 203 DPI

print("Rendering \(widthDots)x\(heightDots) bitmap label...")

// Create a CGImage with text, a border, and some shapes
guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
      let ctx = CGContext(
          data: nil,
          width: widthDots,
          height: heightDots,
          bitsPerComponent: 8,
          bytesPerRow: widthDots,
          space: colorSpace,
          bitmapInfo: CGImageAlphaInfo.none.rawValue
      ) else {
    print("Failed to create graphics context")
    exit(1)
}

// Helper to draw text using CoreText
func drawText(_ text: String, fontName: String, fontSize: CGFloat, x: CGFloat, y: CGFloat, context: CGContext) {
    let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
    let attrs: [CFString: Any] = [
        kCTFontAttributeName: font,
        kCTForegroundColorFromContextAttributeName: true
    ]
    let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
    let line = CTLineCreateWithAttributedString(attrStr)
    context.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(line, context)
}

// White background
ctx.setFillColor(gray: 1.0, alpha: 1.0)
ctx.fill(CGRect(x: 0, y: 0, width: widthDots, height: heightDots))

// Black drawing color
ctx.setFillColor(gray: 0.0, alpha: 1.0)
ctx.setStrokeColor(gray: 0.0, alpha: 1.0)

// Border (3 dot thick)
ctx.setLineWidth(3)
ctx.stroke(CGRect(x: 5, y: 5, width: widthDots - 10, height: heightDots - 10))

// Draw title text
drawText("BITMAP LABEL TEST", fontName: "Helvetica-Bold", fontSize: 36, x: 30, y: CGFloat(heightDots - 60), context: ctx)

// Draw subtitle
drawText("Rendered via CoreGraphics, sent as ^GF", fontName: "Helvetica", fontSize: 20, x: 30, y: CGFloat(heightDots - 95), context: ctx)

// Draw a filled rectangle
ctx.fill(CGRect(x: 30, y: 80, width: 200, height: 40))

// Draw a circle
ctx.fillEllipse(in: CGRect(x: 300, y: 60, width: 80, height: 80))

// Draw info text
let infoLines = [
    "\(widthDots)x\(heightDots) dots (\(dpi) DPI)",
    "4.0 x 2.0 inches",
    "Host: \(host)",
]
for (i, text) in infoLines.enumerated() {
    drawText(text, fontName: "Courier", fontSize: 16, x: 30, y: CGFloat(heightDots - 140 - (i * 22)), context: ctx)
}

// Create CGImage
guard let cgImage = ctx.makeImage() else {
    print("Failed to create image")
    exit(1)
}

// Build ZPL label using the Graphic element
let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
    Graphic(cgImage, at: .dots(0, 0), width: .dots(widthDots), height: .dots(heightDots))
}

let zpl = label.render()

// Stats
let zplBytes = zpl.utf8.count
print("ZPL size: \(zplBytes) bytes (\(String(format: "%.1f", Double(zplBytes) / 1024.0)) KB)")

// For comparison, a native ZPL label with similar content
let nativeLabel = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
    Box(at: .dots(5, 5), width: .dots(802), height: .dots(396))
        .thickness(3)
    Text("NATIVE ZPL LABEL TEST", at: .dots(30, 30))
        .font(.default, height: .dots(36))
    Text("Rendered by printer firmware", at: .dots(30, 80))
        .font(.default, height: .dots(20))
    Box(at: .dots(30, 130), width: .dots(200), height: .dots(40))
    Circle(at: .dots(300, 130), diameter: .dots(80))
    Text("\(widthDots)x\(heightDots) dots (\(dpi) DPI)", at: .dots(30, 200))
        .font(.default, height: .dots(16))
    Text("4.0 x 2.0 inches", at: .dots(30, 225))
        .font(.default, height: .dots(16))
    Text("Host: \(host)", at: .dots(30, 250))
        .font(.default, height: .dots(16))
}
let nativeZpl = nativeLabel.render()
let nativeBytes = nativeZpl.utf8.count
print("Bitmap is \(String(format: "%.0f", Double(zplBytes) / Double(nativeBytes)))x larger")
print()

// MARK: - Dither Comparison Label

// Create a gradient test image (smooth horizontal gradient from black to white)
let gradWidth = 200
let gradHeight = 300
guard let gradCtx = CGContext(
    data: nil,
    width: gradWidth,
    height: gradHeight,
    bitsPerComponent: 8,
    bytesPerRow: gradWidth,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.none.rawValue
) else {
    print("Failed to create gradient context")
    exit(1)
}

// Draw horizontal gradient
if let data = gradCtx.data {
    let pixels = data.bindMemory(to: UInt8.self, capacity: gradWidth * gradHeight)
    for y in 0..<gradHeight {
        for x in 0..<gradWidth {
            pixels[y * gradWidth + x] = UInt8(x * 255 / (gradWidth - 1))
        }
    }
}

guard let gradientImage = gradCtx.makeImage() else {
    print("Failed to create gradient image")
    exit(1)
}

// Build a comparison label: three columns showing different dither methods
// 4" wide label at 203 DPI = 812 dots, using 3" tall = 609 dots
let ditherLabel = ZPLLabel(width: 4, height: 3, dpi: .dpi203) {
    // Column headers
    Text("Threshold", at: .dots(30, 20))
        .font(.default, height: .dots(22))
    Text("Floyd-Steinberg", at: .dots(280, 20))
        .font(.default, height: .dots(22))
    Text("Atkinson", at: .dots(560, 20))
        .font(.default, height: .dots(22))

    // Column 1: default threshold (no dither)
    Graphic(gradientImage, at: .dots(30, 50), width: .dots(gradWidth), height: .dots(gradHeight))

    // Column 2: Floyd-Steinberg
    Graphic(gradientImage, at: .dots(280, 50), width: .dots(gradWidth), height: .dots(gradHeight))
        .dither(.floydSteinberg)

    // Column 3: Atkinson
    Graphic(gradientImage, at: .dots(560, 50), width: .dots(gradWidth), height: .dots(gradHeight))
        .dither(.atkinson)

    // Footer
    Text("Dither Comparison - Gradient", at: .dots(30, 370))
        .font(.default, height: .dots(18))
}

let ditherZpl = ditherLabel.render()
let ditherBytes = ditherZpl.utf8.count
print("Dither comparison label: \(ditherBytes) bytes (\(String(format: "%.1f", Double(ditherBytes) / 1024.0)) KB)")

// Send all labels
let printer = ZPLPrinter(host: host)

print("Sending bitmap label to \(host)...")
let bitmapStart = Date()
try await printer.send(zpl)
let bitmapTime = Date().timeIntervalSince(bitmapStart)
print("Bitmap sent in \(String(format: "%.2f", bitmapTime))s")

// Small delay between prints
try await Task.sleep(nanoseconds: 2_000_000_000)

print("Sending native ZPL label to \(host)...")
let nativeStart = Date()
try await printer.send(nativeZpl)
let nativeTime = Date().timeIntervalSince(nativeStart)
print("Native sent in \(String(format: "%.2f", nativeTime))s")

try await Task.sleep(nanoseconds: 2_000_000_000)

print("Sending dither comparison label to \(host)...")
let ditherStart = Date()
try await printer.send(ditherZpl)
let ditherTime = Date().timeIntervalSince(ditherStart)
print("Dither comparison sent in \(String(format: "%.2f", ditherTime))s")

print()
print("Done! Compare the three labels.")
