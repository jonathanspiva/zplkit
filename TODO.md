# ZPLKit TODO

## Now
### Live-hardware findings (2026-07-15)

- [ ] **Test ZPLKit `calibrate()` against a manual media calibration.** On the
  GX420t, `ZPLPrinter.setup()` / `calibrate()` (which sends `~JC`) did NOT fully
  re-register the media — labels printed but sat misaligned, borders crossing
  the label gaps. The printer's **manual 2-blink media calibration** (hold FEED,
  release on the 2nd green flash) fixed alignment. Verify what `calibrate()` and
  `calibrateFull()` actually emit and whether they should trigger the fuller
  length/gap re-measure rather than just `~JC`.
- [x] **`send()` reverted to POSIX sockets** (PR #5) — a `NetworkConnection`
  `send()` (PR #4) passed tests but intermittently dropped jobs on real Zebra
  printers. GX420t + ZM400 now print reliably via `send()`; verified on hardware.
- [x] **`GraphicPrintTest` hardened** (PR #6) — traceable ID/timestamp footers,
  sensor-safe margins, `--fiducial` and `--calibrate` modes.

### Live-hardware findings (2026-07-23)

- [x] **Barcode symbology print pass** (`Tools/BarcodePrintTest`, PR #10) — all 12
  symbologies printed to the ZM400 + GX420t. Library output correct across the
  board; the ZM400 right-half streaking was a ribbon/printhead artifact (tracked
  position not symbology, cleared in the left column, absent on the GX420t). See
  HARDWARE-VALIDATION.md 2b.
- [ ] **Decode a printed USPS IMb with a scanner.** Generation is confirmed
  spec-correct (`^BZ ...,3` = Intelligent Mail, printer-encoded) and the Barcode
  Identifier is now validated (2nd digit 0-4, PR #11). The only thing left is to
  scan a printed sample with an IMb-capable reader to confirm end-to-end
  scannability. Separately, the software-renderer *preview* is still an
  approximate placeholder (a pixel-accurate 4-state encoder needs the USPS-B-3200
  reference tables) — low priority since the printer does the real encoding.

### Require macOS/iOS/tvOS/watchOS 27 + Swift 6.4 (2026-07-15)

Platform floor raised from 26 to 27 (Xcode 27 beta / Swift 6.4). What the bump
actually unlocks is Swift 6.4 language ergonomics; the framework modernizations
below were already available at the 26 floor and are bundled in here.

- [x] **Phase 0: floor bump** - `Package.swift` swift-tools 6.3->6.4 and all four
  platforms .v26->.v27; README badges. Builds clean, 243 tests pass on Swift 6.4.
- [x] **Phase 2: Vision Swift API** - No-op. Verifier already uses the modern
  `DetectBarcodesRequest`/`RecognizeTextRequest`/`ImageRequestHandler` API (that
  API shipped iOS 18 / macOS 15, well below the floor). No legacy `VN*` left.
- [ ] **Phase 1a: `query()` -> NetworkConnection** - Replace the NWConnection +
  `QueryState`-actor machinery in `query()` with the Swift-native
  `NetworkConnection` async API (`receive`/`send`, `TCP().connectionTimeout`) and
  `async defer` (SE-0493) for cleanup. Verifiable now via NetworkRoundTripTests
  (loopback FakePrinter). Must preserve: single-ETX completion, 3-frame `~HS`,
  trailing-ETX `^HH` in <0.9s, idle fallback, graceful-close, responseTimeout,
  prompt cancellation. Note: `NetworkConnection` is macOS 26, so this did not
  require the 27 bump; `async defer` is the 6.4-specific win.
- [x] **Phase 1b: `send()` -> NetworkConnection - TRIED AND REVERTED (PR #5).**
  Do NOT re-attempt without a physical-printer A/B test. A `NetworkConnection`
  `send()` (PR #4) passed all loopback tests but intermittently **dropped print
  jobs on real Zebra hardware** (teardown races the printer's job commit). It was
  reverted to POSIX sockets in PR #5; the GX420t (FW V56.17.17Z) and ZM400 now
  print reliably. See the README "Known Issues" section before touching `send()`.
  Connect-error mapping preserved (`ETIMEDOUT`/unreachable -> `.timeout`,
  `ECONNREFUSED` -> `.connectionFailed`).
- [x] **Phase 1c: `ZPLPrinterBrowser` rewritten off Bonjour (PR #7).** Zebra
  units don't advertise `_pdl-datastream._tcp` over mDNS, so the browser now uses
  Zebra's proprietary UDP-4201 broadcast protocol. Request/response parsing is
  unit-tested, and end-to-end discovery was validated on hardware 2026-07-23
  (ZM400 + GX420t both discovered via the async `printers` stream; see
  HARDWARE-VALIDATION.md 2b).
- [x] **Phase 0 (CI): `ci.yml` -> macos-27** - Done. All push/PR jobs run on a
  self-hosted `macos-27` runner with the Xcode 27 beta toolchain (pinned via
  `DEVELOPER_DIR`), since no GitHub-hosted image carries the macOS 27 SDK / Swift
  6.4 yet. Fork PRs are skipped (they can't use the self-hosted runner); the live
  printer job is `workflow_dispatch`-only.
- [ ] **Phase 3: verify** - UDP-4201 discovery validated on hardware 2026-07-23
  (Phase 1c). Still outstanding: wire the live sweep into the self-hosted runner's
  `workflow_dispatch` job, and add a GitHub-hosted build/unit job for fork PRs
  once a `macos-27` hosted image ships.

### Code review pass 2026-07-10 (53 findings)

#### High severity
- [x] `ZPLPrinterBrowser.stop()` deadlocks: `continuation.finish()` under the non-reentrant NSLock re-enters via `onTermination` (ZPLPrinterBrowser.swift:134)
- [x] `IntelligentMail` emits `^BZ` without the 5th postal-code-type param, so printers default to POSTNET instead of type 3 (IntelligentMail.swift:53)
- [x] Renderer parsers use `split(separator: ",")` which drops omitted middle params and shifts argument slots (`^BCN,,Y,N,N`, `^GB100,,2`) (ZPLParser/ShapeParser/BarcodeParser/TextParser)
- [x] Renderer R/B rotations swapped: `^A0R` renders CCW, `^A0B` CW, opposite of spec, text and barcodes (CoreGraphicsRenderer.swift:163,431)
- [x] `^FS` never processed: a barcode without `^FD` survives the separator and captures the next unrelated `^FD` (ZPLParser.swift:213)
- [x] `^FT` baseline positioning parsed but never used; renders identical to `^FO` (ParsedLabel.useBaseline, CoreGraphicsRenderer.swift:185)
- [x] VisualTests POSTs raw ZPL as `application/x-www-form-urlencoded` without percent-encoding; `+`/`%XX`/`&` corrupt Labelary references (VisualTests/main.swift:462)

#### Medium: generation (wrong bytes to real printers)
- [x] Non-ASCII text hex-escaped under `^FH` but no `^CI28` emitted; CP850 default prints mojibake (StringEscaping.swift:8)
- [x] ASCII control chars pass through `^FD` unescaped; `Barcode128("AB\nCD")` silently encodes ABCD (StringEscaping.swift:28)
- [x] TextBlock doesn't escape literal backslashes (`^FB` escape introducer) (TextBlock.swift:175)
- [x] Numeric barcode elements validate with `isNumber`, accepting fullwidth/Arabic-Indic digits into `^FD` (EAN13/EAN8/UPCA/UPCE/I2of5/IntelligentMail)
- [x] `DataMatrix.rows()` without `.columns()` emits rows in the columns slot (DataMatrix.swift:66)

#### Medium: printer networking
- [x] `query(responseTimeout: .infinity)` traps in `nanoseconds(from:)` (rounds to 2^64); deadline addition can also overflow; `send()` clamps but `query()` doesn't (ZPLPrinter.swift:418)
- [x] `poll()` EINTR/-1 misreported as `.timeout`; should re-poll on EINTR, `connectionFailed` otherwise (ZPLPrinter.swift:325)
- [x] `^HH` early-completion requires trailing LF but real devices end `0D 0A 03`; every queryConfiguration burns ~1-1.5s idle timer and >1s stalls truncate silently (ZPLPrinter.swift:633)

#### Medium: renderer parsing/fidelity
- [x] `^B3` param order wrong: check-digit flag comes before height per spec (BarcodeParser.swift:22 via ZPLParser.swift:174)
- [x] `^AB`-`^AZ` commands dropped entirely (size+rotation lost); `ParserState.currentFont` is `let` so font A unreachable (ZPLParser.swift:110,286)
- [x] `^GFA` with `:Z64:`/`:B64:` payload decodes as hex garbage (GraphicParser.swift:60)
- [x] `_XX` hex escapes decoded without `^FH` gating; corrupts `2_50` (TextParser.swift:44)
- [x] Field data whitespace-trimmed, losing intentional leading/trailing spaces (ZPLParser.swift:40,63)
- [x] `fontWidth` parsed but ignored; `^A0N,30,90` renders normal width (CoreGraphicsRenderer.swift:134)
- [x] `^FR` on a field without `^FD` leaks reverse-print to the next field (ZPLParser.swift:136,270)
- [x] Code128 `>` invocation codes and `^BQ` `MA,` prefix encoded literally into symbols (CoreGraphicsRenderer.swift:531,557)
- [x] One bad barcode aborts the whole label render instead of skipping the element (CoreGraphicsRenderer.swift:90)

#### Medium: tools/CI
- [x] VisualTests scoring drops failed fixtures from the denominator (regressions raise the score) and reuses stale PNGs on render failure (VisualTests/main.swift:299,176)
- [x] Size-mismatch comparison bottom-aligns images; 1px height diff reports catastrophic score (VisualTests/main.swift:498)
- [x] Visual-tests CI job can never fail (`continue-on-error` + tool always exits 0) (ci.yml:62)
- [x] No CI `concurrency` group; stacked pushes run duplicate macOS pipelines (ci.yml)

#### Low severity
- [x] I2of5 odd-length data prints with printer-prepended 0, scanning differently than input (Interleaved2of5.swift:21)
- [x] Graphic aspect-derived height truncates instead of rounds (Graphic.swift:103)
- [x] DiagonalLine direction doc comments swapped vs `^GD` semantics (DiagonalLine.swift:12)
- [x] `bitmapToHex` per-byte `String(format:)`; lookup table ~100x faster on large graphics (Graphic.swift:325, StringEscaping.swift:12)
- [x] Template substitution: a value containing `{{key}}` gets expanded by later iterations (ZPLLabel.swift:235)
- [x] Shapes/label emit zero/negative resolved dimensions verbatim; clamp to >=1 like Graphic (Box.swift:100 et al, ZPLLabel.swift:101)
- [x] Verifier `verify {}` with empty/conditionally-empty builder passes vacuously (ZPLVerifier.swift:181)
- [x] `PrinterInfo.extractContent` no-ETX fallback keeps leading STX byte (PrinterInfo.swift:180)
- [x] `printers`/`stop()` race can strand an iterator on a never-terminated stream (ZPLPrinterBrowser.swift:78)
- [x] SO_SNDTIMEO expiry surfaces as sendFailed("Resource temporarily unavailable") instead of `.timeout` (ZPLPrinter.swift:387)
- [x] `queryDiagnostics()` blanket catch swallows `CancellationError` (ZPLPrinter+Configuration.swift:194)
- [x] Doc comment says 10s default, actual 15s (ZPLPrinter+Configuration.swift:146,164)
- [x] `^BY` third param (default barcode height) ignored, hardcoded 100 (ZPLParser.swift:139, BarcodeParser.swift:8)
- [x] `^FB` maxLines not enforced (frameHeight doubled); lineSpacing/hangingIndent parsed but unapplied (CoreGraphicsRenderer.swift:237)
- [x] `^GB` border strokes centered on path; ZPL draws inside the box (CoreGraphicsRenderer.swift:268)
- [x] Code128 interpretation line drawn unrotated after rotation applied (CoreGraphicsRenderer.swift:580)
- [x] Z64/B64 CRC stripped but never validated (GraphicParser.swift:327)
- [x] EAN-13 quiet zone 9/9; spec wants 11 left / 7 right (EANPatterns.swift:85)
- [x] `decodeFieldData` O(n*m) on `_XX`-heavy fields (TextParser.swift:47)
- [x] Dead `hasSuffix("^FS")` strip in TextParser (regex can't produce it) (TextParser.swift:38)
- [x] VisualTests `CGContext(data: &pixels)` inout-to-pointer UB; use withUnsafeMutableBytes (VisualTests/main.swift:576,602)
- [x] GitHub Actions pinned by mutable tag, not SHA (ci.yml:17,54,71)
- [x] **Fix red CI on master** - Every run since NetworkRoundTripTests landed (2026-06-09) failed: the 7 `query()` round-trip tests (NWConnection to the loopback FakePrinter) timed out at the 2s success timeout, while `send()` (POSIX) tests passed. Cause: NWConnection cold-start plus parallel test load on slow CI runners; the same 7-failure signature reproduced locally once on a cold first run after a clean build. Fix: raised the success-path timeout to 15s (only bounds failing tests), marked the suite `.serialized`, and bumped `waitUntil`'s default to 10s.
- [x] **Close stale GitHub issue #1** (dithering support for Graphic) - feature shipped and is documented in the README; closed 2026-07-10.
- [x] **Clean up StatusCheck** - Removed `~FF` from feed command (not a valid ZPL command) and deleted the `GraphicPrintTest/status.swift` placeholder.

## Later
### Deferred low-severity review items
- [ ] `send()`/`query()` share the global concurrent queue; mass fan-out (60+ concurrent sends to unreachable printers) can saturate GCD threads and stall query() callbacks (ZPLPrinter.swift). Deferred: needs a bounded-concurrency design (dedicated queue or semaphore), not a spot fix.
- [x] Switch Labelary calls to https (Tools/VisualTests/main.swift:459)
- [x] Add `.claude/` to .gitignore so worktrees/settings can't be accidentally committed
- [x] `try await` in ZPLVerifier doc snippets (ZPLVerifier.swift)
- [x] Clamp `timeout` to a 1-day ceiling before the `Int`/`Int32` conversions in send() (ZPLPrinter.swift)
- [x] `errno` read after connect - already adequate: errno is read on the statement immediately after `Darwin.connect()`, no intervening Swift work. Left as-is.
- [x] **query() connection-timeout race** - Fixed: the connection-timeout timer is cancelled in the `.ready` handler (once connected it can't spuriously fire a bogus `PrinterError.timeout` while the command is in flight), and both timeout timers are registered with `QueryState` so `complete()` cancels them instead of letting them sleep out the full timeout. Verified stable over repeated runs.
- [x] **Discovery / diagnostics open too many port-9100 connections** - Partially addressed (low-risk parts): `queryDiagnostics()` now runs `~HI`/`~HS`/`~HM` sequentially instead of 3 concurrent connections; the browser refreshes TXT metadata in place on `.changed` events instead of reopening a resolution connection to the print port. NOT done (needs real mDNS hardware): the full lazy-resolution redesign that would avoid the one resolution connection per `.added` by storing the NWEndpoint and resolving only on connect (changes the public `DiscoveredPrinter` API).
- [x] **Examples CI typecheck step** - Added: the build-and-test CI job now typechecks every `Examples/*.swift` against the built ZPLKit module (`swiftc -typecheck`), so example drift fails CI. No SPM target / source refactor needed.

### Verifier API findings (from coverage pass, non-security)
- [x] **VerificationBuilder control-flow methods were dead code** - Fixed: `buildExpression` lifts each statement to `[any Expectation]` and `buildBlock(_:)` takes `[any Expectation]...` and flattens, so `if`/`if-else`/`for`/`if #available` now work inside a `@VerificationBuilder` block. Pinned with DSL control-flow tests.
- [x] **`Text(containing:)` case-insensitive vs `Barcode(containing:)` case-sensitive** - Resolved by documenting the asymmetry as intentional: barcode payloads are exact machine data (case-sensitive), OCR text is fuzzy (case-insensitive). Documented on `Barcode.PayloadMatch`.

- [ ] **Open source release**
  - [ ] Tag v1.0.0 release
  - [ ] Make repo public
  - [ ] Add package to Swift Package Index (PR to SwiftPackageIndex/PackageList)
  - [ ] Update README badges to use Swift Package Index badges

- [ ] **ZPLKit MCP server** - MCP tool server wrapping ZPLKit for use with Claude and other LLM agents
  - Discover printers, query status, configure, and print labels via natural language
  - Tools: `discover_printers`, `printer_status`, `configure_printer`, `print_label`, `preview_label`
  - Swift executable using the MCP protocol over stdio
  - Could live in its own repo (e.g., `swift-zplkit-mcp`)

## Someday
- [ ] **Physical print verification** - End-to-end testing with real printers
  - V1: MacBook camera capture + ZPLKitVerifier (hold label in front of camera)
  - AVFoundation `AVCaptureSession` for FaceTime camera frame capture
  - ZPLKitVerifier already handles barcode/text detection from captured image
  - V2: Network camera support (HTTP snapshot endpoints like `/snapshot.jpg`)
  - V3: Automated test fixture (camera mount, consistent lighting, label positioning)
  - Consider: timing (wait for print), print quality grading (ISO 15415), thermal artifacts
- [ ] **Additional font support** - Currently only Font 0 (Roboto Condensed Bold) is bundled
  - Font A-F mappings to open source equivalents
  - Scalable font loading from system or bundled TTF files
  - `^CW` custom font command support
- [ ] **SGD (Set-Get-Do) commands** - Modern Link-OS protocol for newer printers
  - `! U1 getvar/setvar/do` syntax, more granular than ZPL control commands
  - `odometer.total_label_count` for precise print verification (count before/after)
  - `device.*` namespace for identification, `odometer.*` for maintenance info
  - `sensor.head.temp` for head temperature (not available via ZPL control commands)
  - Full support on Link-OS printers; reduced set on older printers (ZM400 era)
- [ ] **RFID encode-at-print** - ZPL `^RF`, `^RS`, `^RT` commands for UHF EPC Gen2 tags
  - Requires RFID-enabled printer (e.g., ZT411R, ZD621R)
  - Write EPC, TID, User Memory banks
  - Void-and-retry on encode failure (`^RZ`)
  - Useful for parts bin tracking, retail item-level tagging, asset management
- [ ] **Public barcode generation API** - Expose barcode encoding as a module
  - Most encoders already implemented internally (Code128, Code39, EAN-13/8, UPC-A/E, I2of5)
  - QR, Aztec, PDF417 use CoreImage (available on Apple platforms)
  - Data Matrix encoder (CoreImage doesn't support it, needs mathematical implementation)
  - Intelligent Mail encoder (uses placeholder currently)
- [ ] **Bluetooth printer support** - Add BLE and Bluetooth Classic transports for mobile printers
  - Target printers: Zebra ZQ610 Plus, ZQ620 Plus, ZQ630 Plus (and legacy QLn220)
  - BLE via CoreBluetooth: Zebra Parser Service (`38EB4A80-C570-11E3-9507-0002A5D5C51B`), write characteristic (`38EB4A82-...`), chunked writes for BLE packet limits
  - Bluetooth Classic via ExternalAccessory framework (MFi, stream-based like TCP)
  - Abstract transport with a `ZPLTransport` protocol (TCP, BLE, Bluetooth Classic implementations)
  - Label generation unchanged; only the send/query transport differs
  - Note: 2" mobile printers have 48mm max print width vs 104mm on desktop printers

## Done
- [x] **Zero-touch printer configuration API** - `PrinterConfiguration` struct with type-safe enums, ZPL generation, presets, and `apply`/`setup` methods on `ZPLPrinter`. Validated on ZM400-200dpi and GX420t-200dpi (x2). 82/82 integration tests pass.
- [x] **Update README with printer configuration docs** - Added configuration examples, status query example, and updated feature list
- [x] **Fix TCP send for reliable delivery** - POSIX sockets for send(), NWConnection .finalMessage has issues (documented in README Known Issues)
- [x] **Merge feature/printer-configuration to master**

## Never
- Stored formats (`^DF`, `^XF`) - Printer-dependent state; ZPLKit's `{{variable}}` templates solve this better at the application level
- SF Symbols icon support - Apple licensing prohibits redistribution and use in printed materials; FontAwesome is the supported alternative
- Snapshot tests (pixel-perfect PNG comparison) - ZPLKitVerifier already validates barcodes scan correctly; snapshot tests are brittle across macOS versions, CI environments, and architectures; thermal printers are forgiving of minor rendering differences
