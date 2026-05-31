import Vision

/// Barcode symbology types supported by ZPLVerifier.
///
/// These map to Vision framework's `VNBarcodeSymbology` types that are
/// available on macOS 26+.
@frozen
public enum BarcodeSymbology: String, Sendable, Codable, Hashable, CaseIterable, CustomStringConvertible {
    case aztec
    case code39
    case code39Checksum
    case code39FullASCII
    case code39FullASCIIChecksum
    case code93
    case code93i
    case code128
    case dataMatrix
    case ean8
    case ean13
    case i2of5
    case i2of5Checksum
    case itf14
    case pdf417
    case qr
    case upce

    /// Convert to Vision framework symbology.
    var vnSymbology: VNBarcodeSymbology {
        switch self {
        case .aztec: return .aztec
        case .code39: return .code39
        case .code39Checksum: return .code39Checksum
        case .code39FullASCII: return .code39FullASCII
        case .code39FullASCIIChecksum: return .code39FullASCIIChecksum
        case .code93: return .code93
        case .code93i: return .code93i
        case .code128: return .code128
        case .dataMatrix: return .dataMatrix
        case .ean8: return .ean8
        case .ean13: return .ean13
        case .i2of5: return .i2of5
        case .i2of5Checksum: return .i2of5Checksum
        case .itf14: return .itf14
        case .pdf417: return .pdf417
        case .qr: return .qr
        case .upce: return .upce
        }
    }

    public var description: String {
        switch self {
        case .aztec: return "Aztec"
        case .code39, .code39Checksum, .code39FullASCII, .code39FullASCIIChecksum: return "Code 39"
        case .code93, .code93i: return "Code 93"
        case .code128: return "Code 128"
        case .dataMatrix: return "Data Matrix"
        case .ean8: return "EAN-8"
        case .ean13: return "EAN-13"
        case .i2of5, .i2of5Checksum: return "Interleaved 2 of 5"
        case .itf14: return "ITF-14"
        case .pdf417: return "PDF417"
        case .qr: return "QR Code"
        case .upce: return "UPC-E"
        }
    }

    /// Create from Vision framework symbology.
    init?(vnSymbology: VNBarcodeSymbology) {
        switch vnSymbology {
        case .aztec: self = .aztec
        case .code39: self = .code39
        case .code39Checksum: self = .code39Checksum
        case .code39FullASCII: self = .code39FullASCII
        case .code39FullASCIIChecksum: self = .code39FullASCIIChecksum
        case .code93: self = .code93
        case .code93i: self = .code93i
        case .code128: self = .code128
        case .dataMatrix: self = .dataMatrix
        case .ean8: self = .ean8
        case .ean13: self = .ean13
        case .i2of5: self = .i2of5
        case .i2of5Checksum: self = .i2of5Checksum
        case .itf14: self = .itf14
        case .pdf417: self = .pdf417
        case .qr: self = .qr
        case .upce: self = .upce
        default: return nil
        }
    }
}
