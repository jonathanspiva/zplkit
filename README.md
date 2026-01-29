# ZPLKit

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
[![CI](https://github.com/jonathanspiva/zplkit/actions/workflows/ci.yml/badge.svg)](https://github.com/jonathanspiva/zplkit/actions/workflows/ci.yml)

A Swift library for generating and rendering ZPL (Zebra Programming Language) labels. Build labels with a declarative, type-safe API and preview them instantly without a physical printer.

## Features

### ZPL Generation

- **Declarative API** using Swift result builders
- **Text** with fonts, rotation, reverse print, and baseline positioning
- **Text blocks** with word wrap, alignment, and multi-line support
- **Barcodes**: Code128, Code39, QR, DataMatrix, PDF417, Aztec, EAN-13, EAN-8, UPC-A, UPC-E, Interleaved 2 of 5, Intelligent Mail
- **Shapes**: Box, Circle, Ellipse, Horizontal/Vertical/Diagonal lines
- **Graphics**: Embed images via `^GF` command
- **Templates**: Variable substitution with `{{variable}}` syntax
- **Serial numbers**: Auto-incrementing fields with `^SN`
- **Automatic unit conversion** (inches, mm, dots)
- **Full Swift 6 concurrency support** (`Sendable` types)

### ZPL Rendering

- **Native Swift renderer** with no external dependencies (no Node.js, no npm)
- **Parse ZPL strings** into structured element trees
- **Render to PNG** for instant label previews in your app
- **CoreGraphics engine** for high-quality output
- **CoreImage barcode generation** for QR, Code128, Aztec, PDF417, DataMatrix
- **Mathematical 1D barcode rendering** for Code39, EAN-13, EAN-8, UPC-A, UPC-E, Interleaved 2 of 5
- **Bundled Roboto Condensed Bold font** for accurate Font 0 rendering

## Installation

Add ZPLKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jonathanspiva/ZPLKit.git", from: "1.0.0")
]
```

Then add the product to your target:

```swift
.target(name: "YourTarget", dependencies: ["ZPLKit"])

// For rendering support:
.target(name: "YourTarget", dependencies: ["ZPLKit", "ZPLKitRenderer"])
```

## Quick Start

```swift
import ZPLKit

let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
    Text("PARTS BIN A-7", at: .inches(0.25, 0.25))
        .font(.default, height: .inches(0.2))

    Barcode128("BIN-A7-001", at: .inches(0.25, 0.6))
        .height(.inches(0.5))
        .showText(true)

    Box(at: .inches(0.2, 0.2), width: .inches(3.5), height: .inches(1.2))
        .thickness(2)
}

let zpl = label.render()
// Send `zpl` to your Zebra printer
```

## Elements

### Text

```swift
Text("Hello World", at: .inches(0.5, 0.5))
    .font(.default, height: .dots(30))
    .rotated(.rotated90)
    .reversed()
```

### Text Block (Word Wrap)

```swift
TextBlock("Long text that wraps automatically", at: .inches(0.5, 0.5), width: .inches(2.0))
    .maxLines(3)
    .alignment(.center)
    .lineSpacing(5)
```

### Barcodes

```swift
// 1D Barcodes
Barcode128("ABC123", at: .inches(0.5, 1.0))
    .height(.inches(0.5))
    .showText(true)

Code39("HELLO-123", at: .inches(0.5, 1.5))
    .height(.inches(0.4))

EAN13("5901234123457", at: .inches(0.5, 2.0))
UPCA("012345678905", at: .inches(0.5, 2.5))
Interleaved2of5("1234567890", at: .inches(0.5, 3.0))

// 2D Barcodes
QRCode("https://example.com", at: .inches(0.5, 3.5))
    .magnification(5)
    .errorCorrection(.high)

DataMatrix("SERIAL123", at: .inches(2.0, 3.5))
    .size(5)

PDF417("Encoded data here", at: .inches(0.5, 4.5))
Aztec("More data", at: .inches(2.0, 4.5))
```

### Shapes

```swift
// Box with border
Box(at: .inches(0.25, 0.25), width: .inches(2.0), height: .inches(1.0))
    .thickness(3)
    .cornerRadius(2)

// Filled box
Box(at: .inches(0.25, 0.25), width: .inches(1.0), height: .inches(0.5))
    .filled()

// Circle
Circle(at: .inches(1.0, 1.0), diameter: .inches(0.5))
    .thickness(2)

// Ellipse
Ellipse(at: .inches(1.0, 2.0), width: .inches(1.0), height: .inches(0.5))

// Lines
HorizontalLine(at: .inches(0.5, 1.0), length: .inches(3.0), thickness: 2)
VerticalLine(at: .inches(0.5, 1.0), length: .inches(2.0), thickness: 2)
DiagonalLine(at: .inches(0.5, 1.0), width: .inches(1.0), height: .inches(1.0))
    .direction(.leftToRight)
