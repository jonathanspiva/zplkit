# ZPLKit TODO

## Now
- [ ] Nothing active

## Later
- [ ] Nothing planned

## Someday
- [ ] **Open source release**
  - [ ] CHANGELOG.md
  - [ ] Tag v1.0.0 release
  - [ ] Make repo public
  - [ ] Submit to Swift Package Index
- [ ] **Printer commands (one-way, fire and forget)**
  - [ ] Print network config (`~WL`)
  - [ ] Calibrate media (`~JC`)
  - [ ] Reset printer (`~JR`)
  - [ ] Cancel current job (`~JA`)
- [ ] Barcode decode verification (scan rendered barcodes to verify encoded data)
- [ ] Icon support via LiveUI/Awesome (FontAwesome 6, native CGImage, 1,500+ icons)

## Never
- Stored formats (`^DF`, `^XF`) - Printer-dependent state; ZPLKit's `{{variable}}` templates solve this better at the application level
- Two-way printer commands (`~HS`, `^HH`) - Require response parsing and network client, out of scope for a generation/rendering library

## Done
- [x] Fixture metadata JSON with descriptions, categories, features, size, DPI
- [x] ^FX DESCRIPTION comments in all 114 ZPL fixtures
- [x] HTML comparison with filtering (category chips, size/DPI dropdowns, text search)
- [x] Curated reference images (ZPLKitRenderer for ^FR cases where Labelary is wrong)
- [x] Renderer validation (scoring, diff images, reference comparison)
- [x] ZPL test fixtures documented in README as reusable resource
- [x] DocC documentation (ZPLLabel, types, core elements)
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
- [x] GitHub Actions CI workflow (macOS, with artifact uploads)
- [x] Visual test harness (Swift-native, replaces npm)
- [x] Labelary comparison in CI (retry logic, graceful failure handling)
- [x] Renderer accuracy scoring (90.5% baseline, reference images committed)
- [x] Comprehensive unit testing (268 tests)
