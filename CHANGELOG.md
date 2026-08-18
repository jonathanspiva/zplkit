# Changelog

All notable changes to ZPLKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-08-18

### Added

- **Linux support for `ZPLKit`.** ZPL generation already worked on Linux (the
  only platform dependency, the CoreGraphics-backed `Graphic` element, was
  already behind `#if canImport`), but nothing tested or documented it, so it
  worked by accident and could have regressed silently.

  `Package.swift` now declares only `ZPLKit` and its tests when the host is not
  Darwin, so `swift build` and `swift test` both work on Linux instead of
  failing on the first Apple-only import. This runs the 155-test core suite
  there; previously no test could run on Linux at all. The Apple package graph
  is byte-identical to before. `ZPLKitRenderer` (CoreGraphics),
  `ZPLKitVerifier` (Vision), and `ZPLKitPrinter` (Network) remain Apple-only.

  CI builds and tests on `swift:6.3` and asserts that a consumer package
  renders a label byte-identically to macOS.

## [1.0.1] - 2026-08-17

### Fixed

- **watchOS builds.** `ZPLKitVerifier` used Vision unconditionally, so the
  package failed to compile for watchOS despite declaring `.watchOS(.v26)`. The
  Vision module is absent on watchOS under Xcode 26, and under Xcode 27 it
  imports but its Swift API (`DetectBarcodesRequest`, `RecognizeTextRequest`) is
  watchOS 27+. Its sources are now behind
  `#if canImport(Vision) && !os(watchOS)`; the module is empty on watchOS and
  `ZPLKit`, `ZPLKitRenderer`, and `ZPLKitPrinter` build normally.
- **`xcodebuild` builds of the package.** `Tools/RenderFixtures` and
  `Tools/VisualTests` used `@main` inside a file named `main.swift`. That
  filename is compiled in top-level-code mode, where `@main` is an error, so
  `xcodebuild -scheme ZPLKit-Package` failed at the Swift 6.3 floor even for
  macOS. SwiftPM tolerated it, which is why `swift build` never caught it. Both
  files are renamed after their target, so they compile as parse-as-library.
  This affects anyone building ZPLKit through Xcode rather than SwiftPM.
- `Tools/VisualTests` is now `#if os(macOS)`, since it depends on
  `ZPLKitVerifier` and so could not compile for watchOS.

### Changed

- CI now builds for iOS, tvOS, and watchOS via `xcodebuild -scheme
  ZPLKit-Package`, matching what Swift Package Index does. Previously only macOS
  was ever compiled, which is why the watchOS break shipped in 1.0.0. The
  whole-package scheme matters: the per-product `ZPLKit` scheme builds green on
  watchOS even when `ZPLKitVerifier` does not compile.

## [1.0.0] - 2026-08-14

First public release.

### Breaking changes

These affect anyone who built against pre-release code:

- The `ZPLVerifier` module (product) was renamed to `ZPLKitVerifier`. Update imports to `import ZPLKitVerifier`. The entry type is still named `ZPLVerifier`.
- `ZPLVerifier.analyze(_:)` and the `verify(...)` overloads are now `async throws` (migrated to the Swift-native Vision API).
- `ZPLKitVerifier`'s expectation types were renamed `Text` → `TextExpectation` and
  `Barcode` → `BarcodeExpectation`, so `Text` no longer collides with `ZPLKit.Text`
  when both modules are imported for the build → render → verify workflow.
- Minimum platforms are iOS 26 / macOS 26 / tvOS 26 / watchOS 26, and Swift 6.3
  is required (`swift-tools-version: 6.3`). An earlier pre-release targeted 27 /
  Swift 6.4; the floor was lowered so the package installs on a shipping
  toolchain rather than a beta OS. Nothing in the library needed the higher
  floor: the Swift-native Vision API shipped in iOS 18 / macOS 15, and
  `NetworkConnection` is macOS 26.
- Removed the inert `dpi:` parameter from `ZPLRenderer.render(_:)` and
  `renderToPNG(_:)`. Output dimensions are derived from the label's `^PW`/`^LL`
  dot values, so the parameter never had any effect.
- `ZPLRenderer.renderToPNG(_:)` returns a `PNGRenderResult` struct instead of a
  `(data:metrics:)` tuple. A tuple return type can never gain a member, so it
  would have been frozen at 1.0.
