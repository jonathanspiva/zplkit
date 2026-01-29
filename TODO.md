# ZPLKit TODO

## Now
- [ ] Nothing active

## Later

## Someday
- [ ] Data Matrix renderer (CoreImage doesn't support it, needs mathematical implementation)
- [ ] Intelligent Mail renderer (also uses placeholder currently)
- [ ] **Open source release**
  - [ ] CHANGELOG.md
  - [ ] Tag v1.0.0 release
  - [ ] Make repo public
  - [ ] Submit to Swift Package Index

## Never
- Stored formats (`^DF`, `^XF`) - Printer-dependent state; ZPLKit's `{{variable}}` templates solve this better at the application level
- Two-way printer commands (`~HS`, `^HH`) - Require response parsing and network client, out of scope for a generation/rendering library
- SF Symbols icon support - Apple licensing prohibits redistribution and use in printed materials; FontAwesome is the supported alternative

## Done
- [x] **FontAwesome icon support** - Replaced SF Symbols with LiveUI/Awesome library
  - SF Symbols licensing prohibits redistribution and printed materials
  - FontAwesome 6 Free: 1,500+ icons as native CGImages
  - CC BY 4.0 / OFL / MIT licensed (safe for printed labels)
  - All 36 graphic fixtures regenerated and verified
- [x] **EAN/UPC barcode rendering fix** - All EAN/UPC barcodes now scannable
  - Added check digit calculation for EAN-13, EAN-8, UPC-A
  - Fixed UPC-E parity patterns (was using all L-codes, now proper O/E pattern)
  - Added quiet zones (9-module margins) for all EAN/UPC types
  - Verification improved from 76% to 89%
- [x] **ZPLVerifier public API** - Verification framework for rendered labels
  - [x] Barcode detection via Vision framework (Code128, QR, Code39, EAN-13, Aztec, PDF417, etc.)
  - [x] Text OCR via `VNRecognizeTextRequest`
  - [x] Bounds/clipping detection for edge content
  - [x] Discovery mode (analyze) and assertion mode (verify)
  - [x] Declarative DSL with `Barcode(...)` and `Text(...)` expectations
  - [x] Vision hints optimization for faster detection
  - [x] 37 unit and integration tests
  - [x] Visual test harness integration with verification and discovery display
  - [x] fixtures.json populated with expectedBarcodes for 54 barcode fixtures
- [x] Fixture metadata JSON with descriptions, categories, features, size, DPI
- [x] ^FX DESCRIPTION comments in all 114 ZPL fixtures
- [x] HTML comparison with filtering (category chips, size/DPI dropdowns, text search)
- [x] Curated reference images (ZPLKitRenderer for ^FR cases where Labelary is wrong)
- [x] Renderer validation (scoring, diff images, reference comparison)
- [x] ZPL test fixtures documented in README as reusable resource
- [x] Printer commands: PrinterCommand enum (~WL, ~JC, ~JR, ~JA)
- [x] Barcode decode verification (Vision framework, 8 barcode types verified)
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
- [x] Comprehensive unit testing (280 tests)
