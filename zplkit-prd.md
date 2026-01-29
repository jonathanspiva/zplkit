# ZPLKit Library Specification

**Version:** 0.2.0 (Draft)
**Author:** Jonathan / Anticipate IT
**Date:** January 2026
**Swift Version:** 6.0+ (strict concurrency, XCTest)

---

## 1. Purpose

A Swift library for generating ZPL (Zebra Programming Language) code. Nothing else.

**What it does:**
- Provides Swift types that emit valid ZPL strings

**What it doesn't do:**
- Network communication (use NWConnection yourself)
- Bluetooth pairing
- Printer discovery
- ZPL parsing/rendering (use Zebrash/zpl-renderer-js for testing)
- Image conversion (separate concern)

**Why not swift-zpl?**
[swift-zpl](https://github.com/scchn/swift-zpl) is a good library with a command-oriented API that mirrors ZPL structure. ZPLKit takes a different approach: a label-first abstraction where users think in terms of "text at position" rather than "field origin, field data, field separator." The ZPL details are hidden.

---

## 2. Design Principles

### 2.1 API Philosophy

```swift
// The entire mental model in one example:
let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
    Text("M6 Titanium Bolt", at: .inches(0.25, 0.25))
        .font(.default, height: .inches(0.15))

    Barcode128("M6-TI-001", at: .inches(0.25, 0.75))  // Returns optional
        .height(.inches(0.5))

    Box(at: .inches(0.2, 0.2), width: .inches(1.5), height: .inches(1.4))
        .thickness(2)  // Integer literal = dots (via ExpressibleByIntegerLiteral)
}

let zpl = label.render()  // "^XA^FO50,50^A0N,30,30^FDM6 Titanium Bolt^FS..."
```

**Note:** Barcode initializers are failable (`init?`) for charset-restricted types. The result builder accepts optionals; `nil` barcodes are silently omitted from output. For user-provided data, validate before label creation or handle the optional explicitly.

### 2.2 Core Tenets

| Principle | Implementation |
|-----------|----------------|
| **Clear, minimal API** | Result builder DSL. Few types. Obvious names. |
| **Does one thing well** | Generates ZPL strings. Period. |
| **Predictable behavior** | Same input = same output. No side effects. |
| **Reasonable defaults** | Works without configuration for common cases. |
| **Minimal dependencies** | Zero external dependencies. Pure Swift. |
| **Concurrency-ready** | All public types are `Sendable`. Swift 6 strict concurrency compatible. |
| **Stable interface** | SemVer. Public API changes only in major versions. |
| **Proper error handling** | Compile-time where possible. Clear errors at runtime. |
| **Performance-appropriate** | String building is not a bottleneck. Clarity > micro-optimization. |

---

## 3. Scope

### 3.1 In Scope (v1.0)

**Label Elements:**
- Text fields (`^FD`, `^A`, `^FO`)
- Barcodes: Code128 (`^BC`), QR Code (`^BQ`), Code39 (`^B3`), DataMatrix (`^BX`), PDF417 (`^B7`), Interleaved 2 of 5 (`^B2`)
- Shapes: Box (`^GB`), Lines (horizontal/vertical via thin box), Circle (`^GC`), Ellipse (`^GE`), Diagonal Line (`^GD`)
- Field positioning (`^FO`, `^FT`)
- Field orientation/rotation

**Label Configuration:**
- Label start/end (`^XA`, `^XZ`)
- Print width (`^PW`)
- Label length (`^LL`)
- Print quantity (`^PQ`)
- Default font (`^CF`)

**Output:**
- Single render method returning `String`
- Optional pretty-printing (newlines between elements) for debugging

### 3.2 Out of Scope (v1.0)

- RFID commands
- Serialization (`^SF`, `^SN`)
- Printer configuration commands (`~JC`, `~SD`, etc.)
- Font downloading (`~DU`)
- Stored formats (`^DF`, `^XF`)

### 3.3 Future Consideration (v2.0+)

- Additional barcodes (EAN-13, EAN-8, UPC-A, UPC-E, Aztec)
- Label templates with variable substitution
- Advanced serialization (`^SF`, `^SN`)

### 3.4 Someday (No Commitment)

- Graphics/images (`^GF`, `~DG`) via separate `ZPLKitGraphics` package

---

## 4. API Design

### 4.1 Entry Point

```swift
import ZPLKit

let label = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
    // elements
}

let zpl: String = label.render()
let debugZpl: String = label.render(prettyPrint: true)
```

### 4.2 Core Types

```swift
// Label container
public struct ZPLLabel: Sendable {
    public init(
        width: Double,      // inches
        height: Double,     // inches
        dpi: DPI = .dpi203,
        @ZPLBuilder content: () -> [ZPLElement]
    )

    /// Renders ZPL string. Non-throwing; invalid values are clamped with DEBUG logging.
    public func render(prettyPrint: Bool = false) -> String
}

// DPI presets (matches common Zebra printers)
public enum DPI: Int, Sendable {
    case dpi152 = 152   // 6 dpmm
    case dpi203 = 203   // 8 dpmm (most common)
    case dpi300 = 300   // 12 dpmm
    case dpi600 = 600   // 24 dpmm
}

// Position specification (converted to dots at render time using label's DPI)
public enum Position: Sendable {
    case dots(Int, Int)               // x, y in dots
    case inches(Double, Double)       // converted at render time
    case mm(Double, Double)           // converted at render time
}

// Single-value dimension (converted to dots at render time using label's DPI)
public enum Dimension: Sendable, ExpressibleByIntegerLiteral {
    case dots(Int)
    case inches(Double)
    case mm(Double)

    // ExpressibleByIntegerLiteral allows: .height(100) instead of .height(.dots(100))
    public init(integerLiteral value: Int) { self = .dots(value) }
}

// All elements conform to this
public protocol ZPLElement: Sendable {
    func render(context: ZPLRenderContext) -> String
}

// Internal context passed during rendering (not public API)
struct ZPLRenderContext {
    let dpi: DPI
    let labelWidth: Int   // dots
    let labelHeight: Int  // dots
}
```

### 4.3 Text

```swift
public struct Text: ZPLElement {
    public init(_ text: String, at position: Position)

    // Modifiers (return Self for chaining)
    /// Default: font 0, height 30 dots, width = height (~10pt at 203 DPI)
    public func font(_ font: ZPLFont, height: Dimension, width: Dimension? = nil) -> Self
    public func reversed() -> Self
    public func rotated(_ rotation: Rotation) -> Self
}

public enum ZPLFont: String, Sendable {
    case `default` = "0"    // Scalable, most compatible
    case a = "A"
    case b = "B"
    // ... etc
}

public enum Rotation: String, Sendable {
    case normal = "N"       // 0°
    case rotated90 = "R"    // 90° clockwise
    case inverted = "I"     // 180°
    case rotated270 = "B"   // 270° clockwise
}
```

**Output:**
```zpl
^FO50,100^A0N,30,30^FDHello World^FS
```

### 4.4 Text Block (Word Wrap)

```swift
public struct TextBlock: ZPLElement {
    public init(_ text: String, at position: Position, width: Dimension)

    public func font(_ font: ZPLFont, height: Dimension, width: Dimension? = nil) -> Self
    public func maxLines(_ lines: Int) -> Self           // 0 = unlimited (default)
    public func lineSpacing(_ spacing: Dimension) -> Self
    public func alignment(_ alignment: TextAlignment) -> Self
    public func hangingIndent(_ indent: Dimension) -> Self
}

public enum TextAlignment: String, Sendable {
    case left = "L"
    case center = "C"
    case right = "R"
    case justified = "J"
}
```

**Output:**
```zpl
^FO50,100^FB400,3,0,L,0^A0N,30,30^FDThis is a long text that will wrap to multiple lines^FS
```

### 4.5 Barcodes

```swift
public struct Barcode128: ZPLElement {
    public init?(_ data: String, at position: Position)  // Failable: validates charset

    public func height(_ height: Dimension) -> Self
    public func showText(_ show: Bool) -> Self
    public func textAbove() -> Self
    public func rotated(_ rotation: Rotation) -> Self
    public func moduleWidth(_ width: Int) -> Self  // 1-10, default 2 (unitless)
}

public struct QRCode: ZPLElement {
    public init(_ data: String, at position: Position)

    public func magnification(_ mag: Int) -> Self  // 1-10 (unitless multiplier)
    public func errorCorrection(_ level: QRErrorCorrection) -> Self
}

public enum QRErrorCorrection: String, Sendable {
    case ultraHigh = "H"  // 30% recovery
    case high = "Q"       // 25%
    case medium = "M"     // 15% (default)
    case low = "L"        // 7%
}

public struct Code39: ZPLElement {
    public init?(_ data: String, at position: Position)  // Failable: A-Z, 0-9, space, -.$/+% only

    public func height(_ height: Dimension) -> Self
    public func showText(_ show: Bool) -> Self
    public func checkDigit(_ include: Bool) -> Self
}

public struct DataMatrix: ZPLElement {
    public init(_ data: String, at position: Position)  // Accepts any data

    public func size(_ size: Int) -> Self              // Module size 1-10 (unitless)
    public func quality(_ level: Int) -> Self          // 0, 50, 80, 100, 140, 200
    public func columns(_ cols: Int) -> Self           // Fixed columns (optional)
    public func rows(_ rows: Int) -> Self              // Fixed rows (optional)
}

public struct PDF417: ZPLElement {
    public init(_ data: String, at position: Position)  // Accepts any data

    public func rotated(_ rotation: Rotation) -> Self
    public func rowHeight(_ height: Dimension) -> Self  // Height of each row
    public func securityLevel(_ level: Int) -> Self     // 0-8 (0 = auto)
    public func columns(_ cols: Int) -> Self            // 1-30 (0 = auto)
    public func rows(_ rowCount: Int) -> Self           // 3-90 (0 = auto)
    public func truncated() -> Self                     // Truncated PDF417
}

public struct Interleaved2of5: ZPLElement {
    public init?(_ data: String, at position: Position)  // Failable: digits only

    public func rotated(_ rotation: Rotation) -> Self
    public func height(_ height: Dimension) -> Self
    public func showText(_ show: Bool) -> Self
    public func textAbove() -> Self
    public func checkDigit(_ include: Bool) -> Self     // MOD 10 check digit
    public func moduleWidth(_ width: Int) -> Self       // 1-10
}
```

**Output:**
```zpl
^FO50,200^BCN,100,Y,N,N^FD123456^FS
^FO50,350^BQN,2,5^FDQA,https://example.com^FS
^FO50,500^BXN,5,200^FDserial123^FS
^FO50,600^B7N,8,0,0,0,N^FDPDF417-DATA^FS
^FO50,700^B2N,80,Y,N,N^FD123456789012^FS
```

### 4.6 Shapes

```swift
public struct Box: ZPLElement {
    public init(at position: Position, width: Dimension, height: Dimension)

    public func thickness(_ thickness: Dimension) -> Self  // border thickness
    public func filled() -> Self                           // solid fill
    public func cornerRadius(_ radius: Int) -> Self        // 0-8 (unitless)
    public func white() -> Self                            // white/reverse
}

// Convenience for lines
public struct HorizontalLine: ZPLElement {
    public init(at position: Position, length: Dimension, thickness: Dimension = 2)
}

public struct VerticalLine: ZPLElement {
    public init(at position: Position, length: Dimension, thickness: Dimension = 2)
}

public struct Circle: ZPLElement {
    public init(at position: Position, diameter: Dimension)

    public func thickness(_ thickness: Dimension) -> Self
    public func filled() -> Self
    public func white() -> Self
}

public struct Ellipse: ZPLElement {
    public init(at position: Position, width: Dimension, height: Dimension)

    public func thickness(_ thickness: Dimension) -> Self
    public func filled() -> Self
    public func white() -> Self
}

public struct DiagonalLine: ZPLElement {
    public init(at position: Position, width: Dimension, height: Dimension)

    public func thickness(_ thickness: Dimension) -> Self
    public func direction(_ direction: DiagonalDirection) -> Self  // .rightLeaning or .leftLeaning
    public func white() -> Self
}
```

**Output:**
```zpl
^FO100,100^GB200,150,3,B,2^FS
^FO100,100^GC100,2,B^FS
^FO100,100^GE200,100,3,B^FS
^FO100,100^GD150,150,2,B,R^FS
```

### 4.7 Result Builder

```swift
@resultBuilder
public struct ZPLBuilder {
    public static func buildBlock(_ components: ZPLElement...) -> [ZPLElement]
    public static func buildOptional(_ component: [ZPLElement]?) -> [ZPLElement]
    public static func buildEither(first: [ZPLElement]) -> [ZPLElement]
    public static func buildEither(second: [ZPLElement]) -> [ZPLElement]
    public static func buildArray(_ components: [[ZPLElement]]) -> [ZPLElement]
    public static func buildExpression(_ expression: ZPLElement?) -> [ZPLElement]  // Handles failable barcodes
}
```

Enables:
```swift
ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
    Text("Header", at: .dots(50, 20))

    if showBarcode {
        Barcode128(sku, at: .dots(50, 60))  // nil if invalid, silently omitted
    }

    for (index, item) in items.enumerated() {
        Text(item, at: .dots(50, 100 + index * 30))
    }

    // Explicit handling of failable barcode with fallback
    if let barcode = Code39(userInput, at: .dots(50, 200)) {
        barcode.height(80)
    } else {
        Text("Invalid barcode data", at: .dots(50, 200))
    }
}
```

### 4.8 Label Configuration

```swift
public struct ZPLLabel {
    // Additional configuration modifiers
    public func printQuantity(_ count: Int) -> Self
    public func defaultFont(_ font: ZPLFont, height: Int) -> Self
    public func labelHome(_ x: Int, _ y: Int) -> Self
    public func printDarkness(_ level: Int) -> Self  // 0-30
}
```

---

## 5. Error Handling

### 5.1 Design Philosophy

The library should be hard to misuse. `render()` is **non-throwing** to keep the API simple. Errors are handled at the appropriate layer:

| Error Type | Handling Strategy |
|------------|-------------------|
| Invalid enum values | Compile-time prevention via strong typing |
| Out-of-range numeric values | Clamped at render time, logged in DEBUG |
| Invalid barcode data | Failable initializer returns `nil` |
| Special characters in text | Auto-escaped, no user action needed |

### 5.2 Compile-Time Prevention

- Strong typing prevents invalid enum values
- Required parameters are non-optional
- Position/size use appropriate numeric types
- Barcode initializers are failable for format-restricted types

### 5.3 Runtime Validation

```swift
// Values outside valid ranges are clamped
// Logged via os_log in DEBUG builds, silent in release
Barcode128("test", at: .dots(50, 50))?
    .moduleWidth(15)  // Clamped to 10, logs warning in DEBUG

// Invalid barcode data returns nil at creation time
let barcode = Code39("invalid@chars!", at: .dots(0, 0))  // nil

// Special characters are auto-escaped using ^FH + _XX hex encoding
Text("Price: $5.00 (~10% off)", at: .dots(0, 0))
// Renders: ^FH^FDPrice: $5.00 (_7e10_25 off)^FS
```

### 5.4 Barcode Validation

| Barcode Type | Initializer | Valid Characters |
|--------------|-------------|------------------|
| `Barcode128` | `init?` | ASCII 0-127 (validates subset compatibility) |
| `Code39` | `init?` | A-Z, 0-9, space, - . $ / + % |
| `QRCode` | `init` | Any (non-failable) |
| `DataMatrix` | `init` | Any (non-failable) |
| `PDF417` | `init` | Any (non-failable) |
| `Interleaved2of5` | `init?` | Digits 0-9 only |

### 5.5 Text Handling

- **No length limit enforced.** Practical limits (~3KB per field) are documented but not enforced. Trust the user.
- **Auto-escaping:** All text fields automatically use `^FH` (field hex) mode. Characters `^`, `~`, and non-ASCII are hex-encoded as `_XX`.
- **User writes:** `"50% off (limited ~time)"`
- **Library emits:** `^FH^FD50_25 off (limited _7etime)^FS`

---

## 6. Testing Strategy

### 6.0 Local-First Testing Requirement

**All tests must run locally without network dependencies.** This is a hard requirement.

- No external APIs (Labelary, etc.)
- No cloud services
- No authentication or API keys
- CI runs the exact same commands as local development

**Local test commands:**

```bash
# Run all Swift tests (unit + golden file)
swift test

# Run visual regression tests
swift test --filter VisualTests
cd Tests/VisualTestHarness && npm test

# Run everything
swift test && cd Tests/VisualTestHarness && npm test
```

**Prerequisites:**
- Swift 6.2+
- Node.js 22+ (for visual test harness)

### 6.0.1 AI-Assisted Development Workflow

During development with Claude Code, the following feedback loop is available:

1. Claude generates ZPL using the library
2. Claude runs zpl-renderer-js to render PNG
3. Claude reads the PNG and visually verifies the output
4. Claude iterates if the rendering doesn't match expectations

This enables rapid prototyping and validation without requiring manual inspection at every step. Claude can verify that labels render correctly, catch visual regressions, and suggest fixes based on what the rendered output actually looks like.

### 6.1 Unit Tests (XCTest)

Using XCTest framework:
- Every element type has render tests
- Modifier chains produce expected output
- Edge cases (empty strings, max values, special characters)
- Position and Dimension unit conversions (inches, mm → dots)

```swift
import XCTest
@testable import ZPLKit

final class ZPLKitTests: XCTestCase {
    func testTextRendersCorrectly() {
        let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
            Text("Hello", at: .inches(0.5, 0.5))
        }
        XCTAssertTrue(label.render().contains("^FDHello^FS"))
    }
}
```

### 6.2 Visual Testing (zpl-renderer-js)

Automated visual regression testing using zpl-renderer-js to render ZPL to PNG and compare against baselines.

**Infrastructure:**

```
Tests/
├── ZPLKitTests/
│   └── VisualTests.swift       # Generates ZPL files
└── VisualTestHarness/
    ├── package.json
    ├── render.js               # Batch render ZPL → PNG
    ├── compare.js              # Pixel diff against baselines
    ├── fixtures/
    │   └── *.zpl               # Generated by Swift tests
    ├── output/
    │   └── *.png               # Rendered images
    └── baselines/
        └── *.png               # Golden images (committed)
```

**Test matrix:**

| Dimension | Values |
|-----------|--------|
| DPI | 203, 300 |
| Elements | Text, TextBlock, Barcode128, QRCode, Code39, DataMatrix, Box, Lines |
| Modifiers | rotation (0°, 90°, 180°, 270°), reversed, font sizes |
| Units | dots, inches, mm |
| Edge cases | empty text, max barcode length, special characters, boundary positions |

**Standard label sizes for testing:**

| Size | Use Case |
|------|----------|
| 4" x 6" | Shipping labels (UPS, FedEx, USPS, Amazon) |
| 2" x 1" | Barcodes, SKUs, product labels, small asset tags |
| 4" x 2" | Shipping manifest lines, inventory, price marking |
| 4" x 3" | Warehouse bins, medium asset tags, pallet labels |
| 4" x 4" | QR codes, square labels, bin identification |

Each element type should have visual tests at multiple label sizes to verify correct positioning and scaling.

**Workflow:**

1. Swift tests generate `.zpl` files to `Tests/VisualTestHarness/fixtures/`
2. Node script renders all `.zpl` → `.png` using zpl-renderer-js
3. Pixel comparison against baseline images (pixelmatch, threshold ~0.1%)
4. CI fails if diff exceeds threshold; outputs diff image for review

**Scripts:**

```json
// package.json
{
  "scripts": {
    "render": "node render.js",
    "compare": "node compare.js",
    "test": "npm run render && npm run compare",
    "update-baselines": "cp output/*.png baselines/"
  },
  "dependencies": {
    "zpl-renderer-js": "^1.0.0",
    "pixelmatch": "^5.3.0",
    "pngjs": "^7.0.0"
  }
}
```

**CI integration:**

```yaml
visual-tests:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: swift-actions/setup-swift@v2
      with:
        swift-version: "6.2"
    - uses: actions/setup-node@v4
      with:
        node-version: "22"
    - run: swift test --filter VisualTests
    - run: cd Tests/VisualTestHarness && npm ci && npm test
    - uses: actions/upload-artifact@v4
      if: failure()
      with:
        name: visual-diff
        path: Tests/VisualTestHarness/output/
```

**Baseline management:**
- Baseline images committed to repo in `Tests/VisualTestHarness/baselines/`
- To update baselines: `npm run update-baselines`, review changes, commit
- PR reviewers can inspect baseline changes via GitHub's image diff

### 6.3 Golden File Tests (ZPL String)

```swift
func testBasicLabel() {
    let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
        Text("Test", at: .dots(50, 50))
    }

    let expected = """
    ^XA
    ^PW812
    ^LL406
    ^FO50,50^A0N,30,30^FDTest^FS
    ^XZ
    """

    XCTAssertEqual(label.render(prettyPrint: true), expected)
}
```

---

## 7. Package Structure

```
ZPLKit/
├── Package.swift
├── CHANGELOG.md
├── .github/
│   └── workflows/
│       └── ci.yml
├── Sources/
│   └── ZPLKit/
│       ├── ZPLLabel.swift           # Main entry point
│       ├── ZPLBuilder.swift         # Result builder
│       ├── ZPLElement.swift         # Protocol
│       ├── ZPLRenderContext.swift   # DPI, unit conversion
│       ├── Elements/
│       │   ├── Text.swift
│       │   ├── TextBlock.swift
│       │   ├── Barcode128.swift
│       │   ├── QRCode.swift
│       │   ├── Code39.swift
│       │   ├── DataMatrix.swift
│       │   ├── Box.swift
│       │   └── Line.swift
│       ├── Types/
│       │   ├── Position.swift
│       │   ├── Dimension.swift
│       │   ├── Rotation.swift
│       │   ├── DPI.swift
│       │   └── ZPLFont.swift
│       └── Internal/
│           └── StringEscaping.swift
├── Tests/
│   ├── ZPLKitTests/
│   │   ├── TextTests.swift
│   │   ├── TextBlockTests.swift
│   │   ├── BarcodeTests.swift
│   │   ├── BoxTests.swift
│   │   ├── DimensionTests.swift
│   │   ├── VisualTests.swift
│   │   ├── IntegrationTests.swift
│   │   └── Fixtures/
│   │       └── golden/              # ZPL string snapshots
│   └── VisualTestHarness/
│       ├── package.json
│       ├── render.js
│       ├── compare.js
│       ├── fixtures/                # Generated .zpl files
│       ├── output/                  # Rendered .png files
│       └── baselines/               # Golden .png images
└── README.md
```

---

## 8. Documentation

### 8.1 README.md

- One-paragraph description
- Installation (SPM)
- Quick start example (complete working label in <20 lines)
- Link to full docs

### 8.2 DocC Documentation

- Every public type/method has doc comments
- Code examples for each element
- "Common Patterns" article
- "ZPL Reference" article linking to Zebra docs

### 8.3 Examples

Separate `Examples/` directory with:
- BasicLabel.swift
- ShippingLabel.swift
- InventoryTag.swift
- PartsBinLabel.swift

### 8.4 CHANGELOG.md

Keep a Changelog format (https://keepachangelog.com):
- `Added` for new features
- `Changed` for changes in existing functionality
- `Deprecated` for soon-to-be removed features
- `Removed` for now removed features
- `Fixed` for bug fixes
- `Security` for vulnerability fixes

---

## 9. CI/CD

### 9.1 GitHub Actions

**On pull request and push to main:**
- Build on macOS (latest) and Linux (Ubuntu)
- Run test suite via Swift Testing
- Check for API breaking changes (`swift package diagnose-api-breaking-changes`)

**On release tag:**
- Validate package can be resolved
- Generate DocC documentation

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main, master]
  pull_request:
    branches: [main, master]

jobs:
  test:
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: swift-actions/setup-swift@v2
        with:
          swift-version: "6.2"
      - run: swift build
      - run: swift test
```

---

## 10. Distribution

### 10.1 Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/jonathanspiva/ZPLKit.git", from: "1.0.0")
]
```

### 10.2 Platform Support

- iOS 15+
- macOS 12+
- tvOS 15+ (why not)
- watchOS 8+ (labels from your wrist!)
- Linux (server-side label generation)

### 10.3 Versioning

- Semantic versioning
- Public API stability from 1.0.0
- Deprecation warnings for one major version before removal

### 10.4 License

MIT

---

## 11. Non-Goals (Explicit)

Things this library will **never** do:

1. **Printer communication** — Use Foundation's `NWConnection` or Zebra SDK
2. **Printer discovery** — Use Bonjour/mDNS yourself
3. **ZPL parsing** — This is a generator, not a parser
4. **Preview rendering** — Use Labelary API or zpl-renderer-js
5. **Image encoding** — Separate package concern
6. **Database of printer models** — Too volatile, user's responsibility
7. **Print spooling** — OS concern

---

## 12. Success Criteria

The library is successful if:

1. A developer can generate a working label in < 5 minutes after reading the README
2. The API is discoverable via autocomplete without reading docs
3. Generated ZPL works on any ZPL II compatible printer
4. Zero runtime crashes from normal use
5. Test suite passes with zpl-renderer-js rendering

---

## 13. Resolved Decisions

| Question | Decision |
|----------|----------|
| Naming | `ZPLKit` |
| Swift version | Swift 6.0+ with strict concurrency, XCTest framework |
| Barcode scope (v1) | Code128, QR, Code39, DataMatrix |
| Image support | Someday (no commitment) |
| `render()` behavior | Non-throwing, clamp with `os_log` in DEBUG |
| Default font | Font 0, height 30, width 30 |
| Barcode validation | Failable initializers for charset-restricted types |
| Text limits | None enforced, documented only |
| Special characters | Auto-escape via `^FH` + `_XX` hex encoding |
| Unit handling | `Dimension` type supports `.dots()`, `.inches()`, `.mm()` everywhere; `ExpressibleByIntegerLiteral` allows bare integers as dots |
| License | MIT |
| GitHub location | `jonathanspiva/ZPLKit` |
| Testing | Local-first; all tests runnable offline with no external dependencies |
| Visual testing | zpl-renderer-js (local Node.js); no Labelary API |

## 14. Open Questions

*None at this time.*

---

## 15. References

- [ZPL II Programming Guide](https://www.zebra.com/content/dam/support-dam/en/documentation/unrestricted/guide/software/zpl-zbi2-pg-en.pdf)
- [swift-zpl](https://github.com/scchn/swift-zpl) — Existing Swift ZPL library (command-oriented API)
- [BinaryKits.Zpl](https://github.com/BinaryKits/BinaryKits.Zpl) — .NET library, architecture reference
- [Labelary Docs](https://labelary.com/docs.html) — Command support matrix
- [Zebrash](https://github.com/ingridhq/zebrash) — Test renderer
- [zpl-renderer-js](https://github.com/Fabrizz/zpl-renderer-js) — Browser/Node renderer
