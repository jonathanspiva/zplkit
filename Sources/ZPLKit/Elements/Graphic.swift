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
///
/// ## Dithering
///
/// For photographs and gradients, use dithering to produce natural-looking halftones:
///
/// ```swift
/// Graphic(photo, at: .dots(0, 0), width: .inches(2))
///     .dither(.floydSteinberg)
/// ```
///
/// ## Content Mode
///
/// Control how the source image fits into the target dimensions:
///
/// ```swift
/// Graphic(photo, at: .dots(0, 0), width: .inches(2), height: .inches(3))
///     .contentMode(.aspectFill)
/// ```
public struct Graphic: ZPLElement, Equatable, Hashable {
    private let image: CGImage
    private let position: Position
    private let targetWidth: Dimension
    private let targetHeight: Dimension?
    private let invertColors: Bool
    private var ditherMethod: DitherMethod = .none
    private var contentMode: ContentMode = .stretch

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

    /// Sets the dithering method for grayscale-to-monochrome conversion.
    ///
    /// - Parameter method: The dithering algorithm to use.
    /// - Returns: A modified graphic element.
    public func dither(_ method: DitherMethod) -> Graphic {
        var copy = self
        copy.ditherMethod = method
        return copy
    }

    /// Sets how the source image is fitted into the target dimensions.
    ///
    /// - Parameter mode: The content mode to use.
    /// - Returns: A modified graphic element.
    public func contentMode(_ mode: ContentMode) -> Graphic {
        var copy = self
        copy.contentMode = mode
        return copy
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
        // Apply center-crop if aspectFill and we have explicit target dimensions
        let sourceImage: CGImage
        if contentMode == .aspectFill, targetHeight != nil {
            sourceImage = centerCrop(image, targetWidth: width, targetHeight: height)
        } else {
            sourceImage = image
        }

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
        cgContext.draw(sourceImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get pixel data
        guard let data = cgContext.data else { return nil }
        let pixelData = data.bindMemory(to: UInt8.self, capacity: width * height)

        // Apply dithering/thresholding and pack to 1-bit
        let bytesPerRow = (width + 7) / 8
        var monochrome = [UInt8](repeating: 0, count: bytesPerRow * height)

        switch ditherMethod {
        case .none:
            thresholdPack(pixelData, into: &monochrome, width: width, height: height, threshold: 128)
        case .threshold(let t):
            thresholdPack(pixelData, into: &monochrome, width: width, height: height, threshold: t)
        case .floydSteinberg:
            floydSteinbergDither(pixelData, into: &monochrome, width: width, height: height)
        case .atkinson:
            atkinsonDither(pixelData, into: &monochrome, width: width, height: height)
        }

        return monochrome
    }

    // MARK: - Center Crop

    /// Crops the source image to match the target aspect ratio, centered.
    private func centerCrop(_ source: CGImage, targetWidth: Int, targetHeight: Int) -> CGImage {
        let sourceW = Double(source.width)
        let sourceH = Double(source.height)
        let targetAspect = Double(targetWidth) / Double(targetHeight)
        let sourceAspect = sourceW / sourceH

        let cropRect: CGRect
        if sourceAspect > targetAspect {
            // Source is wider: crop sides
            let cropW = sourceH * targetAspect
            let offsetX = (sourceW - cropW) / 2.0
            cropRect = CGRect(x: offsetX, y: 0, width: cropW, height: sourceH)
        } else {
            // Source is taller: crop top/bottom
            let cropH = sourceW / targetAspect
            let offsetY = (sourceH - cropH) / 2.0
            cropRect = CGRect(x: 0, y: offsetY, width: sourceW, height: cropH)
        }

        return source.cropping(to: cropRect) ?? source
    }

    // MARK: - Threshold

    private func thresholdPack(
        _ pixels: UnsafeMutablePointer<UInt8>,
        into monochrome: inout [UInt8],
        width: Int, height: Int,
        threshold: UInt8
    ) {
        let bytesPerRow = (width + 7) / 8
        for y in 0..<height {
            for x in 0..<width {
                let gray = pixels[y * width + x]
                let isBlack = invertColors ? (gray >= threshold) : (gray < threshold)
                if isBlack {
                    let byteIndex = y * bytesPerRow + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    monochrome[byteIndex] |= (1 << bitIndex)
                }
            }
        }
    }

    // MARK: - Floyd-Steinberg Dithering

    private func floydSteinbergDither(
        _ pixels: UnsafeMutablePointer<UInt8>,
        into monochrome: inout [UInt8],
        width: Int, height: Int
    ) {
        // Work in Int16 to handle negative error values
        var buffer = [Int16](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            buffer[i] = Int16(pixels[i])
        }

        let bytesPerRow = (width + 7) / 8

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                let oldPixel = buffer[idx]
                let newPixel: Int16 = oldPixel < 128 ? 0 : 255
                let error = oldPixel - newPixel

                let isBlack = invertColors ? (newPixel != 0) : (newPixel == 0)
                if isBlack {
                    let byteIndex = y * bytesPerRow + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    monochrome[byteIndex] |= (1 << bitIndex)
                }

                // Distribute error to neighbors
                if x + 1 < width {
                    buffer[idx + 1] += error * 7 / 16
                }
                if y + 1 < height {
                    if x > 0 {
                        buffer[idx + width - 1] += error * 3 / 16
                    }
                    buffer[idx + width] += error * 5 / 16
                    if x + 1 < width {
                        buffer[idx + width + 1] += error * 1 / 16
                    }
                }
            }
        }
    }

    // MARK: - Atkinson Dithering

    private func atkinsonDither(
        _ pixels: UnsafeMutablePointer<UInt8>,
        into monochrome: inout [UInt8],
        width: Int, height: Int
    ) {
        var buffer = [Int16](repeating: 0, count: width * height)
        for i in 0..<(width * height) {
            buffer[i] = Int16(pixels[i])
        }

        let bytesPerRow = (width + 7) / 8

        for y in 0..<height {
            for x in 0..<width {
                let idx = y * width + x
                let oldPixel = buffer[idx]
                let newPixel: Int16 = oldPixel < 128 ? 0 : 255
                let error = oldPixel - newPixel
                let portion = error / 8

                let isBlack = invertColors ? (newPixel != 0) : (newPixel == 0)
                if isBlack {
                    let byteIndex = y * bytesPerRow + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    monochrome[byteIndex] |= (1 << bitIndex)
                }

                // Distribute 6/8 of error (intentionally loses 2/8 for lighter result)
                if x + 1 < width {
                    buffer[idx + 1] += portion
                }
                if x + 2 < width {
                    buffer[idx + 2] += portion
                }
                if y + 1 < height {
                    if x > 0 {
                        buffer[idx + width - 1] += portion
                    }
                    buffer[idx + width] += portion
                    if x + 1 < width {
                        buffer[idx + width + 1] += portion
                    }
                }
                if y + 2 < height {
                    buffer[idx + width * 2] += portion
                }
            }
        }
    }

    private func bitmapToHex(_ data: [UInt8], width: Int, height: Int) -> String {
        // Convert each byte to 2 hex characters
        return data.map { String(format: "%02X", $0) }.joined()
    }
}
#endif
