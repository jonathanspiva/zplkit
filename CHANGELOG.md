# Changelog

All notable changes to ZPLKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2025-02-01

Initial public release.

### Added

#### ZPLKit (Label Generation)
- Declarative Swift API using result builders for building ZPL labels
- **Text elements**: `Text`, `TextBlock` with fonts, rotation, reverse print, baseline positioning
- **1D Barcodes**: `Barcode128`, `Code39`, `EAN13`, `EAN8`, `UPCA`, `UPCE`, `Interleaved2of5`
- **2D Barcodes**: `QRCode`, `DataMatrix`, `PDF417`, `Aztec`, `IntelligentMail`
- **Shapes**: `Box`, `Circle`, `Ellipse`, `HorizontalLine`, `VerticalLine`, `DiagonalLine`
- **Graphics**: `Graphic` element for embedding CGImage content
- **Utilities**: `Comment`, `SerialNumber` for label metadata and sequential numbering
- **Label configuration**: print quantity, print speed, darkness, reverse print, label home
- **Template substitution**: `{{variable}}` syntax for dynamic label content
- **Printer commands**: `PrinterCommand` enum for `~WL`, `~JC`, `~JR`, `~JA`
- **Type system**: `DPI`, `Dimension`, `Position`, `Rotation`, `ZPLFont` types
- Full Swift 6 concurrency support with `Sendable` conformance on all types
- Protocol conformances: `Codable`, `Equatable`, `Hashable`, `CustomStringConvertible`

#### ZPLKitRenderer (Parsing & Rendering)
- Native Swift ZPL parser supporting all major commands
- CoreGraphics-based rendering engine for PNG output
- Bundled Roboto Condensed Bold font for accurate Font 0 rendering
- Barcode rendering: Code128, Code39, EAN-13/8, UPC-A/E, Interleaved 2 of 5, QR, Aztec, PDF417
- Parser sub-modules: `BarcodeParser`, `ShapeParser`, `TextParser`, `GraphicParser`
- Hex character decoding (`^FH` with `_XX` sequences)
- Render metrics: parse time, render time, image dimensions

#### ZPLKitPrinter (Network Printing)
- `ZPLPrinter`: Send ZPL to printers via TCP (port 9100)
- `ZPLPrinterBrowser`: Bonjour/mDNS discovery (`_pdl-datastream._tcp`)
- `DiscoveredPrinter`: Printer metadata from network discovery
- **Two-way communication**: `query()` method for bidirectional printer queries
- **Status queries**: `queryStatus()` for `~HS` (Host Status) response parsing
- **Printer info**: `queryInfo()` for `~HI` (Host Identification) response parsing
- **Memory status**: `queryMemory()` for `~HM` (Host Memory) response parsing
- **Test pages**: `printConfigurationLabel()`, `printNetworkConfigLabel()`
- Structured response types: `PrinterStatus`, `PrinterInfo`, `MemoryStatus`
- Async/await API with configurable connection and response timeouts

#### ZPLVerifier (Label Verification)
- Barcode detection via Vision framework (Code128, QR, Code39, EAN-13, Aztec, PDF417, etc.)
- Text OCR via `VNRecognizeTextRequest`
- **Discovery mode**: `analyze()` to discover all barcodes and text in an image
- **Assertion mode**: `verify()` with declarative expectations DSL
- Expectation types: `Barcode(symbology, exactly/containing)`, `Text(exactly/containing)`
- Vision hints optimization for faster detection
- Bounds/clipping detection for edge content
- Result types: `AnalysisResult`, `VerificationResult`, `DetectedBarcode`, `DetectedText`

#### Test Fixtures
- 114 ZPL fixture files covering text, barcodes, shapes, and graphics
- `fixtures.json` metadata with descriptions, categories, features, expected barcodes
- Reference images from Labelary for comparison
- Visual test harness with HTML comparison output
- Renderer accuracy scoring (90.5% baseline vs Labelary)

#### Documentation
- DocC documentation for all public types
- Getting Started guide with full API reference
- Test Fixtures guide for parser/renderer validation
- README with quick start examples

#### Quality
- 374 unit and integration tests
- GitHub Actions CI with visual comparison artifacts
- MIT license

### Notes

- **Data Matrix**: Uses placeholder rendering (CoreImage lacks Data Matrix generator)
- **Intelligent Mail**: Uses placeholder rendering (encoder not yet implemented)
- **Font support**: Only Font 0 (Roboto Condensed Bold) is bundled; other fonts render as Font 0

[Unreleased]: https://github.com/jonathanspiva/zplkit/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jonathanspiva/zplkit/releases/tag/v1.0.0
