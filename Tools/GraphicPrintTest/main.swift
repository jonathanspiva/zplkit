import CoreGraphics
import CoreText
import Foundation
import ZPLKit
import ZPLKitPrinter

// Prints test labels to a real printer to exercise ZPLKit end-to-end.
//
// Usage:
//   swift run GraphicPrintTest [--fiducial] [--calibrate] <host>
//
//   (default)     Sends three demo labels: a CoreGraphics bitmap (^GF), an
//                 equivalent native-ZPL label, and a dither comparison.
//   --fiducial    Sends a registration fiducial instead (frame + crosshair) for
//                 checking print alignment. See "Alignment" below.
//   --calibrate   Runs media calibration (gap tracking + ~JC + save) before
//                 printing, so a mis-registered / parked printer doesn't
//                 silently drop labels.
//
// Traceability: every label carries an `ID <short-uuid>  <timestamp>` footer,
// and every send logs a matching `SENT ... id=... ts=...` line, so a physical
// label can be tied back to the exact send.
//
// Sensor-track safety: all content stays inset from the label edges (>= 20
// dots). Heavy black flush to the die-cut edge can blind a transmissive gap
// sensor and knock the printer out of registration, so keep the margins.
//
// Alignment: with --fiducial, the frame is inset a known 20 dots on every side.
// If registered, the white margin between the frame and the die-cut edge is
// equal top-vs-bottom and left-vs-right, and identical across consecutive
// copies. A consistent difference is a fixed offset (correctable with ^LT/^LS);
// drift across copies means the media tracking is wrong (see --calibrate).

// MARK: - Args

var argv = Array(CommandLine.arguments.dropFirst())
let doFiducial = argv.contains("--fiducial")
let doCalibrate = argv.contains("--calibrate")
argv.removeAll { $0.hasPrefix("--") }
let host = argv.first
    ?? (ProcessInfo.processInfo.environment["ZPLTOOL_ZM400_HOST"] ?? "192.168.1.100")

let dpi = 203
let W = 812   // 4 inches at 203 DPI
let H = 406   // 2 inches at 203 DPI
let inset = 20  // keep content off the edge / gap-sensor track

let printer = ZPLPrinter(host: host)

// MARK: - Helpers

/// A short UUID + human timestamp for cross-referencing physical labels with
/// send logs.
func idStamp() -> (id: String, ts: String) {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return (String(UUID().uuidString.prefix(8)), df.string(from: Date()))
}

func footer(_ id: String, _ ts: String) -> Text {
    Text("ID \(id)  \(ts)", at: .dots(inset + 10, H - 40)).font(.default, height: .dots(18))
}

/// Renders `label`, logs a traceable line, sends it, and pauses briefly.
func send(_ name: String, _ label: ZPLLabel, id: String, ts: String) async throws {
    let zpl = label.render()
    print("SENT \(name)  id=\(id)  ts=\(ts)  bytes=\(zpl.utf8.count)  host=\(host)")
    try await printer.send(zpl)
    try await Task.sleep(nanoseconds: 2_000_000_000)
}

/// Draws text into a CoreGraphics context (origin bottom-left).
func drawText(_ text: String, font: String, size: CGFloat, x: CGFloat, y: CGFloat, in ctx: CGContext) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let attrs: [CFString: Any] = [kCTFontAttributeName: f, kCTForegroundColorFromContextAttributeName: true]
    let attr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
    ctx.textPosition = CGPoint(x: x, y: y)
    CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
}

// MARK: - Optional calibration

if doCalibrate {
    print("Calibrating \(host): direct-thermal, gap tracking, ~JC + save ...")
    try await printer.setup(PrinterConfiguration.directThermal(widthDots: W, lengthDots: H))
    try await Task.sleep(nanoseconds: 3_000_000_000)
    print("Calibration done.")
}

// MARK: - Fiducial mode

