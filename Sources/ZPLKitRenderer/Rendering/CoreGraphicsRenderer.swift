import Foundation
import CoreGraphics
import CoreText
import ZPLKit

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

#if canImport(CoreImage)
import CoreImage
#endif

/// Renders parsed ZPL elements to a CGImage using CoreGraphics
public enum CoreGraphicsRenderer {

    /// Renders a parsed label to a CGImage.
    ///
    /// Output dimensions come from the label's dot values (`ParsedLabel.width`/`.height`);
    /// DPI is not a parameter because the dimensions are already expressed in dots.
    public static func render(
        _ label: ParsedLabel,
        fontConfiguration: ZPLRenderer.FontConfiguration
    ) throws -> CGImage {
        // Clamp dimensions defensively: the parser already bounds `^PW`/`^LL`, but a
        // `ParsedLabel` could be constructed directly. This keeps the context within
        // a sane size regardless of how the label was produced.
        let width = min(max(label.width, 1), RenderLimits.maxDimensionDots)
        let height = min(max(label.height, 1), RenderLimits.maxDimensionDots)

        // Overflow-checked `bytesPerRow` as defense in depth: never let `width * 4`
        // trap.
        let (bytesPerRow, overflowed) = width.multipliedReportingOverflow(by: 4)
        guard !overflowed else {
            throw ZPLRendererError.renderError("Label dimensions too large")
        }

        // Create bitmap context (white background)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ZPLRendererError.renderError("Failed to create graphics context")
        }

        // Fill with white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // CoreGraphics uses bottom-left origin, ZPL uses top-left
        // Flip the coordinate system
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        // Create a single CIContext for the whole render pass (used by 2D barcode
        // generators). Constructing a CIContext is expensive, so we avoid building
        // one per barcode element. `nil` on platforms without CoreImage.
        #if canImport(CoreImage)
        let ciContext = CIContext()
        #endif

        // Render each element
        for element in label.elements {
            switch element {
            case .text(let text):
                renderText(text, in: context, fontConfig: fontConfiguration)

            case .textBlock(let textBlock):
                renderTextBlock(textBlock, in: context, fontConfig: fontConfiguration)

            case .box(let box):
                renderBox(box, in: context)

            case .circle(let circle):
                renderCircle(circle, in: context)

            case .ellipse(let ellipse):
                renderEllipse(ellipse, in: context)

            case .diagonalLine(let line):
                renderDiagonalLine(line, in: context)

            case .barcode(let barcode):
                #if canImport(CoreImage)
                try renderBarcode(barcode, in: context, ciContext: ciContext)
                #else
                try renderBarcode(barcode, in: context)
                #endif

            case .graphic(let graphic):
                renderGraphic(graphic, in: context)
            }
        }

        guard let image = context.makeImage() else {
            throw ZPLRendererError.renderError("Failed to create image from context")
        }

