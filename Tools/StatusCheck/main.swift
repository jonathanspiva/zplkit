import CoreGraphics
import CoreText
import Foundation
import ZPLKit
import ZPLKitPrinter

let args = Array(CommandLine.arguments.dropFirst())

guard !args.isEmpty else {
    print("Usage: swift run StatusCheck <command> <IP> [<IP> ...]")
    print("Commands:")
    print("  status <IP>       Query printer status")
    print("  feed <IP>         Feed one label")
    print("  send <IP> <ZPL>   Send raw ZPL string")
    print("  graphic <IP>      Send bitmap vs native ZPL test labels")
    exit(1)
}

let command = args[0]

switch command {
case "status":
    let hosts = Array(args.dropFirst())
    guard !hosts.isEmpty else {
        print("Usage: swift run StatusCheck status <IP> [<IP> ...]")
        exit(1)
    }
    for host in hosts {
        let printer = ZPLPrinter(host: host, timeout: 5)
        print("[\(host)]")

        do {
            let info = try await printer.queryInfo()
            print("  Model: \(info.model)")
            print("  Firmware: \(info.firmwareVersion)")
            print("  DPI: \(info.dpi)")
        } catch {
            print("  Info failed: \(error)")
        }

        do {
            let status = try await printer.queryStatus()
            print("  Ready: \(status.isReadyToPrint)")
            if status.isPaperOut { print("  *** PAPER OUT ***") }
            if status.isHeadOpen { print("  *** HEAD OPEN ***") }
            if status.isRibbonOut { print("  *** RIBBON OUT ***") }
            if status.isPaused { print("  *** PAUSED ***") }
            if status.isHeadTooHot { print("  *** HEAD TOO HOT ***") }
            if status.isReceiveBufferFull { print("  *** BUFFER FULL ***") }
            if status.formatsInBuffer > 0 { print("  Formats in buffer: \(status.formatsInBuffer)") }
            if status.labelsRemainingInBatch > 0 { print("  Labels remaining: \(status.labelsRemainingInBatch)") }
            print("  Label length: \(status.labelLengthInDots) dots")
        } catch {
            print("  Status failed: \(error)")
        }

        do {
            let memory = try await printer.queryMemory()
            print("  Memory: \(memory)")
        } catch {
            print("  Memory failed: \(error)")
        }

        print()
    }

case "feed":
    let hosts = Array(args.dropFirst())
    guard !hosts.isEmpty else {
        print("Usage: swift run StatusCheck feed <IP>")
        exit(1)
    }
    for host in hosts {
        let printer = ZPLPrinter(host: host, timeout: 5)
        print("Feeding \(host)...")

        // Try multiple approaches
        let feedCommands = [
            ("^XA^FO0,0^FD ^FS^XZ (label with space)", "^XA^FO0,0^FD ^FS^XZ"),
            ("^XA^FO0,0^GB1,1,1^FS^XZ (label with dot)", "^XA^FO0,0^GB1,1,1^FS^XZ"),
        ]

        for (desc, cmd) in feedCommands {
            do {
                print("  Trying \(desc)...")
                try await printer.send(cmd)
                print("    Sent OK")
                // Wait a moment to see if it worked
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                print("    Failed: \(error)")
            }
        }
    }

case "send":
    guard args.count >= 3 else {
        print("Usage: swift run StatusCheck send <IP> <ZPL>")
        exit(1)
    }
    let host = args[1]
    let zpl = args[2]
    let printer = ZPLPrinter(host: host, timeout: 5)
    print("Sending to \(host): \(zpl)")
    do {
        try await printer.send(zpl)
        print("  Done")
    } catch {
        print("  Failed: \(error)")
    }

case "graphic":
    guard args.count >= 2 else {
        print("Usage: swift run StatusCheck graphic <IP>")
        exit(1)
    }
    let host = args[1]
    let dpi = 203
    let widthDots = 812
    let heightDots = 406

    print("Rendering \(widthDots)x\(heightDots) bitmap label...")

    guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
          let ctx = CGContext(
              data: nil, width: widthDots, height: heightDots,
              bitsPerComponent: 8, bytesPerRow: widthDots,
              space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
          ) else {
        print("Failed to create graphics context")
        exit(1)
    }

    func drawText(_ text: String, fontName: String, fontSize: CGFloat, x: CGFloat, y: CGFloat) {
        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        let attrs: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorFromContextAttributeName: true
        ]
        let attrStr = CFAttributedStringCreate(nil, text as CFString, attrs as CFDictionary)!
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, ctx)
    }

    ctx.setFillColor(gray: 1.0, alpha: 1.0)
    ctx.fill(CGRect(x: 0, y: 0, width: widthDots, height: heightDots))
    ctx.setFillColor(gray: 0.0, alpha: 1.0)
    ctx.setStrokeColor(gray: 0.0, alpha: 1.0)
    ctx.setLineWidth(3)
    ctx.stroke(CGRect(x: 5, y: 5, width: widthDots - 10, height: heightDots - 10))

    drawText("BITMAP LABEL TEST", fontName: "Helvetica-Bold", fontSize: 36, x: 30, y: CGFloat(heightDots - 60))
    drawText("Rendered via CoreGraphics, sent as ^GF", fontName: "Helvetica", fontSize: 20, x: 30, y: CGFloat(heightDots - 95))
    ctx.fill(CGRect(x: 30, y: 80, width: 200, height: 40))
    ctx.fillEllipse(in: CGRect(x: 300, y: 60, width: 80, height: 80))

    for (i, text) in ["\(widthDots)x\(heightDots) dots (\(dpi) DPI)", "4.0 x 2.0 inches", "Host: \(host)"].enumerated() {
        drawText(text, fontName: "Courier", fontSize: 16, x: 30, y: CGFloat(heightDots - 140 - (i * 22)))
    }

    guard let cgImage = ctx.makeImage() else {
        print("Failed to create image")
        exit(1)
    }

    let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
        Graphic(cgImage, at: .dots(0, 0), width: .dots(widthDots), height: .dots(heightDots))
    }
    let zpl = label.render()
    print("Bitmap ZPL size: \(zpl.utf8.count) bytes (\(String(format: "%.1f", Double(zpl.utf8.count) / 1024.0)) KB)")

    let nativeLabel = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
        Box(at: .dots(5, 5), width: .dots(802), height: .dots(396)).thickness(3)
        Text("NATIVE ZPL LABEL TEST", at: .dots(30, 30)).font(.default, height: .dots(36))
        Text("Rendered by printer firmware", at: .dots(30, 80)).font(.default, height: .dots(20))
        Box(at: .dots(30, 130), width: .dots(200), height: .dots(40))
        Circle(at: .dots(300, 130), diameter: .dots(80))
        Text("\(widthDots)x\(heightDots) dots (\(dpi) DPI)", at: .dots(30, 200)).font(.default, height: .dots(16))
        Text("4.0 x 2.0 inches", at: .dots(30, 225)).font(.default, height: .dots(16))
        Text("Host: \(host)", at: .dots(30, 250)).font(.default, height: .dots(16))
    }
    let nativeZpl = nativeLabel.render()
    print("Native ZPL size: \(nativeZpl.utf8.count) bytes")
    print("Bitmap is \(String(format: "%.0f", Double(zpl.utf8.count) / Double(nativeZpl.utf8.count)))x larger")
    print()

    let printer = ZPLPrinter(host: host)

    print("Sending bitmap label to \(host)...")
    do {
        try await printer.send(zpl)
        print("  Bitmap sent")
    } catch {
        print("  Bitmap failed: \(error)")
    }

    if args.count > 2 && args[2] == "both" {
        try await Task.sleep(nanoseconds: 2_000_000_000)

        print("Sending native ZPL label to \(host)...")
        do {
            try await printer.send(nativeZpl)
            print("  Native sent")
        } catch {
            print("  Native failed: \(error)")
        }
    }

    print("\nDone!")

