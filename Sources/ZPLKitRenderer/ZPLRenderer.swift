import Foundation
import CoreGraphics
import ZPLKit

/// A native Swift renderer for ZPL (Zebra Programming Language) code.
/// Renders ZPL strings to images for preview purposes.
public final class ZPLRenderer: Sendable {

    /// Font mappings for ZPL fonts to system fonts
    public struct FontConfiguration: Sendable {
        public var font0: String
        public var fontA: String
        public var fontDefault: String

        public static let `default` = FontConfiguration(
            font0: "Helvetica",
            fontA: "Courier",
            fontDefault: "Helvetica"
        )

        public init(font0: String = "Helvetica", fontA: String = "Courier", fontDefault: String = "Helvetica") {
            self.font0 = font0
            self.fontA = fontA
            self.fontDefault = fontDefault
        }
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

