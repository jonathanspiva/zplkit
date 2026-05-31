# Changelog

All notable changes to ZPLKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- `ZPLKitRenderer` now decodes `^GF` binary (`^GFB`), ASCII run-length compression in `^GFA` (repeat-count letters, `,`/`!` row fills, `:` row repeat), and `^GFC` `:B64:`/`:Z64:` (zlib) graphic formats, which were previously dropped.

### Changed
- Adopted Swift 6.2's "approachable concurrency" upcoming-feature flags via a shared `swiftSettings` block applied to every first-party target: `NonisolatedNonsendingByDefault` and `InferIsolatedConformances`. (`InferSendableFromCaptures` is already enabled by default in Swift 6 language mode, so it is intentionally not enabled explicitly.) Default isolation remains `nonisolated`; the package is a library and does not force callers onto the main actor.
- `ZPLVerifier.analyze`/`verify` timing now uses `ContinuousClock`; the reported `*TimeSeconds` fields are documented as wall-clock (including time suspended at `await`).
- Set `swiftLanguageModes: [.v6]` explicitly in the manifest (Swift 6.3 tools-version already defaults to Swift 6 mode; this makes it explicit)
- Raised `swift-tools-version` to 6.3 (Swift 6.3 / Xcode 26.5 toolchain)
- Raised minimum platforms to iOS 26 / macOS 26 / tvOS 26 / watchOS 26
- CI now runs on the `macos-26` runner with Xcode 26 selected explicitly, enforces `-warnings-as-errors`, has per-job timeouts, and treats the external Labelary visual comparison as non-blocking
- Migrated `ZPLVerifier` to the new Swift-native Vision API (`DetectBarcodesRequest`, `RecognizeTextRequest`, `ImageRequestHandler`), replacing the legacy `VN`-prefixed completion-handler API. As a result, `ZPLVerifier.analyze(_:)` and the `verify(...)` overloads are now `async throws`.
- **Removed the `Awesome` dependency** (and the `GraphicsTest` dev tool that used it); the library now has zero external dependencies.
- `ZPLVerifier` now runs barcode and text recognition concurrently (`async let`), roughly halving analysis latency.

### Fixed
- **Fixed a `query()` hang**: a continuation race in `ZPLPrinter` could drop the result on fast connection failure and hang forever; it now always resumes.
- **Fixed crashes reachable from public API**: zero-port force-unwrap in `query()`/`send()`, empty-`Data` `send()` trap, integer divide-by-zero on malformed `^GF` (`bytesPerRow == 0`), and a slice-offset bug in the `~HS`/`~HI`/`~HM` response parsers when given a non-zero-`startIndex` `Data`.
- **Fixed ZPL corruption/injection**: free-form barcode payloads (`Barcode128`, `QRCode`, `PDF417`, `DataMatrix`, `Aztec`) and `render(substituting:)` values are now escaped (`^FH`), so `^`/`~`/`_` in data no longer breaks or injects into the command stream.
- POSIX `send()` now loops on partial writes and retries `EINTR`, validates `fcntl`/`getsockopt` results, honors fractional timeouts and task cancellation.
- `ZPLVerifier` now covers all 24 Vision barcode symbologies (previously dropped `codabar`, GS1 DataBar variants, `microPDF417`, `microQR`, `msiPlessey`), preserves the underlying error, rethrows `CancellationError`, and validates image dimensions.
- Renderer: cache the bundled `CGFont` and reuse one `CIContext` per render pass; reset all `^FB` text-block state between fields; apply rotation to barcode render paths.
- Resolved Swift 6 temporary-pointer warning in `CoreGraphicsRenderer` paragraph-style creation; silenced unused-result `fcntl` warnings in `ZPLPrinter`.
- `ZPLPrinter` now formats POSIX errors with the thread-safe `strerror_r` (the shared `strerror` buffer could race across concurrent `send()` calls).
- Renderer: single-allocation graphic buffer (removed a redundant copy); forward-compatible font-slot selection with documented Font 0 fallback; human-readable placeholder barcode names.
- Removed the deprecated `VerifierError.visionError` case (no consumers); documented the QRCode dual error-correction emission, the barcode `minimumConfidence` no-op, and the `TextExpectation` 3-character hint threshold; replaced a force-unwrapping `PrinterCommand` doc example.

### Internal
- Gated flaky live-network printer tests behind an env var so CI is hermetic by default; added hermetic regression tests for the fixes above.
- Migrated the entire test suite from XCTest to Swift Testing and parameterized the repetitive barcode-validity, clamping, parser-per-command, and verification matrices into `@Test(arguments:)` tables. The package no longer uses XCTest. Coverage was preserved (verified per target); the formerly hidden `SKIP`-prefixed Data Matrix test is now a tracked `@Test(.disabled(...))` skip.

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
