import Foundation
import ZPLKit

// MARK: - Parsed Types
//
// The result of `ZPLParser.parse(_:)`: a structured view of a ZPL label for
// rendering, inspection, and analysis tools. These are part of the public API
// and follow semantic versioning like the rest of the package.

/// A parsed ZPL label: its geometry, elements, and print settings.
///
/// Returned by ``ZPLParser/parse(_:)``. Part of the public, semver-stable API.
public struct ParsedLabel: Sendable {
    /// Label width in dots, from `^PW`.
    public let width: Int
    /// Label height in dots, from `^LL`.
    public let height: Int
    /// The label's elements, in the order they appeared in the source.
    public let elements: [ParsedElement]
    /// Number of copies requested by `^PQ`. Defaults to 1.
    public let printQuantity: Int
    /// Darkness set by `^MD`, or `nil` if the label didn't specify one.
    public let printDarkness: Int?
}

/// One parsed element within a ``ParsedLabel``.
///
/// - Note: New cases may be added in future minor releases as support for more
///   ZPL commands is added, so consumers switching over this enum should include
///   a `default` case.
public enum ParsedElement: Sendable {
    /// A single-line text field (`^FD` positioned by `^FO`/`^FT`).
    case text(ParsedText)
    /// A word-wrapped text block (`^FB`).
    case textBlock(ParsedTextBlock)
    /// A rectangle (`^GB`).
    case box(ParsedBox)
    /// A circle (`^GC`).
    case circle(ParsedCircle)
    /// An ellipse (`^GE`).
    case ellipse(ParsedEllipse)
    /// A diagonal line (`^GD`).
    case diagonalLine(ParsedDiagonalLine)
    /// A barcode of any supported symbology.
    case barcode(ParsedBarcode)
    /// An embedded bitmap (`^GF`).
    case graphic(ParsedGraphic)
}

// MARK: - Text Elements

/// A single-line text field.
///
/// All coordinates and sizes are in dots at the label's resolution.
public struct ParsedText: Sendable {
    /// The field data, with any `^FH` hex escapes already decoded.
    public let text: String
    /// Horizontal position, in dots from the left edge.
    public let x: Int
    /// Vertical position, in dots from the top edge.
    public let y: Int
    /// Font identifier, e.g. `"0"` for the scalable default font.
    public let font: String
    /// Character height in dots.
    public let fontHeight: Int
    /// Character width in dots. Zero means "derive from the height".
    public let fontWidth: Int
    /// Field orientation: `"N"` normal, `"R"` rotated 90 degrees clockwise,
    /// `"I"` inverted 180 degrees, `"B"` read bottom-up 270 degrees.
    public let rotation: String
    /// Whether the field prints white-on-black (`^FR`).
    public let isReversed: Bool
    /// True when the field was positioned with `^FT` (origin at the text
    /// baseline) rather than `^FO` (origin at the top-left).
    public let useBaseline: Bool
}

/// A word-wrapped text block (`^FB`).
public struct ParsedTextBlock: Sendable {
    /// The field data, with any `^FH` hex escapes already decoded.
    public let text: String
    /// Horizontal position, in dots from the left edge.
    public let x: Int
    /// Vertical position, in dots from the top edge.
    public let y: Int
    /// Width of the wrapping block, in dots.
    public let blockWidth: Int
    /// Font identifier, e.g. `"0"` for the scalable default font.
    public let font: String
    /// Character height in dots.
    public let fontHeight: Int
    /// Character width in dots. Zero means "derive from the height".
    public let fontWidth: Int
    /// Maximum number of lines the block may occupy.
    public let maxLines: Int
    /// Extra space between lines, in dots.
    public let lineSpacing: Int
    /// Text alignment: `"L"` left, `"C"` centre, `"R"` right, `"J"` justified.
    public let alignment: String
    /// Indent applied to every line after the first, in dots.
    public let hangingIndent: Int
    /// True when the field was positioned with `^FT` rather than `^FO`.
    public let useBaseline: Bool
}

// MARK: - Shape Elements

/// A rectangle (`^GB`), which ZPL also uses to draw straight lines.
public struct ParsedBox: Sendable {
    /// Horizontal position, in dots from the left edge.
    public let x: Int
    /// Vertical position, in dots from the top edge.
    public let y: Int
    /// Width in dots.
    public let width: Int
    /// Height in dots.
    public let height: Int
    /// Border thickness in dots. ZPL strokes the border *inside* the bounds.
    public let thickness: Int
    /// Line colour: `"B"` black or `"W"` white.
    public let color: String
    /// Corner rounding, 0 (square) through 8 (most rounded).
    public let cornerRadius: Int
}

