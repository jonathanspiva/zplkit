# ZPLKit

<img src="logo.svg" width="128" height="128" alt="ZPLKit logo">

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
[![CI](https://github.com/jonathanspiva/zplkit/actions/workflows/ci.yml/badge.svg)](https://github.com/jonathanspiva/zplkit/actions/workflows/ci.yml)

A Swift library for generating and rendering ZPL (Zebra Programming Language) labels. Build labels with a declarative, type-safe API and preview them instantly without a physical printer.

## Features

### ZPLKit (Generation)

- **Declarative API** using Swift result builders
- **Text** with fonts, rotation, reverse print, and baseline positioning
- **Barcodes**: Code128, Code39, QR, DataMatrix, PDF417, Aztec, EAN-13, EAN-8, UPC-A, UPC-E, Interleaved 2 of 5
- **Shapes**: Box, Circle, Ellipse, Horizontal/Vertical/Diagonal lines
- **Graphics**, templates, serial numbers, printer commands
- **Full Swift 6 concurrency support** (`Sendable` types)

### ZPLKitRenderer (Previews)

- **Native Swift renderer** with no external dependencies
- **Parse ZPL strings** into structured element trees
- **Render to PNG** for instant label previews
- **Bundled Roboto Condensed Bold font** for accurate Font 0 rendering

### ZPLKitPrinter (Network Printing)

- **Send ZPL to printers** over TCP (port 9100)
- **Bonjour discovery** to find printers on the local network
- **Async/await API** with configurable timeout

### ZPLVerifier (Validation)

- **Barcode verification** using Vision framework
- **Text OCR** to verify label content

### Test Fixtures

- **114 ZPL files** covering text, barcodes, shapes, and graphics
- **Reusable test suite** for validating any ZPL parser or renderer
- **Reference images** from Labelary for comparison

## Installation

Add ZPLKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jonathanspiva/ZPLKit.git", from: "1.0.0")
]
```

Then add the products to your target:

```swift
.target(name: "YourTarget", dependencies: ["ZPLKit"])

// For rendering support:
.target(name: "YourTarget", dependencies: ["ZPLKit", "ZPLKitRenderer"])

// For network printing:
.target(name: "YourTarget", dependencies: ["ZPLKit", "ZPLKitPrinter"])
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

## Rendering Previews

```swift
import ZPLKitRenderer

let renderer = ZPLRenderer()
if let pngData = try? renderer.renderToPNG(zpl, width: 812, height: 1218) {
    // Display in UIImageView, save to file, etc.
}
```

## Printing

```swift
import ZPLKitPrinter

// Send to a known printer
let printer = ZPLPrinter(host: "192.168.1.100")
try await printer.send(label.render())

// Or discover printers on the network
let browser = ZPLPrinterBrowser()
for await discovered in browser.printers {
    try await ZPLPrinter.send(zpl, to: discovered)
    break
}
```

## Documentation

- **[Getting Started](Sources/ZPLKit/Documentation.docc/Articles/GettingStarted.md)** - Full API reference with examples for all elements
- **[Test Fixtures](Sources/ZPLKit/Documentation.docc/Articles/Fixtures.md)** - 114 ZPL files for testing parsers and renderers

## Requirements

- Swift 6.0+
- iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+

## Resources

- [Zebra ZPL Programming Guide](https://www.zebra.com/content/dam/zebra/manuals/printers/common/programming/zpl-zbi2-pm-en.pdf)
- [Labelary](http://labelary.com/viewer.html) - Online ZPL viewer

## License

MIT