- Removed five public error cases that nothing ever threw:
  `PrinterError.printerNotFound` / `.receiveFailed`, `VerifierError.unexpected`,
  and `ZPLRendererError.parseError` / `.unsupportedCommand`. They documented
  conditions that could not occur, and deleting them after 1.0 would be a break.
  `ZPLParser.parse` keeps `throws` for future use.
- `CGImage.pngData()` and `CoreGraphicsRenderer` are now internal. The former is
  a retroactive extension on a system type, which collides with the same
  extension anywhere else in a consumer's dependency graph; the latter is
  unreachable in practice (`ParsedLabel` has no public initializer) and kept the
  internal parse-to-draw pipeline frozen. Use `ZPLRenderer.render(_:)`.
- `ZPLTemplate.render(with:)` is now `render(substituting:)`, matching
  `ZPLLabel`; `DataMatrix.size(_:)` is now `moduleSize(_:)`, matching
  `moduleWidth(_:)` / `magnification(_:)` on its siblings.
- `PrinterConfiguration.fieldRotation` is a typed `FieldRotation` enum instead of
  a `String`, and its cases spell the same as `ZPLKit.Rotation`
  (`.normal` / `.rotated90` / `.inverted` / `.rotated270`).
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
- 125 ZPL fixture files covering text, barcodes, shapes, and graphics
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
- `ParsedLabel` / `ParsedElement` and the other `Parsed*` types are documented as
  part of the public, semver-stable API, with doc comments on every property.
  `ParsedElement` may still gain cases in minor releases, so switch over it with
  a `default`.
- `BarcodeSymbology` is not `@frozen`, so future Vision symbologies can be added
  without a source break (switch over it with a `default` case).
- `Expectation` provides a default `visionHints`, so future protocol
  requirements will not break external conformers.
- `PrinterConfiguration.networkConfig(...)` / `dhcp()` (the `^NS` path) are
  documented as **experimental / not hardware-verified**: a static-IP change via
  `^NSP` + `~JR` was observed not to take effect on a GX420t (V56), so the
  emitted command shape and reset sequence are still unconfirmed. Use with
  caution and a recoverable printer.
- Adopted Swift 6.2's "approachable concurrency" upcoming-feature flags via a shared `swiftSettings` block applied to every first-party target: `NonisolatedNonsendingByDefault` and `InferIsolatedConformances`. (`InferSendableFromCaptures` is already enabled by default in Swift 6 language mode, so it is intentionally not enabled explicitly.) Default isolation remains `nonisolated`; the package is a library and does not force callers onto the main actor.
- `ZPLVerifier.analyze`/`verify` timing now uses `ContinuousClock`; the reported `*TimeSeconds` fields are documented as wall-clock (including time suspended at `await`).
- Set `swiftLanguageModes: [.v6]` explicitly in the manifest.
- Migrated `ZPLVerifier` to the Swift-native Vision API (`DetectBarcodesRequest`, `RecognizeTextRequest`, `ImageRequestHandler`), replacing the legacy `VN`-prefixed completion-handler API.
- `ZPLVerifier` now runs barcode and text recognition concurrently (`async let`), roughly halving analysis latency.
- **Removed the `Awesome` dependency** (and the `GraphicsTest` dev tool that used it); the library now has zero external dependencies.
- The README documents which ZPL commands the preview renderer implements, and
  what the four unimplemented ones (`^LR`, `^CI`, `^CC`/`^CT`, raw-binary
  `^GFB`) do on a printer versus in the preview.
- CI builds the package at its advertised floor on a GitHub-hosted `macos-26`
  runner (Xcode 26.6 / Swift 6.3) with `-warnings-as-errors`, which also gives
  fork PRs a CI signal. The self-hosted runner additionally covers the visual
  comparison and the opt-in live-printer job, gated behind a minimum accuracy
  score and per-job timeouts.

### Fixed

#### Label generation
- `^BY` module width is now emitted by every 1-D barcode (`Code39`, `EAN13`,
  `EAN8`, `UPCA`, `UPCE`, joining `Barcode128`/`Interleaved2of5`), and all expose
  a `moduleWidth(_:)` modifier. Previously a preceding barcode's module width
  could leak in via `^BY` stickiness.
- `EAN13`/`EAN8`/`UPCA` now reject a fully-specified value whose trailing check
  digit doesn't match the computed one, instead of letting the printer silently
  re-derive a different digit.
