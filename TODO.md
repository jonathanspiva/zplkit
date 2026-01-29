# ZPLKit TODO

## Now
- [ ] Nothing active

## Later
- [ ] **Documentation**
  - [ ] DocC documentation
  - [ ] CHANGELOG.md
- [ ] **Renderer validation**
  - [ ] GitHub Actions workflow for Labelary comparison
  - [ ] Multi-renderer validation (compare ZPLKitRenderer output against Labelary as reference)

## Someday
- [ ] **Open source release**
  - [ ] Tag v1.0.0 release
  - [ ] Make repo public
  - [ ] Submit to Swift Package Index
- [ ] **Printer network commands**
  - [ ] Query printer status (`~HS` host status)
  - [ ] Get configuration (`^HH` configuration return)
  - [ ] Calibrate media (`~JC` calibration)
  - [ ] Reset printer (`~JR` power-on reset)
  - [ ] Save/restore settings (`^JUS`, `^JUR`)
  - [ ] Network configuration (IP, gateway, etc.)
- [ ] Barcode decode verification (scan rendered barcodes to verify encoded data)
- [ ] Icon support via LiveUI/Awesome (FontAwesome 6, native CGImage, 1,500+ icons)

## Never
- Stored formats (`^DF`, `^XF`) - Printer-dependent state; ZPLKit's `{{variable}}` templates solve this better at the application level

## Done
- [x] README badges (Swift version, platforms, CI status)
- [x] Examples/ directory (BasicLabel, ShippingLabel, InventoryTag, PartsBinLabel, ProductLabel)
- [x] Core ZPL elements (Text, TextBlock, Box, Barcode128, QRCode, DataMatrix, Code39)
- [x] Shapes (Box, Circle, Ellipse, HorizontalLine, VerticalLine, DiagonalLine)
- [x] Additional barcodes (PDF417, Interleaved2of5, EAN13, EAN8, UPCA, UPCE, Aztec, IntelligentMail)
- [x] Serial number support (`^SN`)
- [x] Baseline text positioning (`^FT`)
- [x] Label templates with variable substitution (`{{variable}}` syntax)
- [x] TextBlock enhancements (rotation, reverse print, newline support)
- [x] Print speed control (`^PR`)
- [x] Reverse print (`^LRY`)
- [x] Comment support (`^FX`)
- [x] Graphics support (`^GF`)
- [x] ZPLKitRenderer (parser, CoreGraphics engine, barcode rendering, font handling)
- [x] Bundled Roboto Condensed Bold font for Font 0
- [x] README with quick start example
- [x] LICENSE file (MIT)
- [x] GitHub Actions CI workflow (macOS + Linux)
- [x] Visual test harness (Swift-native, replaces npm)
- [x] Labelary comparison tool
- [x] Comprehensive unit testing (268 tests)
