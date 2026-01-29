# ZPLKit

A Swift library for generating ZPL (Zebra Programming Language) code.

## Features

- Simple, declarative API using Swift result builders
- Support for text, barcodes (Code128, QR, Code39, DataMatrix), and shapes
- Automatic unit conversion (inches, mm, dots)
- Special character escaping
- Zero external dependencies
- Full Swift 6 concurrency support (`Sendable` types)

## Installation

Add ZPLKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jonathanspiva/ZPLKit.git", from: "1.0.0")
]
```

## Quick Start

```swift
import ZPLKit

let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
    Text("M6 Titanium Bolt", at: .inches(0.25, 0.25))
        .font(.default, height: .inches(0.15))

    Barcode128("M6-TI-001", at: .inches(0.25, 0.75))
        .height(.inches(0.5))

    Box(at: .inches(0.2, 0.2), width: .inches(1.5), height: .inches(1.4))
        .thickness(2)
}

let zpl = label.render()
// Send `zpl` string to your Zebra printer
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
TextBlock("Long text that wraps", at: .inches(0.5, 0.5), width: .inches(2.0))
    .maxLines(3)
    .alignment(.center)
```

### Barcodes

```swift
// Code 128
Barcode128("ABC123", at: .inches(0.5, 1.0))
    .height(.inches(0.5))
    .showText(true)

// QR Code
QRCode("https://example.com", at: .inches(0.5, 2.0))
    .magnification(5)
    .errorCorrection(.high)

// Code 39
Code39("HELLO-123", at: .inches(0.5, 3.0))
    .height(.inches(0.4))

// DataMatrix
DataMatrix("SERIAL123", at: .inches(0.5, 4.0))
    .size(5)
```

### Shapes

```swift
// Box
Box(at: .inches(0.25, 0.25), width: .inches(2.0), height: .inches(1.0))
    .thickness(3)
    .cornerRadius(2)

// Filled box
Box(at: .inches(0.25, 0.25), width: .inches(1.0), height: .inches(0.5))
    .filled()

// Lines
HorizontalLine(at: .inches(0.5, 1.0), length: .inches(3.0), thickness: 2)
VerticalLine(at: .inches(0.5, 1.0), length: .inches(2.0), thickness: 2)
```

## Units

Position and dimensions support three unit types:

```swift
// Dots (printer native)
Text("Hello", at: .dots(100, 200))

// Inches (converted at render time based on DPI)
Text("Hello", at: .inches(0.5, 1.0))

// Millimeters
Text("Hello", at: .mm(12.7, 25.4))
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
```

## Supported DPI

- `.dpi152` (6 dpmm)
- `.dpi203` (8 dpmm, most common)
- `.dpi300` (12 dpmm)
- `.dpi600` (24 dpmm)

## Requirements

- Swift 6.0+
- iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+

## License

MIT
