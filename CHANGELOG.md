# Changelog

All notable changes to ZPLKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Breaking changes
- `ZPLKitVerifier`'s expectation types were renamed `Text` → `TextExpectation` and
  `Barcode` → `BarcodeExpectation`, so `Text` no longer collides with `ZPLKit.Text`
  when both modules are imported for the build → render → verify workflow.
- Removed the inert `dpi:` parameter from `ZPLRenderer.render(_:)` and
  `renderToPNG(_:)`. Output dimensions are derived from the label's `^PW`/`^LL`
  dot values, so the parameter never had any effect.
- `PrinterConfiguration.fieldRotation` is now a typed `FieldRotation` enum
  (`.normal`/`.rotate90`/`.rotate180`/`.rotate270`) instead of a `String`, matching
  the other typed configuration fields.

### Changed
- `ParsedLabel` / `ParsedElement` and the other `Parsed*` types are now documented
  as part of the public, semver-stable API (the "may change without notice"
  disclaimer is gone); `ParsedElement` may still gain cases in minor releases.
- `BarcodeSymbology` is no longer `@frozen`, so future Vision symbologies can be
  added without a source break (switch over it with a `default` case).
- `PrinterConfiguration.networkConfig(...)` / `dhcp()` (the `^NS` path) are now
  documented as **experimental / not hardware-verified**: a static-IP change via
  `^NSP` + `~JR` was observed not to take effect on a GX420t (V56), so the emitted
  command shape and reset sequence are still unconfirmed. Use with caution and a
  recoverable printer.

### Fixed
- `^BY` module width is now emitted by every 1-D barcode (`Code39`, `EAN13`,
  `EAN8`, `UPCA`, `UPCE`, joining `Barcode128`/`Interleaved2of5`), and all expose
  a `moduleWidth(_:)` modifier. Previously a preceding barcode's module width
  could leak in via `^BY` stickiness.
- `EAN13`/`EAN8`/`UPCA` now reject a fully-specified value whose trailing check
  digit doesn't match the computed one, instead of letting the printer silently
  re-derive a different digit.
- `HorizontalLine`/`VerticalLine` clamp resolved length/thickness to ≥ 1 dot,
  matching `Box`/`Circle`/`Ellipse` (a `^GB0` dimension is out-of-range on real
  firmware).
- `PrinterInfo.dpi` now reports 152 (not 150) for 6 dots/mm, matching its own
  docs and `DPI.dpi152`.
- `IntelligentMail` rejects a data string whose Barcode Identifier is invalid
  (the 2nd digit must be 0-4 per USPS-B-3200); previously it would emit an
  out-of-spec symbol.
- Corrected `Interleaved2of5` documentation, which claimed data "must be even"
  while the initializer accepts odd-length input (the printer prepends a 0).

## [1.0.0]

<!-- set release date when tagging -->
First public release.

### Breaking changes

These affect anyone who built against pre-release code:

- The `ZPLVerifier` module (product) was renamed to `ZPLKitVerifier`. Update imports to `import ZPLKitVerifier`. The entry type is still named `ZPLVerifier`.
- `ZPLVerifier.analyze(_:)` and the `verify(...)` overloads are now `async throws` (migrated to the Swift-native Vision API).
- Minimum platforms raised to iOS 27 / macOS 27 / tvOS 27 / watchOS 27.
- Swift 6.4 is required (`swift-tools-version: 6.4`).
- `VerifierError.visionError` was removed (no consumers).

### Added

#### ZPLKit (Label Generation)
- Declarative Swift API using result builders for building ZPL labels
- **Text elements**: `Text`, `TextBlock` with fonts, rotation, reverse print, baseline positioning
- **1D Barcodes**: `Barcode128`, `Code39`, `EAN13`, `EAN8`, `UPCA`, `UPCE`, `Interleaved2of5`
- **2D Barcodes**: `QRCode`, `DataMatrix`, `PDF417`, `Aztec`, `IntelligentMail`
- **Shapes**: `Box`, `Circle`, `Ellipse`, `HorizontalLine`, `VerticalLine`, `DiagonalLine`
- **Graphics**: `Graphic` element for embedding CGImage content, with dithering (Floyd-Steinberg, Atkinson) and aspect-fill cropping
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
- `^GF` graphic decoding: binary (`^GFB`), ASCII run-length compression in `^GFA` (repeat-count letters, `,`/`!` row fills, `:` row repeat), and `^GFC` `:B64:`/`:Z64:` (zlib) formats
- Hex character decoding (`^FH` with `_XX` sequences)
- Render metrics: parse time, render time, image dimensions

#### ZPLKitPrinter (Network Printing)
- `ZPLPrinter`: Send ZPL to printers via TCP (port 9100)
- `ZPLPrinterBrowser`: LAN discovery via Zebra's UDP broadcast protocol (port 4201)
- `DiscoveredPrinter`: Printer metadata from network discovery
- **Two-way communication**: `query()` method for bidirectional printer queries
- **Status queries**: `queryStatus()` for `~HS` (Host Status) response parsing
- **Printer info**: `queryInfo()` for `~HI` (Host Identification) response parsing
- **Memory status**: `queryMemory()` for `~HM` (Host Memory) response parsing
- **Configuration**: `PrinterConfiguration` with type-safe enums, presets, and `apply`/`setup` methods
- **Diagnostics**: combined status, info, memory, and settings in one call
- **Test pages**: `printConfigurationLabel()`, `printNetworkConfigLabel()`
- Structured response types: `PrinterStatus`, `PrinterInfo`, `MemoryStatus`
- Async/await API with configurable connection and response timeouts, plus an idle timeout for automatic connection cleanup

