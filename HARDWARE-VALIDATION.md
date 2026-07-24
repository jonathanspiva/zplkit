# Hardware validation

ZPLKit's printer communication layer is validated against **physical Zebra
printers**, not just synthetic data. This document records what was tested, on
which hardware and firmware, and how to reproduce it.

## Tested hardware

| Model | Firmware | DPI | Print method | Connection |
|---|---|---|---|---|
| Zebra **ZM400-200dpi**  | **V53.17.24Z** | 203 | thermal-transfer (ribbon) | TCP / port 9100 |
| Zebra **GX420t-200dpi** | **V56.17.17Z** | 203 | direct-thermal | TCP / port 9100 |

Last validated: **2026-07-23** (full `LivePrinterTests` sweep re-run on current
`main` — 18/18 pass on both printers).

## How it's validated

Three layers, in decreasing order of "runs everywhere":

### 1. Real-device response fixtures (run in CI, no hardware needed)

Verbatim byte captures of `~HI`, `~HS`, `~HM`, and `^HH` responses from the
printers above are committed under
[`Tests/ZPLKitPrinterTests/Fixtures/RealDevice/`](Tests/ZPLKitPrinterTests/Fixtures/RealDevice/)
and parsed by `RealDeviceFixtureTests`. (Device serial numbers in these captures
have been replaced with placeholder values; every other byte is as-emitted.) These assert that
`PrinterInfo` / `PrinterStatus` / `MemoryStatus` / `PrinterSettings` extract the
correct values from the exact bytes these firmwares emit — e.g. ZM400 reports
`darkness 30, 2 IPS, 812-dot width, thermal-transfer`, GX420t reports
`darkness 15, 4 IPS, 816-dot width, direct-thermal, serial 50J000000001`. This
layer runs on every CI build with no printer attached, so parser regressions
against real-firmware output are caught automatically.

### 2. Live integration tests (run on demand against the hardware)

`LivePrinterTests` (gated behind `ZPLTOOL_LIVE_TESTS=1`) exercise the full
network round-trip against real printers: query parsing, configuration
round-trips (change → save → read back → assert → restore for darkness, speed,
and multi-setting), `apply()`/`setup()` with real `~JC` calibration, and full
`queryDiagnostics()`. Run them with:

```sh
ZPLTOOL_LIVE_TESTS=1 \
ZPLTOOL_ZM400_HOST=192.168.1.100 \
ZPLTOOL_GX420T_HOST=192.168.1.101 \
swift test --filter LivePrinterTests
```

All 18 live tests passed against both printers above (ZM400 in ribbon mode,
GX420t in direct-thermal) on 2026-06-09, and again on 2026-07-23 on current
`main` (after the POSIX-`send()` revert and the UDP-4201 discovery rewrite):
darkness/speed/multi-setting round-trips, query parsing, `apply()`/`setup()`
single-payload delivery, and `~JC` calibration all pass. `Tools/PrinterTests`
provides an
additional standalone integration sweep (`swift run PrinterTests <ip>`) covering
concurrent queries, rapid bursts, timeout differentiation, and query-after-timeout;
on that date 27/28 checks passed on the GX420t (the one failure was the printer
being left paused, not a code defect).

### 2b. Ad hoc generation and discovery checks on hardware

- **Code 128 `>` invocation-code escaping** (2026-07-23, ZM400 V53.17.24Z +
  GX420t V56.17.17Z): `Barcode128("PRICE>5")` emits field data `PRICE>05`, and
  both printers decode the human-readable interpretation line as `PRICE>5`. The
  raw form (`^FD...PRICE>5`) decodes as `PRICE` on both — the `>5` is consumed as
  a function/subset invocation code — confirming the `>` -> `>0` escaping is
  required and correct.
- **UDP-4201 discovery** (2026-07-23, same two printers): the rewritten
  `ZPLPrinterBrowser` (off Bonjour/mDNS, PR #7) discovers both units end-to-end
  via its async `printers` stream. Each replied (unicast) to the broadcast probe
  with a well-formed packet (magic `:,.`), and `parseReply` extracted the correct
  host, port 9100, system name, product, `ZebraNet Wired PS`, and firmware
  (`V53.17.24Z` / `V56.17.17Z`). Note: `discoveredPrinters` is emptied by
  `stop()`, so read it while the browser is running.
- **Barcode symbology print pass** (2026-07-23, `Tools/BarcodePrintTest`): one
  sample of all 12 ZPLKit symbologies (code128, code39, i2of5, imb, ean13, ean8,
  upca, upce, qr, datamatrix, pdf417, aztec) printed to both printers. All 12
  render correctly on the GX420t (direct-thermal). On the ZM400 the same
  symbologies were correct wherever they landed in the label's left half; a
  ribbon/printhead streak band on the *right* half degraded the tall 1-D bars
  there. That was confirmed to be a printer-hardware artifact, not a generation
  defect: it tracked label position (not symbology), cleared when the affected
  codes were reprinted in the left column, and was absent entirely on the GX420t.
  Caveat: **USPS IMb** prints its 4-state bar structure but its codeword
  *encoding* is unverified — a scanner decode is still outstanding, and the
  renderer's IMb encoder is a known placeholder (see TODO "Someday").

### 3. Synthetic + malicious-input fixtures (run in CI)

`ResponseParsingTests` complements the real captures with hand-built edge cases
(truncated frames, missing ETX, non-numeric and out-of-range fields, hostile
`Int.max`/negative values) to prove the parsers fail or clamp gracefully on
untrusted network input rather than trapping.

## Known hardware limitations (not code defects)

- **Printer name (`^KN`) round-trip** can't be confirmed on the ZM400/GX420t:
  these pre-Link-OS firmwares don't expose `device.friendly_name` (SGD can't read
  or write it) and `^HH` has no name field. The `^KN` ZPL emission is verified
  correct by unit tests; confirming the round-trip end-to-end needs a Link-OS
  printer (e.g. ZD-series, ZT411, ZD621).
- **LAN discovery**: Zebra print servers don't advertise `_pdl-datastream._tcp`
  over Bonjour/mDNS by default (browsing it finds generic IPP/socket printers
  like an office inkjet, not Zebra units), so `ZPLPrinterBrowser` uses Zebra's
  proprietary UDP-4201 broadcast protocol instead. Validated end-to-end on
  hardware 2026-07-23 (see 2b above).
- **`^NS` network reconfiguration** is intentionally not exercised against shared
  lab printers (a wrong value would take the printer off the network); the ZPL
  emission is covered by unit tests.

## Adding another printer

Capture its `~HI`/`~HS`/`~HM`/`^HH` responses, drop them in
`Fixtures/RealDevice/` named `<model>_<firmware>_<cmd>.<bin|txt>`, and add a
suite to `RealDeviceFixtureTests`. See that directory's `README.md` for details.
