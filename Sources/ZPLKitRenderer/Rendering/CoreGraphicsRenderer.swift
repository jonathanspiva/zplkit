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

    /// Renders a parsed label to a CGImage
    public static func render(
        _ label: ParsedLabel,
        dpi: DPI,
        fontConfiguration: ZPLRenderer.FontConfiguration
    ) throws -> CGImage {
        let width = label.width
        let height = label.height

        // Create bitmap context (white background)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
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
                try renderBarcode(barcode, in: context)

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

    private static func renderText(_ text: ParsedText, in context: CGContext, fontConfig: ZPLRenderer.FontConfiguration) {
        let fontSize = CGFloat(text.fontHeight)

        guard let font = fontConfig.font0.createFont(size: fontSize) else {
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

        guard let font = fontConfig.font0.createFont(size: fontSize) else {
            return // Skip rendering if font unavailable
        }

        // Create paragraph style using CoreText
        var alignment: CTTextAlignment
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

        let alignmentSetting = [
            CTParagraphStyleSetting(
                spec: .alignment,
                valueSize: MemoryLayout<CTTextAlignment>.size,
                value: &alignment
            )
        ]
        let paragraphStyle = CTParagraphStyleCreate(alignmentSetting, alignmentSetting.count)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1),
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: textBlock.text, attributes: attributes)

        let frameSetter = CTFramesetterCreateWithAttributedString(attributedString)
        let frameHeight = CGFloat(textBlock.maxLines * textBlock.fontHeight * 2)

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
        let width = bytesPerRow * 8  // Each byte = 8 pixels
        let height = graphic.data.count / bytesPerRow

        guard height > 0, width > 0 else { return }

        // Create a bitmap from the 1-bit data
        // Each byte in data represents 8 horizontal pixels (MSB first)
        var expandedData = [UInt8](repeating: 255, count: width * height)  // Start with white

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
                    expandedData[pixelIndex] = isSet ? 0 : 255  // Black if set, white if not
                }
            }
        }

        // Create CGImage from the expanded data
        guard let colorSpace = CGColorSpace(name: CGColorSpace.linearGray),
              let provider = CGDataProvider(data: Data(expandedData) as CFData),
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

    // MARK: - CoreImage Barcodes

    #if canImport(CoreImage)

    private static func renderQRCode(_ barcode: ParsedBarcode, in context: CGContext) throws {
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

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw ZPLRendererError.renderError("Failed to create QR code image")
        }

        let rect = CGRect(x: barcode.x, y: barcode.y, width: cgImage.width, height: cgImage.height)
        context.draw(cgImage, in: rect)
    }

    private static func renderCode128(_ barcode: ParsedBarcode, in context: CGContext) throws {
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

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw ZPLRendererError.renderError("Failed to create Code128 image")
        }

        let rect = CGRect(x: barcode.x, y: barcode.y, width: cgImage.width, height: cgImage.height)
        context.draw(cgImage, in: rect)

        // Draw text below if needed
        if barcode.showText {
            drawBarcodeText(barcode.data, at: CGPoint(x: CGFloat(barcode.x), y: CGFloat(barcode.y) + CGFloat(barcode.height) + 5), in: context)
        }
    }

    private static func renderAztec(_ barcode: ParsedBarcode, in context: CGContext) throws {
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

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw ZPLRendererError.renderError("Failed to create Aztec image")
        }

        let rect = CGRect(x: barcode.x, y: barcode.y, width: cgImage.width, height: cgImage.height)
        context.draw(cgImage, in: rect)
    }

    private static func renderPDF417(_ barcode: ParsedBarcode, in context: CGContext) throws {
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

        let ciContext = CIContext()
        guard let cgImage = ciContext.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw ZPLRendererError.renderError("Failed to create PDF417 image")
        }

        let rect = CGRect(x: barcode.x, y: barcode.y, width: cgImage.width, height: cgImage.height)
        context.draw(cgImage, in: rect)
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

        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))

        let moduleWidth = CGFloat(barcode.moduleWidth)
        var x = CGFloat(barcode.x)
        let y = CGFloat(barcode.y)
        let height = CGFloat(barcode.height)

        for isBar in patterns {
            if isBar {
                context.fill(CGRect(x: x, y: y, width: moduleWidth, height: height))
            }
            x += moduleWidth
        }

        // Draw text below if needed
        if barcode.showText {
            let textY = barcode.textAbove ? CGFloat(barcode.y) - 20 : CGFloat(barcode.y) + height + 5
            drawBarcodeText(barcode.data, at: CGPoint(x: CGFloat(barcode.x), y: textY), in: context)
        }
    }

    private static func renderPlaceholderBarcode(_ barcode: ParsedBarcode, in context: CGContext) {
        // Draw a placeholder box with barcode type label
        let rect = CGRect(x: barcode.x, y: barcode.y, width: 100, height: barcode.height)
        context.setStrokeColor(CGColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        context.setLineWidth(1)
        context.stroke(rect)

        drawBarcodeText("[\(barcode.type.rawValue)]", at: CGPoint(x: CGFloat(barcode.x), y: CGFloat(barcode.y) + CGFloat(barcode.height / 2)), in: context)
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
