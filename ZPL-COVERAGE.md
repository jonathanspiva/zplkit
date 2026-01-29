# ZPL Command Coverage

This document tracks which ZPL II commands are supported by ZPLKit.

## Coverage Summary

| Category | Supported | Total | Coverage |
|----------|-----------|-------|----------|
| Label Format | 4 | 4 | 100% |
| Field Positioning | 2 | 3 | 67% |
| Text/Fonts | 3 | 8 | 38% |
| Barcodes | 4 | 20+ | 20% |
| Graphics/Shapes | 1 | 5 | 20% |
| Field Processing | 3 | 10+ | 30% |

## Supported Commands (v1.0)

### Label Format Commands
| Command | Description | Status | Element |
|---------|-------------|--------|---------|
| `^XA` | Start format | ✅ | ZPLLabel |
| `^XZ` | End format | ✅ | ZPLLabel |
| `^PW` | Print width | ✅ | ZPLLabel |
| `^LL` | Label length | ✅ | ZPLLabel |

### Field Positioning
| Command | Description | Status | Element |
|---------|-------------|--------|---------|
| `^FO` | Field origin | ✅ | All elements |
| `^FT` | Field typeset | ❌ | - |
| `^LH` | Label home | ✅ | ZPLLabel.labelHome() |

### Text and Fonts
| Command | Description | Status | Element |
|---------|-------------|--------|---------|
| `^A` | Scalable font | ✅ | Text, TextBlock |
| `^CF` | Change default font | ✅ | ZPLLabel.defaultFont() |
| `^FD` | Field data | ✅ | All elements |
| `^FS` | Field separator | ✅ | All elements |
| `^FB` | Field block | ✅ | TextBlock |
| `^FH` | Field hex indicator | ✅ | Text (auto) |
| `^FR` | Field reverse | ✅ | Text.reversed() |
| `^FW` | Field orientation | ❌ | - |

### Barcode Commands
| Command | Description | Status | Element |
|---------|-------------|--------|---------|
| `^BC` | Code 128 | ✅ | Barcode128 |
| `^BQ` | QR Code | ✅ | QRCode |
| `^B3` | Code 39 | ✅ | Code39 |
| `^BX` | DataMatrix | ✅ | DataMatrix |
| `^BY` | Barcode defaults | ✅ | Barcode128.moduleWidth() |
| `^BE` | EAN-13 | ❌ | Future |
| `^B8` | EAN-8 | ❌ | Future |
| `^BU` | UPC-A | ❌ | Future |
| `^B9` | UPC-E | ❌ | Future |
| `^BO` | Aztec | ❌ | Future |
| `^B7` | PDF417 | ❌ | Future |

### Graphics Commands
| Command | Description | Status | Element |
|---------|-------------|--------|---------|
| `^GB` | Graphic box | ✅ | Box, HorizontalLine, VerticalLine |
| `^GC` | Graphic circle | ❌ | Future |
| `^GD` | Graphic diagonal | ❌ | Future |
| `^GE` | Graphic ellipse | ❌ | Future |
| `^GF` | Graphic field | ❌ | Someday (images) |

### Print Control
| Command | Description | Status | Element |
|---------|-------------|--------|---------|
| `^PQ` | Print quantity | ✅ | ZPLLabel.printQuantity() |
| `^MD` | Media darkness | ✅ | ZPLLabel.printDarkness() |
| `^PR` | Print rate/speed | ❌ | Future |
| `^PH` | Slew home | ❌ | - |

## Out of Scope (v1.0)

These commands are intentionally not supported in v1.0:

### RFID Commands
- `^RF` - Read/write RFID
- `^RS` - RFID setup
- `^RT` - RFID tag

### Serialization
- `^SF` - Serialization field
- `^SN` - Serial number

### Stored Formats
- `^DF` - Download format
- `^XF` - Recall format
- `^IS` - Image save

### Printer Configuration
- `~JC` - Set media sensor calibration
- `~SD` - Set darkness
- `~HS` - Host status return
- `~HI` - Host identification

## Test Coverage

Each supported command should have:
1. Unit test verifying correct ZPL output
2. Visual test in at least one fixture label

### Command Test Matrix

| Command | Unit Test | Visual Test |
|---------|-----------|-------------|
| `^XA/^XZ` | ✅ testBasicLabelRenders | All fixtures |
| `^PW/^LL` | ✅ testLabelDimensionsCorrect | All fixtures |
| `^FO` | ✅ (implicit) | All fixtures |
| `^A` | ✅ testTextWithFont | Multiple fixtures |
| `^FD/^FS` | ✅ testBasicLabelRenders | All fixtures |
| `^FB` | ✅ testTextBlockRenders | - |
| `^FH` | ✅ testSpecialCharactersEscaped | - |
| `^FR` | ❌ TODO | shipping_return |
| `^BC` | ✅ testBarcode128Valid | shipping_*, sku_* |
| `^BQ` | ✅ testQRCodeRenders | qr_*, inventory_* |
| `^B3` | ✅ testCode39Valid | - |
| `^BX` | ✅ testDataMatrixRenders | datamatrix_* |
| `^GB` | ✅ testBoxRenders | Multiple fixtures |
| `^PQ` | ✅ testPrintQuantity | - |

## Adding New Commands

When adding support for a new ZPL command:

1. Add entry to this coverage document
2. Implement the Swift type/modifier
3. Add unit test for ZPL output
4. Add visual test fixture if applicable
5. Update coverage percentages
