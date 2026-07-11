# ZPLKit TODO

## Now
- [x] **Fix red CI on master** - Every run since NetworkRoundTripTests landed (2026-06-09) failed: the 7 `query()` round-trip tests (NWConnection to the loopback FakePrinter) timed out at the 2s success timeout, while `send()` (POSIX) tests passed. Cause: NWConnection cold-start plus parallel test load on slow CI runners; the same 7-failure signature reproduced locally once on a cold first run after a clean build. Fix: raised the success-path timeout to 15s (only bounds failing tests), marked the suite `.serialized`, and bumped `waitUntil`'s default to 10s.
- [x] **Close stale GitHub issue #1** (dithering support for Graphic) - feature shipped and is documented in the README; closed 2026-07-10.
- [x] **Clean up StatusCheck** - Removed `~FF` from feed command (not a valid ZPL command) and deleted the `GraphicPrintTest/status.swift` placeholder.

## Later
### Deferred low-severity review items
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
  - Could live in its own repo (e.g., `swift-zplkit-mcp`) following the `swift-ynab-mcp` pattern

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