if doFiducial {
    let (id, ts) = idStamp()
    let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
        // Frame inset a known 20 dots; white margin to the die-cut edge should
        // be equal on opposite sides when registered. Nothing touches the edge.
        Box(at: .dots(inset, inset), width: .dots(W - 2 * inset), height: .dots(H - 2 * inset)).thickness(2)
        Box(at: .dots(inset, H / 2 - 1), width: .dots(W - 2 * inset), height: .dots(2))   // crosshair H
        Box(at: .dots(W / 2 - 1, inset), width: .dots(2), height: .dots(H - 2 * inset))   // crosshair V
        Text("TOP", at: .dots(W / 2 - 34, inset + 12)).font(.default, height: .dots(24))
        Text("BOTTOM", at: .dots(W / 2 - 72, H - inset - 40)).font(.default, height: .dots(24))
        Text("FIDUCIAL  ID \(id)  \(ts)", at: .dots(inset + 40, H / 2 + 12)).font(.default, height: .dots(18))
    }
    try await send("fiducial", label, id: id, ts: ts)
    print("Fiducial sent. Check margins equal (top/bottom, left/right) and consistent across copies.")
} else {
    // MARK: - Demo labels (default)

    // 1) CoreGraphics bitmap label, sent as one ^GF.
    let (bmpID, bmpTS) = idStamp()
    guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
          let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W,
                              space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
        print("Failed to create graphics context"); exit(1)
    }
    ctx.setFillColor(gray: 1, alpha: 1); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    ctx.setFillColor(gray: 0, alpha: 1); ctx.setStrokeColor(gray: 0, alpha: 1)
    ctx.setLineWidth(3)
    ctx.stroke(CGRect(x: inset, y: inset, width: W - 2 * inset, height: H - 2 * inset))
    drawText("BITMAP LABEL TEST", font: "Helvetica-Bold", size: 36, x: 40, y: CGFloat(H - 70), in: ctx)
    drawText("Rendered via CoreGraphics, sent as ^GF", font: "Helvetica", size: 20, x: 40, y: CGFloat(H - 105), in: ctx)
    ctx.fill(CGRect(x: 40, y: 90, width: 200, height: 40))
    ctx.fillEllipse(in: CGRect(x: 300, y: 70, width: 80, height: 80))
    drawText("\(W)x\(H) dots (\(dpi) DPI)  4.0 x 2.0 in", font: "Courier", size: 16, x: 40, y: 70, in: ctx)
    drawText("ID \(bmpID)  \(bmpTS)", font: "Courier", size: 16, x: 40, y: 40, in: ctx)
    guard let cgImage = ctx.makeImage() else { print("Failed to create image"); exit(1) }
    let bitmapLabel = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
        Graphic(cgImage, at: .dots(0, 0), width: .dots(W), height: .dots(H))
    }

    // 2) Native-ZPL equivalent.
    let (natID, natTS) = idStamp()
    let nativeLabel = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
        Box(at: .dots(inset, inset), width: .dots(W - 2 * inset), height: .dots(H - 2 * inset)).thickness(3)
        Text("NATIVE ZPL LABEL TEST", at: .dots(40, 40)).font(.default, height: .dots(36))
        Text("Rendered by printer firmware", at: .dots(40, 90)).font(.default, height: .dots(20))
        Box(at: .dots(40, 140), width: .dots(200), height: .dots(40))
        Circle(at: .dots(300, 140), diameter: .dots(80))
        Text("\(W)x\(H) dots (\(dpi) DPI)  4.0 x 2.0 in", at: .dots(40, 250)).font(.default, height: .dots(16))
        footer(natID, natTS)
    }

    // 3) Dither comparison. Height 2 (matches common 4x2 stock); content stays
    //    within the 2" label so it registers on gap media.
    let gw = 180, gh = 250
    guard let gradCtx = CGContext(data: nil, width: gw, height: gh, bitsPerComponent: 8, bytesPerRow: gw,
                                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
        print("Failed to create gradient context"); exit(1)
    }
    if let data = gradCtx.data {
        let px = data.bindMemory(to: UInt8.self, capacity: gw * gh)
        for y in 0..<gh { for x in 0..<gw { px[y * gw + x] = UInt8(x * 255 / (gw - 1)) } }
    }
    guard let gradientImage = gradCtx.makeImage() else { print("Failed to create gradient image"); exit(1) }
    let (ditID, ditTS) = idStamp()
    let ditherLabel = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
        Text("Threshold", at: .dots(40, 24)).font(.default, height: .dots(20))
        Text("Floyd-Steinberg", at: .dots(320, 24)).font(.default, height: .dots(20))
        Text("Atkinson", at: .dots(600, 24)).font(.default, height: .dots(20))
        Graphic(gradientImage, at: .dots(40, 54), width: .dots(gw), height: .dots(gh))
        Graphic(gradientImage, at: .dots(320, 54), width: .dots(gw), height: .dots(gh)).dither(.floydSteinberg)
        Graphic(gradientImage, at: .dots(600, 54), width: .dots(gw), height: .dots(gh)).dither(.atkinson)
        footer(ditID, ditTS)
    }

    try await send("bitmap", bitmapLabel, id: bmpID, ts: bmpTS)
    try await send("native", nativeLabel, id: natID, ts: natTS)
    try await send("dither", ditherLabel, id: ditID, ts: ditTS)
    print("Done. Compare the three labels; cross-reference each footer ID with the SENT log lines above.")
}
