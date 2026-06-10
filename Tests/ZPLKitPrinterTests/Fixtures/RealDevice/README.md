# Real-device response fixtures

These are **verbatim byte captures of responses from physical Zebra printers**,
used by `RealDeviceFixtureTests.swift` to verify the `~HI` / `~HS` / `~HM` / `^HH`
parsers against the exact bytes real hardware emits. They run in CI with no
printer attached.

Each file is the raw TCP payload the printer returned on port 9100, including
the `<STX>…<ETX><CR><LF>` framing (`.bin` = framed binary status responses,
`.txt` = the mostly-text `^HH` configuration dump, both stored as raw bytes).

## Provenance

Captured **2026-06-09** from the lab printers over raw TCP (port 9100):

| File prefix | Model | Firmware | Print method | Command sent |
|---|---|---|---|---|
| `zm400_V53.17.24Z_*`  | ZM400-200dpi  | V53.17.24Z | thermal-transfer (ribbon) | `~HI`, `~HS`, `~HM`, `^XA^HH^XZ` |
| `gx420t_V56.17.17Z_*` | GX420t-200dpi | V56.17.17Z | direct-thermal | `~HI`, `~HS`, `~HM`, `^XA^HH^XZ` |

The model and firmware are encoded in each file name so the fixture set
documents exactly which hardware/firmware the parsers are proven against.

## Recapturing / adding a printer

To add fixtures from another printer, capture the raw response bytes (e.g. with
a small socket client that sends the command and writes the reply to a file) and
name them `<model>_<firmware>_<HI|HS|HM|HH>.<bin|txt>`. Then add a suite to
`RealDeviceFixtureTests.swift` asserting the expected parsed values.

> Note: `~HI`, `~HS`, and `~HM` are immediate tilde commands (send them as
> `~HI`, not wrapped in `^XA…^XZ`). `^HH` is a format command and is sent
> wrapped as `^XA^HH^XZ`.
