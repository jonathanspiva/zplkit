# ZPLKit TODO

## Now

### ZPLKitPrinter: Two-way printer communication
Extend ZPLKitPrinter module (already has TCP send and Bonjour discovery) with response handling using ZPL control commands. These work on all Zebra printers including older models like the ZM400.

#### Concerns and Considerations
- **~HS silent on errors**: Printer will NOT respond to ~HS if in MEDIA OUT, RIBBON OUT, HEAD OPEN, REWINDER FULL, or HEAD OVER-TEMP state. Must treat timeout as potential error condition, not just network failure.
- **Response framing**: Each response string starts with STX (0x02), ends with ETX CR LF (0x03 0x0D 0x0A). ~HS returns 3 strings; must buffer and parse all three.
- **Interlocking risk**: Sending ZPL then immediately querying status on same connection can interlock. Options: (a) close connection between operations, (b) use separate connections, (c) Link-OS printers have port 9200 for status (but ZM400 doesn't fully support this).
- **Port 9200 status channel**: Link-OS feature for JSON-based status queries. ZM400 has "limited admin features" so stick with port 9100 + ZPL control commands.
- **Alternative command**: `~HQES` (Host Query ES) may provide more reliable status on some printers. Worth investigating as fallback.
- **Binary response fields**: Some ~HS fields are "three-digit decimal representation of eight-bit binary number" requiring bit parsing.

#### Foundation
- [x] **Bidirectional connection support**
  - Added `QueryState` actor to track send + receive states with response buffering
  - New `query(_ command:responseTimeout:)` method keeps connection open for response
  - Recursive `receiveResponse` collects data until ETX detected or timeout
  - Separate timeouts: connection timeout vs response timeout
  - Static convenience: `ZPLPrinter.query(_:from:timeout:responseTimeout:)`
- [x] **Response parsing infrastructure**
  - Detects ETX (0x03) + CR LF framing for ZPL control responses
  - New error cases: `receiveFailed`, `responseTimeout`, `invalidResponse`
  - `responseTimeout` error description notes printer may be in error state

#### ZPL Control Commands
- [x] **Printer status** (`~HS` Host Status)
  - `PrinterStatus` struct with all fields (Sendable, Equatable, Codable, CustomStringConvertible)
  - Fields: isPaperOut, isRibbonOut, isHeadOpen, isHeadTooHot, isHeadCold, isPaused, isReceiveBufferFull, isPartialFormatInProgress, formatsInBuffer, labelsRemainingInBatch, labelLengthInDots
  - Computed: `isReadyToPrint`, `hasError`
  - Parser handles STX/ETX framing and comma-separated fields
  - `ZPLPrinter.queryStatus()` convenience method
- [x] **Printer identification** (`~HI` Host Identification)
  - `PrinterInfo` struct (Sendable, Equatable, Codable, CustomStringConvertible)
  - Fields: model, firmwareVersion, dotsPerMillimeter, memoryKB, options
  - Computed: `dpi` (from dpm), `memoryFormatted` (KB/MB)
  - Parser handles STX/ETX framing with fallback for unframed responses
  - `ZPLPrinter.queryInfo()` convenience method
- [ ] **Head diagnostic** (`~HM`)
  - Head temperature, printhead status
- [ ] **Test page commands** (fire-and-forget, no response)
  - `~JC` - Print configuration label
  - `~WC` - Print network configuration label

## Later
- [ ] Nothing planned

## Someday
- [ ] **SGD (Set-Get-Do) commands** - Modern Link-OS protocol for newer printers
  - `! U1 getvar/setvar/do` syntax, more granular than ZPL control commands
  - `odometer.total_label_count` for precise print verification (count before/after)
  - `device.*` namespace for identification, `odometer.*` for maintenance info
  - Full support on Link-OS printers; reduced set on older printers (ZM400 era)
- [ ] **Public barcode generation API** - Expose barcode encoding as a module
  - Most encoders already implemented internally (Code128, Code39, EAN-13/8, UPC-A/E, I2of5)
  - QR, Aztec, PDF417 use CoreImage (available on Apple platforms)
  - [ ] Data Matrix encoder (CoreImage doesn't support it, needs mathematical implementation)
  - [ ] Intelligent Mail encoder (uses placeholder currently)
- [ ] **Open source release**
  - [ ] CHANGELOG.md
  - [ ] CONTRIBUTING.md (code style, PR process, development setup)
  - [ ] GitHub repo description and topics (swift, zpl, zebra, label-printing, barcode)
  - [ ] Issue templates (bug report, feature request)
  - [ ] Verify `swift package dump-package` outputs valid JSON
  - [ ] .spi.yml with documentation_targets for DocC hosting on Swift Package Index
  - [ ] Tag v1.0.0 release
  - [ ] Make repo public
  - [ ] Add package to Swift Package Index (PR to SwiftPackageIndex/PackageList)
  - [ ] Update README badges to use Swift Package Index badges

## Never
- Stored formats (`^DF`, `^XF`) - Printer-dependent state; ZPLKit's `{{variable}}` templates solve this better at the application level
- SF Symbols icon support - Apple licensing prohibits redistribution and use in printed materials; FontAwesome is the supported alternative
- Snapshot tests (pixel-perfect PNG comparison) - ZPLVerifier already validates barcodes scan correctly; snapshot tests are brittle across macOS versions, CI environments, and architectures; thermal printers are forgiving of minor rendering differences

## Done
- [x] **ZPLKitPrinter module** - Network printing and discovery
  - ZPLPrinter: Send ZPL via TCP (async/await, configurable timeout)
  - ZPLPrinterBrowser: Bonjour discovery (`_pdl-datastream._tcp`)
  - DiscoveredPrinter: Name, host, port, metadata from mDNS
  - Uses Network.framework (NWConnection, NWBrowser)
- [x] **Swift best practice conformances** - Protocol conformances across all public types
  - Codable: All types serializable to JSON/plist (DPI, Dimension, Position, DetectedBarcode, etc.)
  - Equatable/Hashable: All 22 element types and verification types
  - @frozen: 8 stable enums (DPI, Rotation, ZPLFont, BarcodeSymbology, etc.)
  - CustomStringConvertible: Better debug output for key types
- [x] **Parser refactoring** - Split ZPLParser.swift (611 lines) into focused sub-modules
  - BarcodeParser, ShapeParser, TextParser, GraphicParser
  - Added stability warnings to Parsed* types
- [x] **Richer error handling** - Specific VerifierError cases
  - barcodeDetectionFailed, textRecognitionFailed with underlying message
  - Deprecated generic visionError
- [x] **Documentation split** - README reduced from 328 to 86 lines
  - DocC articles: GettingStarted.md (full API reference), Fixtures.md (test fixture guide)
  - Module-level documentation in Documentation.docc/
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
