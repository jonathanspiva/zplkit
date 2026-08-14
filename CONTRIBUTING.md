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
│   └── Internal/     # String escaping utilities
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
└── VisualTestHarness/    # 124 ZPL fixtures + comparison tools

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

> **Xcode 27 beta: `swift test` does not run the whole suite.** On the Xcode 27
> beta toolchain (confirmed on 27A5218g / Swift 6.4, 2026-08-14), a bare
> `swift test` executes only the **first** test target and still exits 0. It
> reports "244 tests in 6 suites passed" when the package actually has **670
> tests in 73 suites**. The other three targets are silently skipped. All 670
> pass when each target is run explicitly, and the stable Swift 6.3 toolchain
> runs all 670 from a bare `swift test`, so this is a toolchain bug rather than
> a package problem. On stable you can just run `swift test`; on the beta, run
> each target:
>
> ```bash
> for t in ZPLKitTests ZPLKitRendererTests ZPLKitVerifierTests ZPLKitPrinterTests; do
>   swift test --filter "$t"
> done
> ```
>
> Note that `swift test --filter` **also exits 0 when a filter matches nothing**
> ("No matching test cases were run"), so check the reported test counts.
>
> One other beta artifact: `swift build` warns that
> `Sources/ZPLKit/Documentation.docc` is an "unhandled file". The stable
> toolchain handles the catalog correctly. It is only a warning, so do not
> "fix" it by declaring the catalog as a resource.

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
- **Add protocol conformances**: Codable, Equatable, Hashable where appropriate

### Documentation

- All public types and methods need doc comments
- Use `///` for documentation, `//` for implementation notes
- Include code examples in doc comments for complex APIs

### Naming

- Types: `PascalCase` (e.g., `PrinterStatus`, `BarcodeSymbology`)
- Methods/properties: `camelCase` (e.g., `queryStatus()`, `isPaperOut`)
- Files: Match the primary type they contain

### Example Element Structure

```swift
/// A barcode element that renders as ZPL `^BC` command.
public struct Barcode128: ZPLElement, Sendable, Equatable, Hashable, Codable {
    public let data: String
    public let position: Position
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
2. **Conform to protocols**: `ZPLElement`, `Sendable`, `Equatable`, `Hashable`, `Codable`
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