#### ZPLKitVerifier (Label Verification)
- Barcode detection via Vision framework (Code128, QR, Code39, EAN-13, Aztec, PDF417, etc.), covering all 24 Vision symbologies
- Text OCR via the Swift-native `RecognizeTextRequest`
- **Discovery mode**: `analyze()` to discover all barcodes and text in an image
- **Assertion mode**: `verify()` with a declarative expectations DSL
- Expectation types: `Barcode(symbology, exactly/containing:)`, `Text(exactly/containing:)`
- Vision hints optimization for faster detection
- Bounds/clipping detection for edge content
- Result types: `AnalysisResult`, `VerificationResult`, `DetectedBarcode`, `DetectedText`

#### Test Fixtures
- 124 ZPL fixture files covering text, barcodes, shapes, and graphics
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
- Unit and integration tests across all modules
- GitHub Actions CI with visual comparison artifacts
- MIT license

### Changed
- Adopted Swift 6.2's "approachable concurrency" upcoming-feature flags via a shared `swiftSettings` block applied to every first-party target: `NonisolatedNonsendingByDefault` and `InferIsolatedConformances`. (`InferSendableFromCaptures` is already enabled by default in Swift 6 language mode, so it is intentionally not enabled explicitly.) Default isolation remains `nonisolated`; the package is a library and does not force callers onto the main actor.
- `ZPLVerifier.analyze`/`verify` timing now uses `ContinuousClock`; the reported `*TimeSeconds` fields are documented as wall-clock (including time suspended at `await`).
- Set `swiftLanguageModes: [.v6]` explicitly in the manifest.
- Migrated `ZPLVerifier` to the Swift-native Vision API (`DetectBarcodesRequest`, `RecognizeTextRequest`, `ImageRequestHandler`), replacing the legacy `VN`-prefixed completion-handler API.
- `ZPLVerifier` now runs barcode and text recognition concurrently (`async let`), roughly halving analysis latency.
- **Removed the `Awesome` dependency** (and the `GraphicsTest` dev tool that used it); the library now has zero external dependencies.
- CI runs on a self-hosted `macos-27` runner with the Xcode 27 beta toolchain (pinned via `DEVELOPER_DIR`, since no GitHub-hosted image carries the macOS 27 SDK / Swift 6.4 yet), enforces `-warnings-as-errors`, has per-job timeouts, gates the external Labelary visual comparison behind a minimum accuracy score, and skips PRs opened from forks (which cannot use the self-hosted runner).

### Fixed
- **Fixed a `query()` hang**: a continuation race in `ZPLPrinter` could drop the result on fast connection failure and hang forever; it now always resumes.
- **Fixed crashes reachable from public API**: zero-port force-unwrap in `query()`/`send()`, empty-`Data` `send()` trap, integer divide-by-zero on malformed `^GF` (`bytesPerRow == 0`), and a slice-offset bug in the `~HS`/`~HI`/`~HM` response parsers when given a non-zero-`startIndex` `Data`.
- **Fixed ZPL corruption/injection**: free-form barcode payloads (`Barcode128`, `QRCode`, `PDF417`, `DataMatrix`, `Aztec`) and `render(substituting:)` values are now escaped (`^FH`), so `^`/`~`/`_` in data no longer breaks or injects into the command stream.
- POSIX `send()` now loops on partial writes and retries `EINTR`, validates `fcntl`/`getsockopt` results, honors fractional timeouts and task cancellation.
- `ZPLVerifier` now preserves the underlying error, rethrows `CancellationError`, and validates image dimensions.
- Renderer: cache the bundled `CGFont` and reuse one `CIContext` per render pass; reset all `^FB` text-block state between fields; apply rotation to barcode render paths.
- Resolved Swift 6 temporary-pointer warning in `CoreGraphicsRenderer` paragraph-style creation; silenced unused-result `fcntl` warnings in `ZPLPrinter`.
- `ZPLPrinter` now formats POSIX errors with the thread-safe `strerror_r` (the shared `strerror` buffer could race across concurrent `send()` calls).
- Renderer: single-allocation graphic buffer (removed a redundant copy); forward-compatible font-slot selection with documented Font 0 fallback; human-readable placeholder barcode names.

### Internal
- Gated flaky live-network printer tests behind an env var so CI is hermetic by default; added hermetic regression tests for the fixes above.
- The test suite uses the Swift Testing framework throughout (no XCTest). Repetitive barcode-validity, clamping, parser-per-command, and verification matrices are parameterized into `@Test(arguments:)` tables. Coverage was preserved per target; the formerly hidden `SKIP`-prefixed Data Matrix test is now a tracked `@Test(.disabled(...))` skip.

[1.0.0]: https://github.com/jonathanspiva/zplkit/releases/tag/v1.0.0