        return image
    }

    // MARK: - Text Rendering

    /// Selects the `FontSource` for a parsed ZPL font identifier.
    ///
    /// ZPL font slots map to `FontConfiguration` as follows:
    /// - `"0"` -> `font0` (Zebra's scalable Font 0; bundled by default).
    /// - `"A"` -> `fontA` (the built-in bitmap Font A slot).
    /// - anything else -> `fontDefault`.
    ///
    /// Only these three slots are modeled. Any ZPL font letter that is not `0` or `A`
    /// (B-Z and the Unicode fonts) falls back to `fontDefault`, which is Font 0 in the
    /// default configuration. This is a preview renderer: it does not ship the full
    /// set of Zebra bitmap fonts, so glyph metrics are approximate for non-Font-0 text.
    private static func fontSource(
        for fontIdentifier: String,
        config: ZPLRenderer.FontConfiguration
    ) -> ZPLRenderer.FontSource {
        switch fontIdentifier {
        case "0": return config.font0
        case "A": return config.fontA
        default: return config.fontDefault
        }
    }

    private static func renderText(_ text: ParsedText, in context: CGContext, fontConfig: ZPLRenderer.FontConfiguration) {
        let fontSize = CGFloat(text.fontHeight)

        guard let font = fontSource(for: text.font, config: fontConfig).createFont(size: fontSize) else {
            return // Skip rendering if font unavailable
        }

        let color = text.isReversed ? CGColor(red: 1, green: 1, blue: 1, alpha: 1) : CGColor(red: 0, green: 0, blue: 0, alpha: 1)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text.text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)

        context.saveGState()

        // Handle rotation
        let x = CGFloat(text.x)
        let y = CGFloat(text.y)

        // Move to text position
        context.translateBy(x: x, y: y)

        // Get text bounds for proper positioning
        let bounds = CTLineGetBoundsWithOptions(line, [])

        // Apply ZPL rotation
        switch text.rotation {
        case "R":
            context.rotate(by: -.pi / 2)
        case "I":
            context.rotate(by: -.pi)
        case "B":
            context.rotate(by: .pi / 2)
        default:
            break
        }

        // Un-flip for text rendering (context is flipped, but CoreText expects unflipped)
        // This makes text render right-side up
        context.scaleBy(x: 1, y: -1)

        // If reversed, draw background box
        if text.isReversed {
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: -bounds.height, width: bounds.width, height: bounds.height))
        }

        // Position text at baseline (after flip, y is inverted)
        context.textPosition = CGPoint(x: 0, y: -bounds.height - bounds.minY)
        CTLineDraw(line, context)

        context.restoreGState()
    }

    private static func renderTextBlock(_ textBlock: ParsedTextBlock, in context: CGContext, fontConfig: ZPLRenderer.FontConfiguration) {
        let fontSize = CGFloat(textBlock.fontHeight)

        guard let font = fontSource(for: textBlock.font, config: fontConfig).createFont(size: fontSize) else {
            return // Skip rendering if font unavailable
        }

        // Create paragraph style using CoreText
        let alignment: CTTextAlignment
        switch textBlock.alignment {
        case "C":
            alignment = .center
        case "R":
            alignment = .right
        case "J":
            alignment = .justified
        default:
            alignment = .left
        }

        // Pass the alignment value through a scoped pointer so it outlives the
        // CTParagraphStyleSetting initializer (avoids a temporary-pointer warning).
        let paragraphStyle = withUnsafeBytes(of: alignment) { alignmentBytes in
            let setting = CTParagraphStyleSetting(
                spec: .alignment,
                valueSize: MemoryLayout<CTTextAlignment>.size,
                value: alignmentBytes.baseAddress!
            )
            return [setting].withUnsafeBufferPointer { buffer in
                CTParagraphStyleCreate(buffer.baseAddress!, buffer.count)
            }
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: textBlock.text, attributes: attributes)

        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
        // Defense in depth: clamp the block-height multiplication so it cannot trap
        // even if a `ParsedTextBlock` carries unbounded values.
        let clampedLines = min(max(textBlock.maxLines, 1), RenderLimits.maxTextBlockLines)
        let clampedFontHeight = min(max(textBlock.fontHeight, 0), RenderLimits.maxFontHeight)
        let frameHeight = CGFloat(clampedLines) * CGFloat(clampedFontHeight) * 2

        context.saveGState()

        // Move to text block position
        context.translateBy(x: CGFloat(textBlock.x), y: CGFloat(textBlock.y))

        // Un-flip for CoreText (which expects bottom-left origin)
        context.scaleBy(x: 1, y: -1)

        // Create path in local coordinates
        let path = CGPath(rect: CGRect(x: 0, y: -frameHeight,
                                        width: CGFloat(textBlock.blockWidth),
                                        height: frameHeight),
                         transform: nil)
        let frame = CTFramesetterCreateFrame(frameSetter, CFRange(location: 0, length: 0), path, nil)

        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    // MARK: - Shape Rendering

    private static func renderBox(_ box: ParsedBox, in context: CGContext) {
        let rect = CGRect(x: box.x, y: box.y, width: box.width, height: box.height)
        let color = box.color == "W" ?
            CGColor(red: 1, green: 1, blue: 1, alpha: 1) :
            CGColor(red: 0, green: 0, blue: 0, alpha: 1)

        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(CGFloat(box.thickness))

        if box.cornerRadius > 0 {
            let radius = CGFloat(box.cornerRadius)
            let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

            if box.thickness >= min(box.width, box.height) / 2 {
                context.addPath(path)
                context.fillPath()
            } else {
                context.addPath(path)
                context.strokePath()
            }
        } else {
            if box.thickness >= min(box.width, box.height) / 2 {
                context.fill(rect)
            } else {
                context.stroke(rect)
            }
        }
    }

    private static func renderCircle(_ circle: ParsedCircle, in context: CGContext) {
        let rect = CGRect(x: circle.x, y: circle.y, width: circle.diameter, height: circle.diameter)
        let color = circle.color == "W" ?
            CGColor(red: 1, green: 1, blue: 1, alpha: 1) :
            CGColor(red: 0, green: 0, blue: 0, alpha: 1)

        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(CGFloat(circle.thickness))

        if circle.thickness >= circle.diameter / 2 {
            context.fillEllipse(in: rect)
        } else {
            context.strokeEllipse(in: rect)
        }
    }

    private static func renderEllipse(_ ellipse: ParsedEllipse, in context: CGContext) {
        let rect = CGRect(x: ellipse.x, y: ellipse.y, width: ellipse.width, height: ellipse.height)
        let color = ellipse.color == "W" ?
            CGColor(red: 1, green: 1, blue: 1, alpha: 1) :
            CGColor(red: 0, green: 0, blue: 0, alpha: 1)

        context.setStrokeColor(color)
        context.setFillColor(color)
        context.setLineWidth(CGFloat(ellipse.thickness))

        if ellipse.thickness >= min(ellipse.width, ellipse.height) / 2 {
            context.fillEllipse(in: rect)
        } else {
            context.strokeEllipse(in: rect)
        }
    }

    private static func renderDiagonalLine(_ line: ParsedDiagonalLine, in context: CGContext) {
        let color = line.color == "W" ?
            CGColor(red: 1, green: 1, blue: 1, alpha: 1) :
            CGColor(red: 0, green: 0, blue: 0, alpha: 1)

        context.setStrokeColor(color)
        context.setLineWidth(CGFloat(line.thickness))

        let startX = CGFloat(line.x)
        let startY = CGFloat(line.y)
        let endX = startX + CGFloat(line.width)
        let endY = startY + CGFloat(line.height)

        context.beginPath()
        if line.direction == "L" {
            // Left-leaning: top-right to bottom-left
            context.move(to: CGPoint(x: endX, y: startY))
            context.addLine(to: CGPoint(x: startX, y: endY))
        } else {
            // Right-leaning: top-left to bottom-right
            context.move(to: CGPoint(x: startX, y: startY))
            context.addLine(to: CGPoint(x: endX, y: endY))
        }
        context.strokePath()
    }

    // MARK: - Graphic Rendering

    private static func renderGraphic(_ graphic: ParsedGraphic, in context: CGContext) {
        let bytesPerRow = graphic.bytesPerRow
        // Defense in depth: the parser already rejects `bytesPerRow <= 0`, but guard
        // here too so a malformed `ParsedGraphic` can never trap on the division below.
        guard bytesPerRow > 0, bytesPerRow <= RenderLimits.maxBytesPerRow else { return }
        // Overflow-checked `bytesPerRow * 8` and `width * height` as defense in depth.
        let (width, widthOverflow) = bytesPerRow.multipliedReportingOverflow(by: 8)  // Each byte = 8 pixels
        guard !widthOverflow, width > 0, width <= RenderLimits.maxDimensionDots else { return }
        let height = graphic.data.count / bytesPerRow

        guard height > 0, height <= RenderLimits.maxDimensionDots else { return }
        let (pixelCount, pixelOverflow) = width.multipliedReportingOverflow(by: height)
        guard !pixelOverflow, pixelCount <= RenderLimits.maxGraphicBytes else { return }

        // Expand the 1-bit data into one grayscale byte per pixel, writing directly
        // into a single `Data` buffer that backs the CGDataProvider. This avoids the
        // previous `[UInt8]` -> `Data` round-trip (which copied the buffer twice).
        // Each source byte represents 8 horizontal pixels, MSB first.
        var expandedData = Data(repeating: 255, count: pixelCount)  // Start with white

        expandedData.withUnsafeMutableBytes { rawBuffer in
            let pixels = rawBuffer.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for byteIndex in 0..<bytesPerRow {
                    let dataIndex = y * bytesPerRow + byteIndex
                    guard dataIndex < graphic.data.count else { continue }

                    let byte = graphic.data[dataIndex]

                    for bit in 0..<8 {
                        let x = byteIndex * 8 + bit
                        guard x < width else { continue }

                        let pixelIndex = y * width + x
                        // MSB first: bit 7 is leftmost pixel
                        let isSet = (byte & (0x80 >> bit)) != 0
                        pixels[pixelIndex] = isSet ? 0 : 255  // Black if set, white if not
                    }
                }
            }
        }

        // Create CGImage from the expanded data
        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
              let provider = CGDataProvider(data: expandedData as CFData),
              let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: width,
                space: colorSpace,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
              ) else {
            return
        }

        // Draw the image at the specified position
        // Need to flip vertically because CGContext is already flipped for ZPL coords,
        // but CGImage drawing expects unflipped
        let rect = CGRect(x: graphic.x, y: graphic.y, width: width, height: height)

        context.saveGState()
        // Flip around the center of the graphic
        context.translateBy(x: 0, y: CGFloat(graphic.y * 2 + height))
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: rect)
        context.restoreGState()
    }

    // MARK: - Barcode Rendering

    /// Applies the ZPL field rotation (`N`/`R`/`I`/`B`) to the context, matching the
    /// convention used by `renderText`. The caller is responsible for `saveGState`/
    /// `restoreGState` around this and for translating to the field origin first.
    private static func applyRotation(_ rotation: String, in context: CGContext) {
        switch rotation {
        case "R":
            context.rotate(by: -.pi / 2)
        case "I":
            context.rotate(by: -.pi)
        case "B":
            context.rotate(by: .pi / 2)
        default:
            break
        }
    }

    #if canImport(CoreImage)
    private static func renderBarcode(_ barcode: ParsedBarcode, in context: CGContext, ciContext: CIContext) throws {
        switch barcode.type {
        case .qrCode:
            try renderQRCode(barcode, in: context, ciContext: ciContext)
        case .code128:
            try renderCode128(barcode, in: context, ciContext: ciContext)
        case .aztec:
            try renderAztec(barcode, in: context, ciContext: ciContext)
        case .pdf417:
            try renderPDF417(barcode, in: context, ciContext: ciContext)
        case .code39:
            renderCode39(barcode, in: context)
        case .ean13:
            renderEAN13(barcode, in: context)
        case .ean8:
            renderEAN8(barcode, in: context)
        case .upcA:
            renderUPCA(barcode, in: context)
        case .upcE:
            renderUPCE(barcode, in: context)
        case .interleaved2of5:
            renderInterleaved2of5(barcode, in: context)
        case .dataMatrix, .intelligentMail:
            // Placeholder - draw a box with text
            renderPlaceholderBarcode(barcode, in: context)
        }
    }
    #else
    private static func renderBarcode(_ barcode: ParsedBarcode, in context: CGContext) throws {
        switch barcode.type {
        case .qrCode:
            try renderQRCode(barcode, in: context)
        case .code128:
            try renderCode128(barcode, in: context)
        case .aztec:
            try renderAztec(barcode, in: context)
        case .pdf417:
            try renderPDF417(barcode, in: context)
        case .code39:
            renderCode39(barcode, in: context)
        case .ean13:
            renderEAN13(barcode, in: context)
        case .ean8:
            renderEAN8(barcode, in: context)
        case .upcA:
            renderUPCA(barcode, in: context)
        case .upcE:
            renderUPCE(barcode, in: context)
        case .interleaved2of5:
            renderInterleaved2of5(barcode, in: context)
        case .dataMatrix, .intelligentMail:
            // Placeholder - draw a box with text
            renderPlaceholderBarcode(barcode, in: context)
        }
    }
    #endif

    // MARK: - CoreImage Barcodes

    #if canImport(CoreImage)

    /// Draws a generated 2D/CoreImage barcode `CGImage` at the barcode's field origin,
    /// honoring `ParsedBarcode.rotation` (`N`/`R`/`I`/`B`) using the same convention as text.
    ///
    /// For the unrotated (`N`) case this is pixel-identical to the previous direct
    /// `context.draw(cgImage, in: CGRect(x: barcode.x, y: barcode.y, ...))`: the
    /// translation just relocates that origin, and `applyRotation` is a no-op.
    private static func drawBarcodeImage(_ cgImage: CGImage, barcode: ParsedBarcode, in context: CGContext) {
        let width = cgImage.width
        let height = cgImage.height

        context.saveGState()
        // Move to the field origin, then rotate about it (same convention as renderText).
        context.translateBy(x: CGFloat(barcode.x), y: CGFloat(barcode.y))
        applyRotation(barcode.rotation, in: context)
        // Draw in the (now possibly rotated) local space. The rect matches the original
        // draw exactly for rotation "N".
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        context.restoreGState()
    }

    private static func renderQRCode(_ barcode: ParsedBarcode, in context: CGContext, ciContext: CIContext) throws {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw ZPLRendererError.renderError("QR Code filter not available")
        }

        guard let data = barcode.data.data(using: .utf8) else {
            throw ZPLRendererError.renderError("Invalid QR code data")
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else {
            throw ZPLRendererError.renderError("Failed to generate QR code")
        }

        let scale = CGFloat(barcode.magnification)
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw ZPLRendererError.renderError("Failed to create QR code image")
        }

        drawBarcodeImage(cgImage, barcode: barcode, in: context)
    }

    private static func renderCode128(_ barcode: ParsedBarcode, in context: CGContext, ciContext: CIContext) throws {
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else {
            throw ZPLRendererError.renderError("Code128 filter not available")
        }

        guard let data = barcode.data.data(using: .ascii) else {
            throw ZPLRendererError.renderError("Invalid Code128 data")
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(0, forKey: "inputQuietSpace")

        guard let outputImage = filter.outputImage else {
            throw ZPLRendererError.renderError("Failed to generate Code128")
        }

        // Scale to desired height
        let scaleX = CGFloat(barcode.moduleWidth)
        let scaleY = CGFloat(barcode.height) / outputImage.extent.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw ZPLRendererError.renderError("Failed to create Code128 image")
        }

        drawBarcodeImage(cgImage, barcode: barcode, in: context)

        // Draw text below if needed
        if barcode.showText {
            drawBarcodeText(barcode.data, at: CGPoint(x: CGFloat(barcode.x), y: CGFloat(barcode.y) + CGFloat(barcode.height) + 5), in: context)
        }
    }

    private static func renderAztec(_ barcode: ParsedBarcode, in context: CGContext, ciContext: CIContext) throws {
        guard let filter = CIFilter(name: "CIAztecCodeGenerator") else {
            throw ZPLRendererError.renderError("Aztec filter not available")
        }

        guard let data = barcode.data.data(using: .utf8) else {
            throw ZPLRendererError.renderError("Invalid Aztec data")
        }

        filter.setValue(data, forKey: "inputMessage")

        guard let outputImage = filter.outputImage else {
            throw ZPLRendererError.renderError("Failed to generate Aztec code")
        }

        let scale = CGFloat(barcode.magnification)
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw ZPLRendererError.renderError("Failed to create Aztec image")
        }

        drawBarcodeImage(cgImage, barcode: barcode, in: context)
    }

    private static func renderPDF417(_ barcode: ParsedBarcode, in context: CGContext, ciContext: CIContext) throws {
        guard let filter = CIFilter(name: "CIPDF417BarcodeGenerator") else {
            throw ZPLRendererError.renderError("PDF417 filter not available")
        }

        guard let data = barcode.data.data(using: .utf8) else {
            throw ZPLRendererError.renderError("Invalid PDF417 data")
        }

        filter.setValue(data, forKey: "inputMessage")

        guard let outputImage = filter.outputImage else {
            throw ZPLRendererError.renderError("Failed to generate PDF417")
        }

        let scale = CGFloat(barcode.magnification) / 5.0
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw ZPLRendererError.renderError("Failed to create PDF417 image")
        }

        drawBarcodeImage(cgImage, barcode: barcode, in: context)
    }

    #else

    private static func renderQRCode(_ barcode: ParsedBarcode, in context: CGContext) throws {
        renderPlaceholderBarcode(barcode, in: context)
    }

    private static func renderCode128(_ barcode: ParsedBarcode, in context: CGContext) throws {
        renderPlaceholderBarcode(barcode, in: context)
    }

    private static func renderAztec(_ barcode: ParsedBarcode, in context: CGContext) throws {
        renderPlaceholderBarcode(barcode, in: context)
    }

    private static func renderPDF417(_ barcode: ParsedBarcode, in context: CGContext) throws {
        renderPlaceholderBarcode(barcode, in: context)
    }

    #endif

    // MARK: - 1D Barcode Rendering (Manual)

    private static func renderCode39(_ barcode: ParsedBarcode, in context: CGContext) {
        let patterns = Code39Patterns.encode(barcode.data)
        render1DBarcode(patterns: patterns, barcode: barcode, in: context)
    }

    private static func renderEAN13(_ barcode: ParsedBarcode, in context: CGContext) {
        let patterns = EANPatterns.encodeEAN13(barcode.data)
        render1DBarcode(patterns: patterns, barcode: barcode, in: context)
    }

    private static func renderEAN8(_ barcode: ParsedBarcode, in context: CGContext) {
        let patterns = EANPatterns.encodeEAN8(barcode.data)
        render1DBarcode(patterns: patterns, barcode: barcode, in: context)
    }

    private static func renderUPCA(_ barcode: ParsedBarcode, in context: CGContext) {
        let patterns = EANPatterns.encodeUPCA(barcode.data)
        render1DBarcode(patterns: patterns, barcode: barcode, in: context)
    }

    private static func renderUPCE(_ barcode: ParsedBarcode, in context: CGContext) {
        let patterns = EANPatterns.encodeUPCE(barcode.data)
        render1DBarcode(patterns: patterns, barcode: barcode, in: context)
    }

    private static func renderInterleaved2of5(_ barcode: ParsedBarcode, in context: CGContext) {
        let patterns = Interleaved2of5Patterns.encode(barcode.data)
        render1DBarcode(patterns: patterns, barcode: barcode, in: context)
    }

    private static func render1DBarcode(patterns: [Bool], barcode: ParsedBarcode, in context: CGContext) {
        guard !patterns.isEmpty else { return }

        let moduleWidth = CGFloat(barcode.moduleWidth)
        let height = CGFloat(barcode.height)

        context.saveGState()
        // Move to the field origin and rotate about it (same convention as renderText).
        // Bars/text are then drawn in local coordinates starting at (0, 0); for
        // rotation "N" this is pixel-identical to the previous absolute-position draw.
        context.translateBy(x: CGFloat(barcode.x), y: CGFloat(barcode.y))
        applyRotation(barcode.rotation, in: context)

        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

        var x: CGFloat = 0
        for isBar in patterns {
            if isBar {
                context.fill(CGRect(x: x, y: 0, width: moduleWidth, height: height))
            }
            x += moduleWidth
        }

        // Draw text below (or above) if needed, in the same rotated local space.
        if barcode.showText {
            let textY = barcode.textAbove ? -20 : height + 5
            drawBarcodeText(barcode.data, at: CGPoint(x: 0, y: textY), in: context)
        }

        context.restoreGState()
    }

    private static func renderPlaceholderBarcode(_ barcode: ParsedBarcode, in context: CGContext) {
        // Draw a placeholder box with barcode type label
        let rect = CGRect(x: barcode.x, y: barcode.y, width: 100, height: barcode.height)
        context.setStrokeColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.setLineWidth(1)
        context.stroke(rect)

        drawBarcodeText("[\(displayName(for: barcode.type))]", at: CGPoint(x: CGFloat(barcode.x), y: CGFloat(barcode.y) + CGFloat(barcode.height / 2)), in: context)
    }

    /// Human-readable label for a barcode symbology, used in the placeholder text so
    /// previews show "DataMatrix" instead of the raw ZPL command code (e.g. "BX").
    private static func displayName(for type: ParsedBarcode.BarcodeType) -> String {
        switch type {
        case .code128: return "Code128"
        case .code39: return "Code39"
        case .qrCode: return "QR Code"
        case .dataMatrix: return "DataMatrix"
        case .pdf417: return "PDF417"
        case .interleaved2of5: return "Interleaved 2 of 5"
        case .ean13: return "EAN-13"
        case .ean8: return "EAN-8"
        case .upcA: return "UPC-A"
        case .upcE: return "UPC-E"
        case .aztec: return "Aztec"
        case .intelligentMail: return "Intelligent Mail"
        }
    }

    private static func drawBarcodeText(_ text: String, at point: CGPoint, in context: CGContext) {
        let font = CTFontCreateWithName("Helvetica" as CFString, 12, nil)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributedString)
        let bounds = CTLineGetBoundsWithOptions(line, [])

        context.saveGState()
        context.translateBy(x: point.x, y: point.y)
        // Un-flip for CoreText
        context.scaleBy(x: 1, y: -1)
        context.textPosition = CGPoint(x: 0, y: -bounds.height - bounds.minY)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
