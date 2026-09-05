# ZPL Test Fixtures

A collection of real-world ZPL files for testing parsers and renderers.

## Overview

ZPLKit includes 125 ZPL test fixtures covering shipping labels, retail tags, warehouse bins, barcodes, shapes, and more. Use these to validate your own ZPL parser or renderer implementation.

## Location

Fixtures are in `Tests/VisualTestHarness/fixtures/` with metadata in `Tests/VisualTestHarness/fixtures.json`.

## Categories

| Category | Count | Description |
|----------|-------|-------------|
| `asset` | 4 | Asset tags |
| `barcode` | 14 | Barcode-focused tests (Code128, QR, EAN, etc.) |
| `canonical` | 10 | Baseline barcode verification, one per symbology |
| `features` | 9 | Specific feature tests (rotation, text blocks, serial numbers) |
| `food` | 6 | Food storage and meal prep labels |
| `graphic` | 36 | Labels with embedded graphics |
| `inventory` | 5 | Inventory tags |
| `medical` | 1 | Medical/specimen labels |
| `retail` | 8 | Retail and product SKU labels |
| `shapes` | 4 | Shape rendering tests |
| `shipping` | 7 | Shipping labels (FedEx, UPS, USPS styles) |
| `shop` | 8 | Parts bin and shop labels |
| `simple` | 8 | Minimal single-purpose labels |
| `warehouse` | 5 | Warehouse bin and location labels |

**Total: 125**

## File Format

Each ZPL file includes a description comment:

```zpl
^XA
^FX DESCRIPTION: 4x6 shipping label with Code128 tracking barcode,
^FX QR code for mobile lookup, and formatted address block.
^PW1218
^LL1824
...
^XZ
```

## Metadata Schema

`fixtures.json` provides structured metadata for each fixture:

```json
{
  "shipping_4x6_300": {
    "category": "shipping",
    "description": "Shipping label on 4x6 at 300 DPI. From/to addresses, tracking number, service type, weight, and Code 128 barcode. Higher resolution version.",
    "dpi": 300,
    "expectedBarcodes": [
      { "payload": "1Z999AA10123456784", "symbology": "code128" },
      { "payload": "1Z999AA10123456784", "symbology": "qr" }
    ],
    "features": ["^BC", "^A0", "^GB"],
    "size": "4x6"
  }
}

The key is the fixture's bare name. The ZPL for it lives at
`fixtures/<key>.zpl` and its reference image at `reference/<key>.png`.
```

### Fields

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | Human-readable description |
| `category` | string | Fixture category |
| `features` | array | ZPL command tokens the fixture exercises (e.g. `"^BC"`, `"^GB"`) |
| `size` | string | Label dimensions (e.g., "4x6") |
| `dpi` | number | Printer DPI (203, 300, 600) |
| `expectedBarcodes` | array | Barcodes that should be detected |
| `knownLimitations` | string | Notes about Vision framework limitations |

## Using Fixtures

### Load the fixtures

The fixtures are test resources in this repository, not resources of any shipped
library target, so `Bundle.module` cannot reach them. Check the repo out (or vendor
the directory) and read them from disk:

```swift
// Point at your checkout of zplkit.
let root = URL(filePath: "/path/to/zplkit/Tests/VisualTestHarness")

struct ExpectedBarcode: Decodable {
    let payload: String
    let symbology: String
}

struct Fixture: Decodable {
    let category: String
    let description: String
    let dpi: Int
    let size: String
    let expectedBarcodes: [ExpectedBarcode]?
}

let metadata = try JSONDecoder().decode(
    [String: Fixture].self,
    from: Data(contentsOf: root.appending(path: "fixtures.json"))
)

// Each key is a fixture name; the ZPL lives alongside it.
let zpl = try String(
    contentsOf: root.appending(path: "fixtures/\(metadata.keys.first!).zpl"),
    encoding: .utf8
)
```

### Filter by category

```swift
let barcodeFixtures = metadata.filter { $0.value.category == "barcode" }
```

### Verify barcode rendering

```swift
for (name, meta) in metadata {
    guard let expectedBarcodes = meta.expectedBarcodes, !expectedBarcodes.isEmpty else { continue }
    let zpl = loadFixture(name)
    let image = try renderer.render(zpl)

    for expected in expectedBarcodes {
        // Use Vision framework to verify barcode renders correctly
        let detected = try detectBarcodes(in: image)
        #expect(detected.contains { $0.payload == expected.payload })
    }
}
```

## Contributing Fixtures

When adding new fixtures:

1. Create the ZPL file in `Tests/VisualTestHarness/fixtures/`
2. Include a `^FX DESCRIPTION:` comment at the top
3. Add metadata to `fixtures.json`
4. Run `swift run VisualTests` to verify rendering
