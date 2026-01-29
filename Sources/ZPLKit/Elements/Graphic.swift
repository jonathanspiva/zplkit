#if canImport(CoreGraphics)
import CoreGraphics
import Foundation

/// A graphic element that renders a monochrome image using ^GF (Graphic Field).
///
/// Example using SF Symbols (macOS 11+/iOS 13+):
/// ```swift
/// #if canImport(AppKit)
/// import AppKit
/// let symbol = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)!
/// let cgImage = symbol.cgImage(forProposedRect: nil, context: nil, hints: nil)!
/// #endif
///
/// ZPLLabel(width: 4, height: 2) {
///     Graphic(cgImage, at: .dots(50, 50), width: .dots(100))
/// }
/// ```
public struct Graphic: ZPLElement, Equatable, Hashable {
    private let image: CGImage
    private let position: Position
    private let targetWidth: Dimension
    private let targetHeight: Dimension?
    private let invertColors: Bool

    /// Creates a graphic element from a CGImage.
    /// - Parameters:
    ///   - image: The source image (will be converted to monochrome).
    ///   - position: The position on the label.
    ///   - width: The target width for the graphic.
    ///   - height: The target height (optional, maintains aspect ratio if nil).
    ///   - invert: If true, inverts black/white (useful for dark symbols on light backgrounds).
    public init(_ image: CGImage, at position: Position, width: Dimension, height: Dimension? = nil, invert: Bool = false) {
        self.image = image
        self.position = position
        self.targetWidth = width
        self.targetHeight = height
        self.invertColors = invert
    }

    public func render(context: ZPLRenderContext) -> String {
        let pos = position.resolve(dpi: context.dpi)
        let width = targetWidth.resolve(dpi: context.dpi)
        let height: Int
        if let h = targetHeight {
            height = h.resolve(dpi: context.dpi)
        } else {
            // Maintain aspect ratio
            let aspectRatio = Double(image.height) / Double(image.width)
            height = Int(Double(width) * aspectRatio)
        }

        // Render image to monochrome bitmap
        guard let bitmapData = renderToMonochrome(width: width, height: height) else {
            return "^FX Graphic render failed ^FS"
        }

        // Convert to ASCII hex
        let hexData = bitmapToHex(bitmapData, width: width, height: height)

        // Calculate ZPL parameters
        let bytesPerRow = (width + 7) / 8  // Round up to nearest byte
        let totalBytes = bytesPerRow * height

        // ^GF format: ^GFa,b,c,d,data
        // a = compression type (A = ASCII hex)
        // b = binary byte count
        // c = graphic field count (total bytes)
        // d = bytes per row
        return "^FO\(pos.x),\(pos.y)^GFA,\(totalBytes),\(totalBytes),\(bytesPerRow),\(hexData)^FS"
    }

    private func renderToMonochrome(width: Int, height: Int) -> [UInt8]? {
        // Create grayscale context
        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
              let cgContext = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.none.rawValue
              ) else {
            return nil
        }

        // White background
        cgContext.setFillColor(gray: 1.0, alpha: 1.0)
        cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Draw image
        cgContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get pixel data
        guard let data = cgContext.data else { return nil }
        let pixelData = data.bindMemory(to: UInt8.self, capacity: width * height)

        // Convert to 1-bit monochrome (packed bytes)
        let bytesPerRow = (width + 7) / 8
        var monochrome = [UInt8](repeating: 0, count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = y * width + x
                let gray = pixelData[pixelIndex]

                // Threshold at 128 (adjust if needed)
                let isBlack = invertColors ? (gray >= 128) : (gray < 128)

                if isBlack {
                    let byteIndex = y * bytesPerRow + (x / 8)
                    let bitIndex = 7 - (x % 8)  // MSB first
                    monochrome[byteIndex] |= (1 << bitIndex)
                }
            }
        }

        return monochrome
    }

    private func bitmapToHex(_ data: [UInt8], width: Int, height: Int) -> String {
        // Convert each byte to 2 hex characters
        return data.map { String(format: "%02X", $0) }.joined()
    }
}
#endif