default:
    // Legacy behavior: treat all args as hosts for status
    let hosts = args
    for host in hosts {
        let printer = ZPLPrinter(host: host, timeout: 5)
        print("[\(host)]")

        do {
            let info = try await printer.queryInfo()
            print("  Model: \(info.model)")
            print("  Firmware: \(info.firmwareVersion)")
            print("  DPI: \(info.dpi)")
        } catch {
            print("  Info failed: \(error)")
        }

        do {
            let status = try await printer.queryStatus()
            print("  Ready: \(status.isReadyToPrint)")
            if status.isPaperOut { print("  *** PAPER OUT ***") }
            if status.isHeadOpen { print("  *** HEAD OPEN ***") }
            if status.isRibbonOut { print("  *** RIBBON OUT ***") }
            if status.isPaused { print("  *** PAUSED ***") }
            if status.isHeadTooHot { print("  *** HEAD TOO HOT ***") }
            if status.isReceiveBufferFull { print("  *** BUFFER FULL ***") }
            if status.formatsInBuffer > 0 { print("  Formats in buffer: \(status.formatsInBuffer)") }
            if status.labelsRemainingInBatch > 0 { print("  Labels remaining: \(status.labelsRemainingInBatch)") }
            print("  Label length: \(status.labelLengthInDots) dots")
        } catch {
            print("  Status failed: \(error)")
        }

        do {
            let memory = try await printer.queryMemory()
            print("  Memory: \(memory)")
        } catch {
            print("  Memory failed: \(error)")
        }

        print()
    }
}
