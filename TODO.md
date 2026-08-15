# ZPLKit TODO

Open work only. Completed work lives in the [CHANGELOG](CHANGELOG.md) and the
git history; hardware findings that are still relevant are written up in
[HARDWARE-VALIDATION.md](HARDWARE-VALIDATION.md) and the README's "Known Issues".

## Now

### Open source release
- [x] Fold `[Unreleased]` into `[1.0.0]` in the CHANGELOG and set the release date
- [x] Tag v1.0.0 release (2026-08-14)
- [x] Make repo public
- [x] Submit to Swift Package Index
  ([PackageList#14832](https://github.com/SwiftPackageIndex/PackageList/issues/14832))
- [ ] **Swap the README badges to Swift Package Index once indexing completes.**
  Held deliberately: until SPI builds the package its badge API returns
  `"message": "pending"` with `isError: true`, so the badges would render grey
  and broken-looking on a freshly public repo. Check
  <https://swiftpackageindex.com/jonathanspiva/zplkit> (403 until indexed), then
  replace the static Swift/Platforms badges with:

  ```markdown
  [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fjonathanspiva%2Fzplkit%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/jonathanspiva/zplkit)
  [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fjonathanspiva%2Fzplkit%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/jonathanspiva/zplkit)
  ```

  These track the manifest automatically, so they stop going stale when the
  floor moves.

### Hardware verification
These need a physical printer, and they are the last unverified claims in the docs.

- [ ] **Test ZPLKit `calibrate()` against a manual media calibration.** On the
  GX420t, `ZPLPrinter.setup()` / `calibrate()` (which sends `~JC`) did NOT fully
  re-register the media; labels printed but sat misaligned, borders crossing
  the label gaps. The printer's **manual 2-blink media calibration** (hold FEED,
  release on the 2nd green flash) fixed alignment. Verify what `calibrate()` and
  `calibrateFull()` actually emit and whether they should trigger the fuller
  length/gap re-measure rather than just `~JC`.
- [ ] **`^NS` network reconfig does not take effect via `~JR`.** Round-trip test
  on the GX420t (V56): `^NSP,<free-ip>` + `^JUS` + `~JR` left the IP unchanged.
  `networkConfig()`/`dhcp()` are documented as **experimental** in the README.
  Disambiguate when there's time and a recoverable printer: send `^NSP,<free-ip>`,
  **physically power-cycle**, then re-check via UDP-4201 discovery. If it moves,
  the fix is "power cycle, not `~JR`"; if not, the emitted `^NS` format is wrong
  for this firmware. A Link-OS printer would allow SGD read-back (like `^KN`).
- [ ] **Decode a printed USPS IMb with a scanner.** Generation is confirmed
  spec-correct (`^BZ ...,3` = Intelligent Mail, printer-encoded) and the Barcode
  Identifier is validated (2nd digit 0-4). The only thing left is to scan a
  printed sample with an IMb-capable reader to confirm end-to-end scannability.
  Separately, the software-renderer *preview* is still an approximate
  placeholder (a pixel-accurate 4-state encoder needs the USPS-B-3200 reference
  tables), low priority since the printer does the real encoding.

### Tooling and CI
- [ ] **Consider refreshing the remaining references against current Labelary.**
  35 of the 87 old references are size-identical to Labelary 3.3.0 output, but
  the rest have drifted (mostly <1%, a few up to 11% on `shapes_*`). A wholesale
  refresh scores 90.2% vs the current 90.9%, i.e. today's Labelary agrees
  slightly *less* with our renderer than the older vintage did. Worth
  understanding whether that is a Labelary antialiasing change or a real ZPLKit
  regression before adopting it as the baseline.
- [ ] **Wire the live-printer sweep into the runner's `workflow_dispatch` job.**
  UDP-4201 discovery is hardware-validated, but the sweep isn't automated.
- [ ] Cosmetic: the Xcode 27 beta warns that `Sources/ZPLKit/Documentation.docc`
  is an "unhandled file". Stable 26.6 handles it correctly. Do NOT declare the
  catalog as a resource; just re-check on the Xcode 27 GA toolchain.

## Later

- [ ] **Phase 1a: `query()` -> NetworkConnection.** Replace the NWConnection +
  `QueryState`-actor machinery in `query()` with the Swift-native
  `NetworkConnection` async API (`receive`/`send`, `TCP().connectionTimeout`).
  Verifiable via NetworkRoundTripTests (loopback FakePrinter). Must preserve:
  single-ETX completion, 3-frame `~HS`, trailing-ETX `^HH` in <0.9s, idle
  fallback, graceful-close, responseTimeout, prompt cancellation.
  Note: this applies to `query()` only. Do **not** do the same to `send()`;
  see the README's "Known Issues" for why that was tried and reverted.
- [ ] `send()`/`query()` share the global concurrent queue; mass fan-out (60+
  concurrent sends to unreachable printers) can saturate GCD threads and stall
  `query()` callbacks (ZPLPrinter.swift). Deferred: needs a bounded-concurrency
  design (dedicated queue or semaphore), not a spot fix.
- [ ] **ZPLKit MCP server** - MCP tool server wrapping ZPLKit for use with LLM agents
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

## Never

Decisions rather than history: these have been considered and declined. The
reasons are kept so they don't get re-proposed.

- **Stored formats (`^DF`, `^XF`)** - Printer-dependent state; ZPLKit's
  `{{variable}}` templates solve this better at the application level.
- **SF Symbols icon support** - Apple licensing prohibits redistribution and use
  in printed materials; FontAwesome is the supported alternative.
- **Snapshot tests (pixel-perfect PNG comparison)** - ZPLKitVerifier already
  validates that barcodes scan correctly; snapshot tests are brittle across macOS
  versions, CI environments, and architectures, and thermal printers are
  forgiving of minor rendering differences.
