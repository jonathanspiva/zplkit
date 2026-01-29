import Vision

/// Barcode symbology types supported by ZPLVerifier.
///
/// These map to Vision framework's `VNBarcodeSymbology` types that are
/// available on macOS 12+.
public enum BarcodeSymbology: String, Sendable, Hashable, CaseIterable {
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
