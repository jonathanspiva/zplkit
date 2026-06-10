# ZPLKit TODO

## Now
- [x] **Clean up StatusCheck** - Removed `~FF` from feed command (not a valid ZPL command) and deleted the `GraphicPrintTest/status.swift` placeholder.

## Later
### Deferred low-severity review items
- [x] Switch Labelary calls to https (Tools/VisualTests/main.swift:459)
- [x] Add `.claude/` to .gitignore so worktrees/settings can't be accidentally committed
- [x] `try await` in ZPLVerifier doc snippets (ZPLVerifier.swift)
- [x] Clamp `timeout` to a 1-day ceiling before the `Int`/`Int32` conversions in send() (ZPLPrinter.swift)
- [x] `errno` read after connect - already adequate: errno is read on the statement immediately after `Darwin.connect()`, no intervening Swift work. Left as-is.
- [ ] **query() connection-timeout race can return spurious timeout on a success-path race** - deferred: real but subtle concurrency fix (cancel the timer task from complete()), wants careful testing. Not mechanical.
- [ ] **Discovery opens a port-9100 connection per browse event** - deferred: architectural change to ZPLPrinterBrowser (resolve endpoints lazily on selection). Affects how DiscoveredPrinter.host is populated; wants hardware validation.
- [ ] **Examples build target / CI typecheck step** - deferred: adds CI infra / source refactor (examples have top-level code). Worth doing but out of "final fixes" scope.

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
