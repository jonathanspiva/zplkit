import Foundation
import ZPLKit

/// Represents a parsed ZPL label ready for rendering
public struct ParsedLabel: Sendable {
    public let width: Int      // dots
    public let height: Int     // dots
    public let elements: [ParsedElement]
    public let printQuantity: Int
    public let printDarkness: Int?
}

/// Base protocol for all parsed elements
public enum ParsedElement: Sendable {
    case text(ParsedText)
    case textBlock(ParsedTextBlock)
    case box(ParsedBox)
    case circle(ParsedCircle)
    case ellipse(ParsedEllipse)
    case diagonalLine(ParsedDiagonalLine)
    case barcode(ParsedBarcode)
}

// MARK: - Text Elements

public struct ParsedText: Sendable {
    public let text: String
    public let x: Int
    public let y: Int
    public let font: String
    public let fontHeight: Int
    public let fontWidth: Int
    public let rotation: String  // N, R, I, B
    public let isReversed: Bool
    public let useBaseline: Bool
}

public struct ParsedTextBlock: Sendable {
    public let text: String
    public let x: Int
    public let y: Int
    public let blockWidth: Int
    public let font: String
    public let fontHeight: Int
    public let fontWidth: Int
    public let maxLines: Int
    public let lineSpacing: Int
    public let alignment: String  // L, C, R, J
    public let hangingIndent: Int
    public let useBaseline: Bool
}

// MARK: - Shape Elements

public struct ParsedBox: Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let thickness: Int
    public let color: String  // B or W
    public let cornerRadius: Int
}

public struct ParsedCircle: Sendable {
    public let x: Int
    public let y: Int
    public let diameter: Int
    public let thickness: Int
    public let color: String  // B or W
}

public struct ParsedEllipse: Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let thickness: Int
    public let color: String  // B or W
}

public struct ParsedDiagonalLine: Sendable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let thickness: Int
    public let color: String  // B or W
    public let direction: String  // R or L
}

// MARK: - Barcode Elements

public struct ParsedBarcode: Sendable {
    public let type: BarcodeType
    public let data: String
    public let x: Int
    public let y: Int
    public let height: Int
    public let moduleWidth: Int
    public let rotation: String
    public let showText: Bool
    public let textAbove: Bool
    public let magnification: Int  // For 2D codes

    public enum BarcodeType: String, Sendable {
        case code128 = "BC"
        case code39 = "B3"
        case qrCode = "BQ"
        case dataMatrix = "BX"
        case pdf417 = "B7"
        case interleaved2of5 = "B2"
        case ean13 = "BE"
        case ean8 = "B8"
        case upcA = "BU"
        case upcE = "B9"
        case aztec = "B0"
        case intelligentMail = "BZ"
    }
}