/// A circle (`^GC`).
public struct ParsedCircle: Sendable {
    /// Horizontal position, in dots from the left edge.
    public let x: Int
    /// Vertical position, in dots from the top edge.
    public let y: Int
    /// Outer diameter in dots.
    public let diameter: Int
    /// Border thickness in dots.
    public let thickness: Int
    /// Line colour: `"B"` black or `"W"` white.
    public let color: String
}

/// An ellipse (`^GE`).
public struct ParsedEllipse: Sendable {
    /// Horizontal position, in dots from the left edge.
    public let x: Int
    /// Vertical position, in dots from the top edge.
    public let y: Int
    /// Width in dots.
    public let width: Int
    /// Height in dots.
    public let height: Int
    /// Border thickness in dots.
    public let thickness: Int
    /// Line colour: `"B"` black or `"W"` white.
    public let color: String
}

/// A diagonal line (`^GD`).
public struct ParsedDiagonalLine: Sendable {
    /// Horizontal position, in dots from the left edge.
    public let x: Int
    /// Vertical position, in dots from the top edge.
    public let y: Int
    /// Width of the bounding box, in dots.
    public let width: Int
    /// Height of the bounding box, in dots.
    public let height: Int
    /// Line thickness in dots.
    public let thickness: Int
    /// Line colour: `"B"` black or `"W"` white.
    public let color: String
    /// Slope direction: `"R"` for a right-leaning line (top-left to
    /// bottom-right), `"L"` for a left-leaning one.
    public let direction: String
}

// MARK: - Barcode Elements

/// A barcode field, of any symbology the parser recognises.
public struct ParsedBarcode: Sendable {
    /// Which symbology this is, keyed by its ZPL command.
    public let type: BarcodeType
    /// The encoded payload, with any `^FH` hex escapes already decoded.
    public let data: String
    /// Horizontal position, in dots from the left edge.
    public let x: Int
    /// Vertical position, in dots from the top edge.
    public let y: Int
    /// Bar height in dots. Not meaningful for 2-D symbologies, which size
    /// themselves from ``magnification``.
    public let height: Int
    /// Width of the narrowest bar, in dots (`^BY`).
    public let moduleWidth: Int
    /// Field orientation: `"N"`, `"R"`, `"I"`, or `"B"`. See ``ParsedText/rotation``.
    public let rotation: String
    /// Whether to print the human-readable interpretation line.
    public let showText: Bool
    /// Whether that interpretation line sits above the symbol instead of below.
    public let textAbove: Bool
    /// Module magnification factor for 2-D symbologies (QR, Aztec, Data Matrix).
    public let magnification: Int
    /// True when the field was positioned with `^FT` (origin at the barcode's
    /// bottom-left) rather than `^FO` (top-left).
    public var useBaseline: Bool = false

    /// A barcode symbology, raw-valued by the ZPL command that selects it.
    public enum BarcodeType: String, Sendable {
        /// Code 128 (`^BC`).
        case code128 = "BC"
        /// Code 39 (`^B3`).
        case code39 = "B3"
        /// QR Code (`^BQ`).
        case qrCode = "BQ"
        /// Data Matrix (`^BX`).
        case dataMatrix = "BX"
        /// PDF417 (`^B7`).
        case pdf417 = "B7"
        /// Interleaved 2 of 5 (`^B2`).
        case interleaved2of5 = "B2"
        /// EAN-13 (`^BE`).
        case ean13 = "BE"
        /// EAN-8 (`^B8`).
        case ean8 = "B8"
        /// UPC-A (`^BU`).
        case upcA = "BU"
        /// UPC-E (`^B9`).
        case upcE = "B9"
        /// Aztec (`^B0`).
        case aztec = "B0"
        /// USPS Intelligent Mail (`^BZ` with postal type 3).
        case intelligentMail = "BZ"
    }
}

// MARK: - Graphic Elements

/// An embedded monochrome bitmap (`^GF`).
public struct ParsedGraphic: Sendable {
    /// Horizontal position, in dots from the left edge.
    public let x: Int
    /// Vertical position, in dots from the top edge.
    public let y: Int
    /// How the payload was encoded in the source ZPL.
    public let format: GraphicFormat
    /// Bytes per bitmap row. Each byte carries 8 horizontal pixels, MSB first.
    public let bytesPerRow: Int
    /// Total number of bytes in the decoded bitmap.
    public let totalBytes: Int
    /// The decoded 1-bit-per-pixel bitmap. A set bit is a black dot.
    public let data: [UInt8]

    /// The on-the-wire encoding of a `^GF` payload.
    ///
    /// Whichever form the source used, ``ParsedGraphic/data`` is already decoded.
    public enum GraphicFormat: String, Sendable {
        /// ASCII hex, optionally run-length compressed (`^GFA`).
        case ascii = "A"
        /// Raw binary (`^GFB`).
        case binary = "B"
        /// Base64, optionally zlib-deflated: `:B64:` / `:Z64:` (`^GFC`).
        case compressed = "C"
    }
}
