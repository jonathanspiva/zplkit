import Foundation
import ZPLKit
import ZPLKitPrinter

// BarcodePrintTest
// ----------------
// Prints one sample of every ZPLKit barcode symbology to a physical Zebra
// printer, so the real thermal output can be eyeballed and scanned. Each label
// carries a short UUID + timestamp footer so a physical label can be traced back
// to a line in the send log (same convention as GraphicPrintTest).
//
// Usage:
//   swift run BarcodePrintTest [--type <name>] [--calibrate] [--help] <host>
//
//   --type <name>   Print only this symbology (see the list below).
//   --calibrate     Run media calibration (~JC) before printing.
//   --help          Show this help.
//
//   Host: positional arg, else $ZPLTOOL_ZM400_HOST, else 192.168.1.100.
//
// Symbologies: code128 code39 i2of5 imb ean13 ean8 upca upce qr datamatrix
//              pdf417 aztec

let W = 812     // 4 inches at 203 DPI
let H = 406     // 2 inches at 203 DPI
let inset = 20  // keep content off the edge / gap-sensor track
let col2 = 420  // x of the right-hand column

// MARK: - Args

let rawArgs = Array(CommandLine.arguments.dropFirst())
if rawArgs.contains("--help") {
    print("""
    Usage: swift run BarcodePrintTest [--type <name>] [--calibrate] [--help] <host>

    Prints a visual test pass: one sample of every ZPLKit barcode symbology to a
    physical Zebra printer. Each label carries a short ID + timestamp footer for
    traceability. Data is fixed, valid sample data per symbology.

    Options:
      --type <name>   Print only this symbology (e.g. code128, qr, pdf417).
      --calibrate     Run media calibration (~JC) before printing.
      --help          Show this help.

    Host: positional arg, else $ZPLTOOL_ZM400_HOST, else 192.168.1.100.

    Symbologies: code128 code39 i2of5 imb ean13 ean8 upca upce qr datamatrix
                 pdf417 aztec
    """)
    exit(0)
}

var hostArg: String?
var onlyType: String?
var doCalibrate = false
var argIter = rawArgs.makeIterator()
while let arg = argIter.next() {
    switch arg {
    case "--calibrate": doCalibrate = true
    case "--type": onlyType = argIter.next()?.lowercased()
    default: if !arg.hasPrefix("--") { hostArg = arg }
    }
}
let host = hostArg
    ?? ProcessInfo.processInfo.environment["ZPLTOOL_ZM400_HOST"]
    ?? "192.168.1.100"

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

func title(_ text: String, _ x: Int) -> Text {
    Text(text, at: .dots(x, inset + 4)).font(.default, height: .dots(22))
}

/// Renders `label`, logs a traceable line, sends it, and pauses briefly.
func send(_ name: String, _ label: ZPLLabel, id: String, ts: String) async throws {
    let zpl = label.render()
    print("SENT \(name)  id=\(id)  ts=\(ts)  bytes=\(zpl.utf8.count)  host=\(host)")
    try await printer.send(zpl)
    try await Task.sleep(nanoseconds: 2_000_000_000)
}

// MARK: - Symbology specs

let barcodeY = inset + 40
let barHeight = Dimension.dots(110)

/// One symbology: its short name and a builder that lays out a titled sample in
/// the column starting at `x`. Failable initializers fall back to an error label
/// so a bad sample is visible on the print rather than silently dropped.
struct Spec {
    let name: String
    let make: (_ x: Int) -> [ZPLElement]
}

func failable(_ name: String, _ x: Int, _ element: ZPLElement?) -> [ZPLElement] {
    if let element {
        return [title(name, x), element]
    }
    return [title(name, x), Text("ERR: \(name)", at: .dots(x, barcodeY)).font(.default, height: .dots(20))]
}

let specs: [Spec] = [
    Spec(name: "code128") { x in
        failable("Code128", x, Barcode128("ZPLKIT128", at: .dots(x, barcodeY))?.height(barHeight).moduleWidth(2))
    },
    Spec(name: "code39") { x in
        failable("Code39", x, Code39("CODE39", at: .dots(x, barcodeY))?.height(barHeight))
    },
    Spec(name: "i2of5") { x in
        failable("I2of5", x, Interleaved2of5("12345678", at: .dots(x, barcodeY))?.height(barHeight))
    },
    Spec(name: "imb") { x in
        failable("USPS IMb", x, IntelligentMail("01234567094987654321", at: .dots(x, barcodeY))?.height(barHeight))
    },
    Spec(name: "ean13") { x in
        failable("EAN-13", x, EAN13("978020137962", at: .dots(x, barcodeY))?.height(barHeight))
    },
    Spec(name: "ean8") { x in
        failable("EAN-8", x, EAN8("9638507", at: .dots(x, barcodeY))?.height(barHeight))
    },
    Spec(name: "upca") { x in
        failable("UPC-A", x, UPCA("01234567890", at: .dots(x, barcodeY))?.height(barHeight))
    },
    Spec(name: "upce") { x in
        failable("UPC-E", x, UPCE("012345", at: .dots(x, barcodeY))?.height(barHeight))
    },
    Spec(name: "qr") { x in
        [title("QR", x), QRCode("https://github.com/jonathanspiva/zplkit", at: .dots(x, barcodeY)).magnification(4)]
    },
    Spec(name: "datamatrix") { x in
        [title("DataMatrix", x), DataMatrix("DATAMATRIX-TEST", at: .dots(x, barcodeY)).moduleSize(6)]
    },
    Spec(name: "pdf417") { x in
        [title("PDF417", x), PDF417("PDF417 TEST 12345", at: .dots(x, barcodeY))]
    },
    Spec(name: "aztec") { x in
        [title("Aztec", x), Aztec("AZTEC-TEST-123", at: .dots(x, barcodeY)).magnification(4)]
    },
]

// MARK: - Run

let selected = onlyType.map { t in specs.filter { $0.name == t } } ?? specs
guard !selected.isEmpty else {
    print("Unknown --type '\(onlyType ?? "")'. Run with --help for the list."); exit(1)
}

// Two symbologies per label (or one when a single --type is chosen).
var pages: [[Spec]] = []
var index = 0
while index < selected.count {
    pages.append(Array(selected[index..<min(index + 2, selected.count)]))
    index += 2
}

if doCalibrate {
    print("Calibrating \(host) (~JC) ...")
    try await printer.calibrate()
    try await Task.sleep(nanoseconds: 3_000_000_000)
}

print("Printing \(selected.count) symbolog(y/ies) across \(pages.count) label(s) to \(host)")
for (pageIndex, cols) in pages.enumerated() {
    let (id, ts) = idStamp()
    let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
        for (columnIndex, spec) in cols.enumerated() {
            let x = columnIndex == 0 ? inset : col2
            for element in spec.make(x) { element }
        }
        footer(id, ts)
        Text("\(pageIndex + 1)/\(pages.count)", at: .dots(W - 90, H - 40)).font(.default, height: .dots(18))
    }
    try await send(cols.map { $0.name }.joined(separator: "+"), label, id: id, ts: ts)
}
print("Done. \(pages.count) label(s) sent.")
