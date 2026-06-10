# Hardware validation

ZPLKit's printer communication layer is validated against **physical Zebra
printers**, not just synthetic data. This document records what was tested, on
which hardware and firmware, and how to reproduce it.

## Tested hardware

| Model | Firmware | DPI | Print method | Connection |
|---|---|---|---|---|
| Zebra **ZM400-200dpi**  | **V53.17.24Z** | 203 | thermal-transfer (ribbon) | TCP / port 9100 |
| Zebra **GX420t-200dpi** | **V56.17.17Z** | 203 | direct-thermal | TCP / port 9100 |

Last validated: **2026-06-09**.

## How it's validated

Three layers, in decreasing order of "runs everywhere":

### 1. Real-device response fixtures (run in CI, no hardware needed)

Verbatim byte captures of `~HI`, `~HS`, `~HM`, and `^HH` responses from the
printers above are committed under
[`Tests/ZPLKitPrinterTests/Fixtures/RealDevice/`](Tests/ZPLKitPrinterTests/Fixtures/RealDevice/)
and parsed by `RealDeviceFixtureTests`. These assert that
`PrinterInfo` / `PrinterStatus` / `MemoryStatus` / `PrinterSettings` extract the
correct values from the exact bytes these firmwares emit — e.g. ZM400 reports
`darkness 30, 2 IPS, 812-dot width, thermal-transfer`, GX420t reports
`darkness 15, 4 IPS, 816-dot width, direct-thermal, serial 31J114702349`. This
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
ZPLTOOL_ZM400_HOST=192.168.7.4 \
ZPLTOOL_GX420T_HOST=192.168.7.5 \
swift test --filter LivePrinterTests
```

On 2026-06-09 all 18 live tests passed against both printers above (ZM400 in
ribbon mode, GX420t in direct-thermal). `Tools/PrinterTests` provides an
additional standalone integration sweep (`swift run PrinterTests <ip>`) covering
concurrent queries, rapid bursts, timeout differentiation, query-after-timeout,
and Bonjour discovery — 27/28 passed on the GX420t (the one failure was the
printer being left paused, not a code defect).

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
- **Bonjour discovery**: these printers don't advertise `_pdl-datastream._tcp`,
  so they aren't discoverable via mDNS (a printer setting). The service type is
  correct — an HP printer on the same network advertises it and resolves fine.
- **`^NS` network reconfiguration** is intentionally not exercised against shared
  lab printers (a wrong value would take the printer off the network); the ZPL
  emission is covered by unit tests.

## Adding another printer

Capture its `~HI`/`~HS`/`~HM`/`^HH` responses, drop them in
`Fixtures/RealDevice/` named `<model>_<firmware>_<cmd>.<bin|txt>`, and add a
suite to `RealDeviceFixtureTests`. See that directory's `README.md` for details.
