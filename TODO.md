# ZPLKit TODO

Open work only. Completed work lives in the [CHANGELOG](CHANGELOG.md) and the
git history; hardware findings that are still relevant are written up in
[HARDWARE-VALIDATION.md](HARDWARE-VALIDATION.md) and the README's "Known Issues".

## Now

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

### Toolchain

- [ ] **Re-check both Xcode 27 workarounds once the GA toolchain ships.** Still
  beta as of 2026-09-04 (Swift 6.4 / swiftlang-6.4.0.33.1, macOS 27 26A5425a),
  and both workarounds are still load-bearing:
  - **A bare `swift test` still does not run the whole suite.** Re-measured
    2026-09-04: it ran **2 of the 4 test targets** and exited 0. Only
    ZPLKitRendererTests (163) and ZPLKitPrinterTests (245) ran, 408 of the 683
    tests the package actually has; ZPLKitTests (161) and ZPLKitVerifierTests
    (114) were silently skipped, and all 683 pass when each target is filtered
    explicitly. Note this is a **different** subset than the 2026-08-14
    measurement on 27A5218g, which ran only the first target (244 tests). So
    the bug is not the stable "first target only" rule the CI comments describe;
    which targets get dropped varies by build. The per-target loop in
    `build-and-test` and the total-count assertion both stay until GA runs all
    683 unfiltered.
  - **The DocC "unhandled file" warning.** The beta warns that
    `Sources/ZPLKit/Documentation.docc` is an unhandled file; stable 26.6 handles
    it correctly. Do NOT declare the catalog as a resource to silence it; just
    re-check on GA.

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

### Notes for the next release
Not tasks, but the two facts that cost time last release and are not recorded
anywhere else:

- **The Swift Package Index build matrix is per version.** A fix only shows up
  once it is tagged, so the v1.0.0 row stays red permanently (watchOS could not
  compile and `xcodebuild` failed everywhere; both fixed in 1.0.1).
- **swiftpackageindex.com returns 403 to any scripted fetch** (Cloudflare),
  indexed or not. Only the `/api/.../badge` endpoints answer `curl`, which is
  what the README badges use. Verified still working 2026-09-04: platforms reads
  `iOS | macOS | visionOS | tvOS | watchOS | Linux | Wasm | Android`, Swift
  reads `6.3`.

## Later

- [ ] **Bound the concurrency of `send()`.** `send()` is now the only thing in
  `ZPLKitPrinter` still on GCD: it runs its blocking socket work on
  `DispatchQueue.global()` (ZPLPrinter.swift:146). Mass fan-out (60+ concurrent
  sends to unreachable printers) can saturate GCD's thread pool, and each one
  blocks for the full connect timeout. Deferred because it needs a
  bounded-concurrency design (a dedicated queue or a semaphore), not a spot fix.
  Note the old framing of this item is out of date: `query()` no longer shares
  that queue, so the failure mode is starvation of other `send()` calls and of
  any unrelated global-queue work, not stalled `query()` callbacks.
- [ ] **`send()` does not observe cancellation once it starts.** It calls
  `Task.checkCancellation()` before dispatching, then blocks inside a
  `withCheckedThrowingContinuation` with no cancellation handler, so cancelling
  the task does not interrupt the connect or the write; the caller waits out the
  timeout. Bounded (10s by default) rather than unbounded, hence Later. The fix
  pairs naturally with the bounded-concurrency work above.
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
