# ZPLKit TODO

## Now
- [ ] Nothing active

## Later
- [ ] **Open source prep**
  - [x] Add LICENSE file (MIT)
  - [ ] Tag v1.0.0 release
  - [ ] Make repo public
  - [ ] Submit to Swift Package Index
  - [ ] Add badges to README (Swift version, platforms, CI status)
- [ ] GitHub Actions workflow for Labelary comparison (validates both ZPL output and renderer)
- [ ] ZPLKitRenderer: Multi-renderer validation (compare ZPLKitRenderer output against Labelary as reference)
- [ ] ZPLKitRenderer: Swift-native test harness (replaces npm for local testing)
- [ ] Stored formats (`^DF`, `^XF`)
- [ ] DocC documentation
- [ ] CHANGELOG.md

## Someday
- [ ] Graphics/images (`^GF`, `~DG`) via separate ZPLKitGraphics package
- [ ] Barcode decode verification - scan rendered barcodes to verify encoded data

## Never

## Done

### v1.0 Scope
- [x] Core ZPL elements (Text, TextBlock, Box, Barcode128, QRCode, DataMatrix, Code39)
- [x] Shapes (Box, HorizontalLine, VerticalLine)
- [x] README with quick start example
- [x] GitHub Actions CI workflow (build/test on macOS + Linux)
- [x] Visual test harness with zpl-renderer-js

### v2.0 Scope
- [x] Additional shapes (Circle, Ellipse, DiagonalLine)
- [x] Additional barcodes (PDF417, Interleaved2of5, EAN13, UPCA, Aztec)
- [x] Serial number support (`^SN`)
- [x] Baseline text positioning (`^FT`)
- [x] Labelary comparison tool for renderer validation
- [x] Additional barcodes (EAN8, UPCE, IntelligentMail)
- [x] **ZPLKitRenderer** - Native Swift ZPL renderer for label previews
  - [x] ZPL parser (parse ZPL strings into element tree)
  - [x] CoreGraphics rendering engine (Apple platforms only)
  - [x] Font handling: configurable mapping, defaults to system fonts (Helvetica for Font 0)
  - [x] Barcode rendering (CoreImage: QR, Code128, Aztec, PDF417, DataMatrix; 1D math: Code39, EAN-13, EAN-8, UPC-A, UPC-E, I2of5)
  - [x] Performance instrumentation: benchmark parse/render times
- [x] Label templates with variable substitution (`{{variable}}` syntax)
- [x] TextBlock enhancements (rotation, reverse print, newline support)
- [x] Print speed control (`^PR`)
