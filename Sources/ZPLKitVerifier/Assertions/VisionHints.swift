#if canImport(Vision) && !os(watchOS)
import Foundation

/// Hints to optimize Vision framework detection based on expectations.
public struct VisionHints: Sendable {
    /// Barcode symbologies expected in the image.
    public var symbologies: Set<BarcodeSymbology>

    /// Custom words to help text recognition.
    public var customWords: Set<String>

    public init(
        symbologies: Set<BarcodeSymbology> = [],
        customWords: Set<String> = []
    ) {
        self.symbologies = symbologies
        self.customWords = customWords
    }

    /// An empty hints instance with no optimizations.
    public static let empty = VisionHints()

    /// Merge multiple hints together.
    public static func merge(_ hints: [VisionHints]) -> VisionHints {
        var symbologies = Set<BarcodeSymbology>()
        var customWords = Set<String>()

        for hint in hints {
            symbologies.formUnion(hint.symbologies)
            customWords.formUnion(hint.customWords)
        }

        return VisionHints(symbologies: symbologies, customWords: customWords)
    }

    /// Merge this hints instance with another.
    public func merging(_ other: VisionHints) -> VisionHints {
        VisionHints(
            symbologies: symbologies.union(other.symbologies),
            customWords: customWords.union(other.customWords)
        )
    }
}
#endif
