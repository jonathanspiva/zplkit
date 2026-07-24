# Contributing to ZPLKit

Thanks for your interest in contributing to ZPLKit! This document covers the development setup, code style, and PR process.

## Development Setup

### Requirements

- macOS 27+ (required for the macOS 27 SDK and the Vision framework used in tests)
- Swift 6.4 (`swift-tools-version: 6.4`)
- Xcode 27 beta (or VSCode with the Swift extension pointed at the same toolchain)

> **Heads up:** ZPLKit targets the macOS 27 SDK / Swift 6.4, which no stable
> Xcode or GitHub-hosted runner carries yet. Until macOS 27 / Xcode 27 ship as
> GA, you need the Xcode 27 **beta**. Point `swift` at it with `DEVELOPER_DIR`
> (the CI does the same):
>
> ```bash
> export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
> ```

### Getting Started

```bash
git clone https://github.com/jonathanspiva/zplkit.git
cd zplkit
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
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

```bash
# All tests
swift test

# Specific module
swift test --filter ZPLKitTests
swift test --filter ZPLKitRendererTests
swift test --filter ZPLKitPrinterTests
swift test --filter ZPLKitVerifierTests

# Visual comparison (renders fixtures, compares to Labelary)
swift run -c release VisualTests --labelary --score
```

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
