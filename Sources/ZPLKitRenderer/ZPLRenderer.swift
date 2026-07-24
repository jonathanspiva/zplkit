import Foundation
import CoreGraphics
import CoreText
import os
import ZPLKit

/// Thread-safe cache for size-independent `CGFont` objects built from bundled TTF data.
///
/// Building a `CGFont` from a `CGDataProvider` is relatively expensive and was
/// previously repeated for every text element. The `CGFont` is size-independent
/// (size is applied when deriving a `CTFont`), so we cache one per unique font
/// `Data`. Access is serialized with an `OSAllocatedUnfairLock`, keeping the
/// renderer's clean Sendable story (no unsynchronized mutable static state).
private enum CGFontCache {
    // `CGFont` is not `Sendable`, but it is an immutable, thread-safe CoreGraphics
    // object. We guard all access with a lock and use `nonisolated(unsafe)` to opt
    // out of the Sendable check, keeping the target's clean concurrency story.
    //
    // NSData is hashable by content, and the bundled font Data values are shared
    // `static let`s, so this dictionary stays tiny (typically one entry).
    private static let lock = OSAllocatedUnfairLock()
    nonisolated(unsafe) private static var cache: [NSData: CGFont] = [:]

    static func cgFont(for data: Data) -> CGFont? {
        let key = data as NSData
        lock.lock()
        defer { lock.unlock() }

        if let existing = cache[key] {
            return existing
        }
        guard let provider = CGDataProvider(data: data as CFData),
              let cgFont = CGFont(provider) else {
            return nil
        }
        cache[key] = cgFont
        return cgFont
    }
}

/// A native Swift renderer for ZPL (Zebra Programming Language) code.
/// Renders ZPL strings to images for preview purposes.
public final class ZPLRenderer: Sendable {

    /// Represents a font source - either a system font name or bundled font data
    public enum FontSource: Sendable {
        case system(String)
        case bundled(Data)

        /// Creates a CTFont from this source at the specified size
        func createFont(size: CGFloat) -> CTFont? {
            switch self {
            case .system(let name):
                return CTFontCreateWithName(name as CFString, size, nil)
            case .bundled(let data):
                // Cache the size-independent CGFont; only the sized CTFont is per-call.
                guard let cgFont = CGFontCache.cgFont(for: data) else {
                    return nil
                }
                return CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
            }
        }
    }

    /// Font mappings for ZPL fonts.
    ///
    /// Only three font slots are modeled: `font0` (ZPL Font `0`, the scalable
    /// default), `fontA` (ZPL Font `A`), and `fontDefault` (every other ZPL font
    /// letter `B`-`Z`). The renderer selects among these based on the parsed
    /// `^A` font identifier. This is a preview renderer: it does not bundle the full
    /// set of Zebra bitmap fonts, so any font other than `0`/`A` falls back to
    /// `fontDefault` (Font 0 in the default configuration) and glyph metrics are
    /// approximate for those.
    public struct FontConfiguration: Sendable {
        public var font0: FontSource
        public var fontA: FontSource
        public var fontDefault: FontSource

        /// Default configuration using bundled Roboto Condensed Bold for Font 0
        public static let `default`: FontConfiguration = {
            let robotoSource: FontSource
            if let data = BundledFonts.robotoCondensedBold {
                robotoSource = .bundled(data)
            } else {
                // Fallback to system Helvetica Bold if bundled font unavailable
                robotoSource = .system("Helvetica-Bold")
            }
            return FontConfiguration(
                font0: robotoSource,
                fontA: .system("Menlo"),
                fontDefault: robotoSource
            )
        }()

        /// Configuration using only system fonts (no bundled fonts)
        public static let systemFontsOnly = FontConfiguration(
            font0: .system("Helvetica-Bold"),
            fontA: .system("Menlo"),
            fontDefault: .system("Helvetica-Bold")
        )

        public init(font0: FontSource, fontA: FontSource, fontDefault: FontSource) {
            self.font0 = font0
            self.fontA = fontA
            self.fontDefault = fontDefault
        }

        /// Convenience initializer using system font names
        public init(font0: String, fontA: String, fontDefault: String) {
            self.font0 = .system(font0)
            self.fontA = .system(fontA)
            self.fontDefault = .system(fontDefault)
        }
    }

    /// Access to bundled fonts included with ZPLKitRenderer
    public enum BundledFonts {
        /// Roboto Condensed Bold - closest match to Zebra's CG Triumvirate Bold Condensed (Font 0)
        /// Licensed under SIL Open Font License 1.1
        public static let robotoCondensedBold: Data? = {
            #if SWIFT_PACKAGE
            guard let url = Bundle.module.url(forResource: "RobotoCondensed-Bold", withExtension: "ttf") else {
                return nil
            }
            return try? Data(contentsOf: url)
            #else
            return nil
            #endif
        }()
    }

    /// Performance metrics from a render operation
    public struct RenderMetrics: Sendable {
        public let parseTimeSeconds: Double
        public let renderTimeSeconds: Double
        public var totalTimeSeconds: Double { parseTimeSeconds + renderTimeSeconds }
        public let imageWidth: Int
        public let imageHeight: Int
    }

    /// Result of a render operation
    public struct RenderResult: Sendable {
        public let image: CGImage
        public let metrics: RenderMetrics
    }

    public let fontConfiguration: FontConfiguration

    public init(fontConfiguration: FontConfiguration = .default) {
        self.fontConfiguration = fontConfiguration
    }

    /// Renders a ZPL string to a CGImage.
    ///
    /// Output pixel dimensions are derived from the label's `^PW`/`^LL` dot values
    /// in the ZPL (which the ZPLKit DSL already resolves from DPI when generating
    /// the ZPL), so no DPI parameter is needed here.
    /// - Parameter zpl: The ZPL string to render
    /// - Returns: A RenderResult containing the image and performance metrics
    public func render(_ zpl: String) throws -> RenderResult {
        let parseStart = CFAbsoluteTimeGetCurrent()
        let parsed = try ZPLParser.parse(zpl)
        let parseEnd = CFAbsoluteTimeGetCurrent()

        let renderStart = CFAbsoluteTimeGetCurrent()
        let image = try CoreGraphicsRenderer.render(
            parsed,
            fontConfiguration: fontConfiguration
        )
        let renderEnd = CFAbsoluteTimeGetCurrent()

        let metrics = RenderMetrics(
            parseTimeSeconds: parseEnd - parseStart,
            renderTimeSeconds: renderEnd - renderStart,
            imageWidth: image.width,
            imageHeight: image.height
        )

        return RenderResult(image: image, metrics: metrics)
    }

    /// Renders a ZPL string to PNG data.
    /// - Parameter zpl: The ZPL string to render
    /// - Returns: PNG data and performance metrics
    public func renderToPNG(_ zpl: String) throws -> (data: Data, metrics: RenderMetrics) {
        let result = try render(zpl)

        guard let data = result.image.pngData() else {
            throw ZPLRendererError.pngEncodingFailed
        }

        return (data, result.metrics)
    }
}

/// Errors that can occur during rendering
public enum ZPLRendererError: Error, Sendable {
    case parseError(String)
    case renderError(String)
    case pngEncodingFailed
    case unsupportedCommand(String)
}

