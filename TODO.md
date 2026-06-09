# ZPLKit TODO

## Now
- [ ] **Fix ZPL injection in SerialNumber and Comment** - `SerialNumber` startValue (SerialNumber.swift:62) and `Comment` text (Comment.swift:27) are interpolated raw into ZPL; `^`/`~` in the data injects live commands (e.g. `~JR` reset). Validate or escape both.
- [ ] **Set SO_NOSIGPIPE on send() socket** - ZPLPrinter.swift: printer closing the connection mid-write raises SIGPIPE, which kills the host process by default. Set SO_NOSIGPIPE right after socket().
- [ ] **Fix renderer crashes on malformed ZPL** - Unbounded `^PW`/`^LL` overflow `width * 4` in CoreGraphicsRenderer (or request 10GB+ bitmaps); `^GF` bytesPerRow overflows `* 8`; UPC-E with 9+ digits traps on parity-pattern index in EANPatterns.encodeUPCE; `^GF` Z64 capacity and ACS repeat counts allow memory amplification. Clamp dimensions, use checked math, guard sixDigits.count == 6.
- [ ] **Fix Examples compile errors** - `ZPLTemplate` doesn't exist (ShippingLabel, ProductLabel, PartsBinLabel, plus DocC references); modifiers chained on failable inits need `?` (all examples and README Quick Start); `padWithZeros` should be `leadingZeros` (InventoryTag.swift:173). Add an Examples typecheck step to CI.
- [ ] **Fix wrong config ZPL commands** - `^ND` parameters don't match the ZPL manual (likely should be `^NS`), `^JN` is not the printer-name command (likely `^KN`). Verify on lab printers. PrinterConfiguration+ZPL.swift:131-142. Also validate/escape printerName, fieldRotation, and IP fields (injection).
- [ ] **TextBlock maxLines=0 emits out-of-range ^FB** - `^FB` max-lines accepts 1-9999, default 1; emitting 0 truncates wrapped text to one line on real firmware. Map unlimited to 9999. TextBlock.swift.
- [ ] **send() rejects hostnames and IPv6** - inet_pton(AF_INET) only; breaks documented hostname support and Bonjour-discovered printers. Use getaddrinfo (with freeaddrinfo on all paths). ZPLPrinter.swift:240-250.
- [ ] **Harden printer-response parsing and query() lifecycle** - PrinterInfo.dpi and MemoryStatus.used/usagePercent can trap on hostile `~HI`/`~HM` values; query() completes early on multi-segment `~HS` responses; query() cancellation hangs until timeout instead of throwing CancellationError. Range-check parsed fields.
- [ ] **CI and repo hardening** - Add `permissions: contents: read` to ci.yml; switch Labelary calls to https (Tools/VisualTests/main.swift:459); add `.claude/` to .gitignore.
- [ ] **UPCE element length validation contradicts ^B9** - accepts 6/7/8 digits but `^B9` expects 10 characters; normalize or document. UPCE.swift.
- [ ] **Clean up StatusCheck** - Remove `~FF` from feed command (not a valid ZPL command), remove `GraphicPrintTest/status.swift` placeholder

## Later
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