- Template substitution corrupted Code 128 payloads. Inside a `^BC` field a
  literal `>` is an invocation code, so `Barcode128`'s constructor rewrites it to
  `>0` before hex-escaping; substitution applied only the hex escaping, so
  `Barcode128("{{sku}}")` substituted with `PRICE>5` printed a symbol that
  scanned as `PRICE`. Substitution now tracks whether a placeholder sits inside a
  `^BC` field and applies the same escape order there, and only there.
- `HorizontalLine`/`VerticalLine` clamp resolved length/thickness to ≥ 1 dot,
  matching `Box`/`Circle`/`Ellipse` (a `^GB0` dimension is out-of-range on real
  firmware).
- `IntelligentMail` rejects a data string whose Barcode Identifier is invalid
  (the 2nd digit must be 0-4 per USPS-B-3200); previously it would emit an
  out-of-spec symbol.
- **Fixed ZPL corruption/injection**: free-form barcode payloads (`Barcode128`, `QRCode`, `PDF417`, `DataMatrix`, `Aztec`) and `render(substituting:)` values are now escaped (`^FH`), so `^`/`~`/`_` in data no longer breaks or injects into the command stream.
- Corrected `UPCE`'s documentation, which described a 7th digit as an explicit
  check digit. It is a *leading number system* digit, so following the old docs
  shifted every digit and encoded a different product. Verified against
  Labelary: `^FD0123456` renders pixel-identical to `^FD123456`.
- Corrected `Interleaved2of5` documentation, which claimed data "must be even"
  while the initializer accepts odd-length input (the printer prepends a 0).

#### Rendering and parsing
- 2-D barcodes rendered **mirrored**. `drawBarcodeImage` drew into the y-flipped
  ZPL context without un-flipping, so a QR's finder patterns landed at
  TL/BL/BR instead of TL/TR/BL. Affected QR, Aztec and PDF417. The verifier did
  not catch it because Vision decodes mirrored symbols happily.
- Rotated fields were placed on the wrong side of their `^FO` origin. Printers
  anchor the rotated bounding box's top-left *at* the origin; the renderer
  rotated *about* it, so `I` and `B` fields drew up and to the left (often
  clipped off the label) and `R` sat one glyph-height too far left.
- `^LH` (label home) was ignored, so every field of a label that sets a home
  offset rendered in the wrong place.
- `^PO` was ignored; `^POI` now renders the label rotated 180 degrees.
- `^FW` was not implemented, and a `^A` font rotation leaked into any barcode
  that omitted its orientation slot, so `^A0R` followed by `^BC,...` rendered
  the barcode rotated. Barcodes now take their default orientation from `^FW`;
  text still follows `^A`.
- `^FO`/`^FT` with a single coordinate were dropped entirely, so the field kept
  the previous field's position and drew on top of it. An omitted y defaults
  to 0.
- `^FB` survived `^FS`: a block whose field closed without `^FD` leaked its
  width and alignment onto the next field.
- `^CF` with an omitted height fell back to a hardcoded 30. The omitted height
  follows the supplied width, so `^CF0,,20` renders at 20.
- `^GFA` run-length runs were clamped to a single row of nibbles. The encoding
  is a flat nibble stream, so runs legitimately cross rows: `^GFA,8,8,1,VF` is
  an 8x8 solid square that decoded to an 8x1 sliver.
- `^GB`'s 5th parameter is a corner-rounding index of 0-8, not a radius in dots;
  it was used directly, so every rounded box came out nearly square.
- The interpretation line under a GTIN symbol showed the raw field data, one
  digit short of the symbol above it. EAN-13, EAN-8 and UPC-A captions now
  include the printer-computed check digit.
- Renderer: cache the bundled `CGFont` and reuse one `CIContext` per render pass; reset all `^FB` text-block state between fields.
- Renderer: single-allocation graphic buffer (removed a redundant copy); forward-compatible font-slot selection with documented Font 0 fallback; human-readable placeholder barcode names.
- **Fixed crashes reachable from public API**: zero-port force-unwrap in `query()`/`send()`, empty-`Data` `send()` trap, integer divide-by-zero on malformed `^GF` (`bytesPerRow == 0`), and a slice-offset bug in the `~HS`/`~HI`/`~HM` response parsers when given a non-zero-`startIndex` `Data`.

