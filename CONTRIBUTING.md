# Contributing to ZPLKit

Thanks for your interest in contributing to ZPLKit! This document covers the development setup, code style, and PR process.

## Development Setup

### Requirements

- macOS 26+ (for the Vision framework used in tests)
- Swift 6.3 (`swift-tools-version: 6.3`)
- Xcode 26 (or VSCode with the Swift extension pointed at the same toolchain)

> **Heads up:** ZPLKit builds on the current *stable* toolchain. It also builds
> and passes its full suite on the Xcode 27 beta, but that toolchain has two
> bugs worth knowing about before you trust a local run. See the caveat under
> [Running Tests](#running-tests). If you keep both Xcodes installed, select one
> explicitly with `DEVELOPER_DIR`:
>
> ```bash
> export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer       # stable
> export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer  # beta
> ```

### Getting Started

```bash
git clone https://github.com/jonathanspiva/zplkit.git
cd zplkit
swift build
swift test
```

### Project Structure

```
Sources/
├── ZPLKit/           # Core label generation (no dependencies)
│   ├── Elements/     # Text, Barcode128, Box, QRCode, etc.
│   ├── Types/        # DPI, Dimension, Position, Rotation
│   └── Internal/     # String escaping, barcode checksums, character validation
├── ZPLKitRenderer/   # ZPL parsing and PNG rendering
│   ├── Parser/       # ZPL string parsing
│   ├── Barcodes/     # Barcode pattern generation
│   └── Rendering/    # CoreGraphics rendering
├── ZPLKitPrinter/    # Network printing and discovery
└── ZPLKitVerifier/   # Barcode/text verification via Vision

Tests/
├── ZPLKitTests/          # Unit tests for ZPLKit
├── ZPLKitRendererTests/  # Parser and renderer tests
├── ZPLKitPrinterTests/   # Printer communication tests
├── ZPLKitVerifierTests/  # Verification tests
└── VisualTestHarness/    # 125 ZPL fixtures + comparison tools

Tools/
├── RenderFixtures/   # Render all fixtures to PNG
├── VisualTests/      # Generate comparison HTML
├── PrinterTests/     # Network printing integration checks
├── GraphicPrintTest/ # Graphic/image printing checks
├── BarcodePrintTest/ # Prints one sample of every barcode symbology
├── DitherTestPrint/  # Dithering output checks
└── StatusCheck/      # Printer status query checks
```

To print a visual test pass of every barcode symbology to a physical printer
(each label stamped with a traceable ID + timestamp):

```sh
swift run BarcodePrintTest <printer-ip>          # all symbologies
swift run BarcodePrintTest --type qr <printer-ip>  # just one
swift run BarcodePrintTest --help
```

## Running Tests

The test suite uses the **Swift Testing** framework (`@Test`, `#expect`, `#require`, `@Suite`), not XCTest. New tests must be written in that style. Prefer `@Test(arguments:)` parameterized tables for repetitive cases, and `@Test(.disabled("reason"))` for tracked skips.

> **A green `swift test` does not mean the suite ran.** Check the reported test
> counts, not the exit code. The package has **712 tests** in 83 suites:
> ZPLKitTests 190, ZPLKitRendererTests 163, ZPLKitPrinterTests 245,
> ZPLKitVerifierTests 114. On Linux only the core target builds, so a Linux run
> reports 184 (ZPLKitTests minus the six CoreGraphics-gated `Graphic` cases).
>
> CI asserts the total against a FLOOR pinned to the last known count, not a
> loose constant. A loose bound stops catching a dropped test target once the
> suite grows past it, which is a failure that looks exactly like success.
>
> **Counting the output takes care.** From Swift 6.4, SwiftPM defaults to
> `--build-system swiftbuild`, which prints one `Test run with N tests` summary
> **per test target**, where the older (now deprecated) `native` system printed
> a single merged line. So sum the summary lines; do not read the last one:
>
> ```bash
> swift test 2>&1 | grep -oE 'Test run with [0-9]+ test' \
>   | grep -oE '[0-9]+' | awk '{s+=$1} END {print s}'
> ```
>
> Earlier revisions of this file claimed the Xcode 27 beta "runs only some of
> the test targets" (244 of 683, later 408 of 683). **That was a counting bug,
> not a toolchain bug** — those figures are what `tail -1` reads from the
> per-target report. Re-measured on Xcode 27.0 GA: both build systems run the
> whole suite. There is no per-target loop to work around it, and none is
> needed.
>
> **What is still real: no toolchain selected means no tests run, silently.**
> With only the Command Line Tools active (no Xcode selected), every test
> bundle fails to load `Testing.framework`, all four targets report failures,
> and `swift test` **still exits 0**. Select one explicitly:
>
> ```bash
> export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
> ```
>
> Note too that `swift test --filter` **also exits 0 when a filter matches
> nothing** ("No matching test cases were run").
>
> CI guards these by asserting on the output rather than the exit code: it
> fails on `Some test targets reported failures`, and on a total of zero.
>
> **Coverage floors are the real gate.** CI enforces a per-module minimum via
> `Scripts/coverage.sh`, which you can run yourself:
>
> ```bash
> swift test --enable-code-coverage
> Scripts/coverage.sh            # report and enforce
> Scripts/coverage.sh --report   # report only
> ```
>
> The floors are a ratchet: each is the value measured when it was last raised,
> so coverage may rise freely and a drop fails the build. Raise one deliberately
> to lock in an improvement. If you have to lower one, say why in the commit
> message.
>
> This replaced a fixed test-count assertion. A count only says tests
> *executed*, not that they exercise anything, and a fixed bound quietly stops
> catching a dropped test target once the suite grows past it. Coverage catches
> that same failure harder -- a target that stops running takes its module's
> coverage toward zero -- while measuring something worth caring about.

```bash
# All tests (see the caveat above on the Xcode 27 beta)
swift test

# Specific module
swift test --filter ZPLKitTests
swift test --filter ZPLKitRendererTests
swift test --filter ZPLKitPrinterTests
swift test --filter ZPLKitVerifierTests

# Visual comparison (renders fixtures, compares to Labelary)
swift run -c release VisualTests --labelary --score
```

### Reference images

`--score` compares each rendered fixture against a committed reference PNG in
`Tests/VisualTestHarness/reference/`. Those references are Labelary output, and
they are the ground truth the accuracy number is measured against, so a wrong
reference silently corrupts the score rather than failing.

To regenerate one (or all) after adding a fixture or an intentional renderer
change:

```bash
swift run -c release VisualTests --labelary          # writes output-labelary/
cp Tests/VisualTestHarness/output-labelary/<name>.png \
   Tests/VisualTestHarness/reference/<name>.png
swift run -c release VisualTests --score             # confirm the new score
```

Every reference is checked against the label geometry implied by its filename
(`<name>_<width>x<height>_<dpi>.zpl`), and a mismatch fails the run. That check
exists because 12 references sat at 812x1218 (the old `parseDimensions` 4x6
fallback) instead of their true size for months. Because they were compared
against correctly-sized renders they scored *high*, inflating the reported
accuracy. Tolerance is 5%, since Labelary sizes from dots/mm and returns e.g.
1216px for 4in @ 300dpi.

Small labels score lowest (~70% on a 2x0.5) and that is expected, not a bug:
sub-pixel glyph-advance differences shift every following glyph, and on a
406x101 canvas the text is most of the image. Compare the PNGs in
`output-swift/` and `output-labelary/` before assuming a regression.

## Code Style

### General Guidelines

- **No force unwrapping** in library code (tests are OK)
- **Prefer guard** for early returns over nested if-else
- **Use Swift's type system** to prevent invalid states
- **Mark types as Sendable** for Swift 6 concurrency
- **Add protocol conformances**: `Equatable`, `Hashable`, `Sendable` where appropriate

### Documentation

- All public types and methods need doc comments
- Use `///` for documentation, `//` for implementation notes
- Include code examples in doc comments for complex APIs

### Naming

- Types: `PascalCase` (e.g., `PrinterStatus`, `BarcodeSymbology`)
- Methods/properties: `camelCase` (e.g., `queryStatus()`, `isPaperOut`)
- Files: Match the primary type they contain

### Example Element Structure

Stored properties stay `private` and elements are configured through modifiers.
Note that no element conforms to `Codable`: doing so would freeze its stored
properties as a persistence contract.

```swift
/// A barcode element that renders as ZPL `^BC` command.
public struct Barcode128: ZPLElement, Sendable, Equatable, Hashable {
    private let data: String
    private let position: Position
    private var height: Dimension = .dots(100)

    /// Creates a Code 128 barcode. Returns nil if data contains non-ASCII characters.
    public init?(_ data: String, at position: Position) {
        guard data.allSatisfy({ $0.asciiValue != nil }) else { return nil }
        self.data = data
        self.position = position
    }

    /// Sets the barcode height.
    public func height(_ height: Dimension) -> Barcode128 {
        var copy = self
        copy.height = height
        return copy
    }

    public func render(context: ZPLRenderContext) -> String {
        // ZPL generation logic
    }
}
```

## Pull Request Process

### Before Submitting

1. **Run all tests**: `swift test`
2. **Build succeeds**: `swift build`
3. **No warnings**: Fix any compiler warnings
4. **Add tests**: New features need test coverage

### PR Guidelines

- **One feature per PR**: Keep PRs focused and reviewable
- **Descriptive title**: "Add EAN-8 barcode support" not "Update barcodes"
- **Link issues**: Reference any related issues
- **Update docs**: If adding public API, update doc comments

### Commit Messages

Use imperative mood ("Add feature" not "Added feature"):

```
Add EAN-8 barcode element

- Validate 7-8 digit input
- Calculate check digit if not provided
- Add quiet zones for scanner compatibility
```

## Adding a New ZPL Element

1. **Create the element** in `Sources/ZPLKit/Elements/`
2. **Conform to protocols**: `ZPLElement`, `Sendable`, `Equatable`, `Hashable`
3. **Add validation** in the initializer (return nil for invalid input)
4. **Implement `render(context:)`** to generate ZPL commands
5. **Add tests** in `Tests/ZPLKitTests/` using Swift Testing (`@Test` / `#expect`), not XCTest
6. **Add fixtures** in `Tests/VisualTestHarness/fixtures/` if visual testing is relevant
7. **Update fixtures.json** with metadata for new fixtures

## Adding Parser Support

1. **Add parsing logic** in `Sources/ZPLKitRenderer/Parser/`
2. **Add to `ParsedElement` enum** if new element type
3. **Add rendering** in `CoreGraphicsRenderer.swift`
4. **Add round-trip tests** in `ZPLKitRendererTests` (Swift Testing style)
5. **Add verification tests** if barcode (in `ZPLKitRendererTests`)

## Questions?

Open an issue for questions about contributing. We're happy to help!
