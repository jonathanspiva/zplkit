import Foundation
import CoreGraphics
import CoreText
import ZPLKit

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
                guard let provider = CGDataProvider(data: data as CFData),
                      let cgFont = CGFont(provider) else {
                    return nil
                }
                return CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
            }
        }
    }

    /// Font mappings for ZPL fonts
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
    /// - Parameters:
    ///   - zpl: The ZPL string to render
    ///   - dpi: The DPI setting (affects pixel dimensions)
    /// - Returns: A RenderResult containing the image and performance metrics
    public func render(_ zpl: String, dpi: DPI = .dpi203) throws -> RenderResult {
        let parseStart = CFAbsoluteTimeGetCurrent()
        let parsed = try ZPLParser.parse(zpl)
        let parseEnd = CFAbsoluteTimeGetCurrent()

        let renderStart = CFAbsoluteTimeGetCurrent()
        let image = try CoreGraphicsRenderer.render(
            parsed,
            dpi: dpi,
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
    /// - Parameters:
    ///   - zpl: The ZPL string to render
    ///   - dpi: The DPI setting (affects pixel dimensions)
    /// - Returns: PNG data and performance metrics
    public func renderToPNG(_ zpl: String, dpi: DPI = .dpi203) throws -> (data: Data, metrics: RenderMetrics) {
        let result = try render(zpl, dpi: dpi)

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