#### Printing and discovery
- **Fixed a `query()` hang**: a continuation race in `ZPLPrinter` could drop the result on fast connection failure and hang forever; it now always resumes.
- A cancelled `query()` could return truncated data as a *success*: the idle
  timer swallowed the cancellation and won the race against the receive task, so
  a partial `^HH` parsed into a silently incomplete `PrinterSettings`.
- `ZPLPrinterBrowser` leaked its thread, socket and a broadcast every 3 seconds
  for the life of the process when dropped without `stop()` — including in the
  README's own discovery example — because the discovery thread retained the
  browser, making `deinit` unreachable. The socket is now owned solely by that
  thread, `stop()` no longer closes a descriptor out from under it (which could
  hit an unrelated reused fd), and a stop/start cycle no longer closes the new
  session's socket. A failed socket setup no longer leaves a browser that
  reports itself running.
- POSIX `send()` now loops on partial writes and retries `EINTR`, validates `fcntl`/`getsockopt` results, honors fractional timeouts and task cancellation.
- `PrinterInfo.dpi` now reports 152 (not 150) for 6 dots/mm, matching its own
  docs and `DPI.dpi152`.
- `ZPLPrinter` now formats POSIX errors with the thread-safe `strerror_r` (the shared `strerror` buffer could race across concurrent `send()` calls).
- `ZPLVerifier` now preserves the underlying error, rethrows `CancellationError`, and validates image dimensions.
- Resolved Swift 6 temporary-pointer warning in `CoreGraphicsRenderer` paragraph-style creation; silenced unused-result `fcntl` warnings in `ZPLPrinter`.

#### Documentation
- Corrected the bundled font's license, which one doc comment gave as SIL Open
  Font License 1.1. Roboto Condensed is Apache License 2.0, as `NOTICE`, the
  README and the bundled `Roboto-LICENSE.txt` all correctly state.
- `ZPLParser` no longer claims the `Parsed*` types are internal and unstable,
  which contradicted both the changelog and `ParsedLabel`'s own documentation.
- Fixed a `DiagonalLine` sample that used a `.leftToRight` case that does not
  exist (so the snippet never compiled), a README bullet advertising an "idle
  timeout" feature that was never implemented, and a DocC landing page that
  described three modules and omitted `ZPLKitPrinter`.

### Internal
- Gated flaky live-network printer tests behind an env var so CI is hermetic by default; added hermetic regression tests for the fixes above.
- The test suite uses the Swift Testing framework throughout (no XCTest). Repetitive barcode-validity, clamping, parser-per-command, and verification matrices are parameterized into `@Test(arguments:)` tables. Coverage was preserved per target; the formerly hidden `SKIP`-prefixed Data Matrix test is now a tracked `@Test(.disabled(...))` skip.
- CI ran only a third of the test suite. On the Xcode 27 beta toolchain a bare
  `swift test` executes only the first test target and exits 0 (244 of 670
  tests). CI now runs every test target explicitly and asserts the total count.
- `VisualTests --labelary` fetched nothing: a percent-encoded request body made
  Labelary reject all 124 fixtures with "404 ... ZPL generated no labels". The
  API reads the body verbatim and never form-decodes it, so the ZPL is posted as
  raw bytes.
- `VisualTests` parsed fixture dimensions with a regex that could not match a
  decimal, so `2x0.75` became `2x0` and Labelary rejected the zero-height label
  with HTTP 400. This cost the 13 fixtures with 0.5/0.75-inch heights their
  reference renders. Unparseable filenames now warn instead of silently
  defaulting to 4x6.
- `VisualTests` exits non-zero when more than 10% of Labelary fetches fail, so a
  broken comparison can no longer report a green run.
- Visual reference set completed and corrected. 37 fixtures had no
  reference image at all (every `canonical_*` and `graphic_*` fixture), so the
  accuracy score covered only 70% of the corpus. A further 12 references were
  rendered at 812x1218 (a 4x6 fallback) rather than their true label size, and
  because they were compared against correctly-sized renders they scored *high*
  and inflated the reported accuracy. `--score` now validates every reference
  against the geometry implied by its filename and fails on a mismatch.
- Added a rotation fixture; there was no coverage of field orientation at all,
  which is why the rotated-field anchoring bug went unseen.

[1.0.3]: https://github.com/jonathanspiva/zplkit/releases/tag/v1.0.3
[1.0.1]: https://github.com/jonathanspiva/zplkit/releases/tag/v1.0.1
[1.0.0]: https://github.com/jonathanspiva/zplkit/releases/tag/v1.0.0