```

### Graphics

```swift
// From CGImage
if let cgImage = loadImage() {
    Graphic(cgImage, at: .inches(0.5, 0.5))
}

// From raw bitmap data
Graphic(bitmapData: bytes, bytesPerRow: 10, at: .inches(0.5, 0.5))
```

### Serial Numbers

```swift
// Auto-incrementing serial numbers
ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
    Text("SN: ", at: .inches(0.25, 0.25))
    SerialNumber("001", at: .inches(0.6, 0.25))
        .increment(1)
        .padWithZeros(true)
}
.printQuantity(10)  // Prints SN: 001, 002, 003... 010
```

### Comments

```swift
Comment("This section is for the header")
Text("Header Text", at: .inches(0.25, 0.25))
```

## Templates

Create reusable label templates with variable substitution:

```swift
let template = ZPLTemplate(width: 4, height: 2, dpi: .dpi203) {
    Text("{{product_name}}", at: .inches(0.25, 0.25))
        .font(.default, height: .inches(0.15))
    Barcode128("{{sku}}", at: .inches(0.25, 0.5))
        .height(.inches(0.4))
    Text("${{price}}", at: .inches(0.25, 1.1))
}

let zpl = template.render(with: [
    "product_name": "Widget Pro",
    "sku": "WGT-PRO-001",
    "price": "29.99"
])
```

## Units

Position and dimensions support three unit types:

```swift
.dots(100, 200)    // Printer native resolution
.inches(0.5, 1.0)  // Converted based on DPI
.mm(12.7, 25.4)    // Millimeters
```

Integer literals default to dots:

```swift
Box(at: .inches(0.5, 0.5), width: 200, height: 100)  // width/height in dots
```

## Label Configuration

```swift
let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
    // elements
}
.printQuantity(5)
.defaultFont(.default, height: 30)
.printDarkness(15)
.printSpeed(4)
.labelHome(x: 10, y: 10)
.reversePrint(true)  // White on black
```

## Rendering Previews

ZPLKitRenderer lets you preview labels without a physical printer. Generate PNG images for display in your app, or use the parser to inspect ZPL structure.

```swift
import ZPLKitRenderer

// Render ZPL to PNG
let renderer = ZPLRenderer()
let zpl = label.render()  // From ZPLKit

if let pngData = try? renderer.renderToPNG(zpl, width: 812, height: 1218) {
    // Display in UIImageView, save to file, etc.
}

// Or parse ZPL to inspect elements
let parsed = try ZPLParser.parse(zpl)
print("Label size: \(parsed.width) x \(parsed.height) dots")
print("Elements: \(parsed.elements.count)")
```

The renderer handles all ZPL commands that ZPLKit generates, including text, barcodes, shapes, and graphics.

## Supported DPI

| DPI | Dots per mm | Use case |
|-----|-------------|----------|
| `.dpi152` | 6 dpmm | Economy printers |
| `.dpi203` | 8 dpmm | Most common, standard |
| `.dpi300` | 12 dpmm | High quality |
| `.dpi600` | 24 dpmm | Ultra high resolution |

## Requirements

- Swift 6.0+
- iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+

## ZPL Command Coverage

ZPLKit supports the most commonly used ZPL II commands for label design:

| Category | Commands |
|----------|----------|
| **Label Format** | `^XA` `^XZ` `^PW` `^LL` `^LH` `^LRY` |
| **Text & Fonts** | `^A` `^CF` `^FD` `^FS` `^FB` `^FH` `^FR` `^FT` |
| **1D Barcodes** | `^BC` `^B3` `^BE` `^B8` `^BU` `^B9` `^B2` `^BZ` `^BY` |
| **2D Barcodes** | `^BQ` `^BX` `^B7` `^B0` |
| **Shapes** | `^GB` `^GC` `^GE` `^GD` |
| **Graphics** | `^GF` |
| **Print Control** | `^PQ` `^MD` `^PR` |
| **Fields** | `^FO` `^SN` `^FX` |

The renderer (ZPLKitRenderer) parses and renders all commands that ZPLKit generates.

**Not covered:** RFID commands, printer configuration/calibration, stored formats, network settings, and some uncommon barcodes (Codabar, Postnet, Planet Code). These are either printer-management functions or legacy formats rarely needed in modern label design.

## Resources

- [Zebra ZPL Programming Guide](https://www.zebra.com/content/dam/zebra/manuals/printers/common/programming/zpl-zbi2-pm-en.pdf) - Official ZPL command reference
- [Labelary](http://labelary.com/viewer.html) - Online ZPL viewer for testing
- [zpl-image](https://www.npmjs.com/package/zpl-image) - Node.js ZPL renderer that inspired ZPLKitRenderer

## License

MIT
