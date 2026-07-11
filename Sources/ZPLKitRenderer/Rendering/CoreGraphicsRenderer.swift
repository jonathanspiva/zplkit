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
                // One barcode with unencodable data must not abort the whole
                // label; skip it like the manual 1D encoders do on bad input.
                do {
                    #if canImport(CoreImage)
                    try renderBarcode(barcode, in: context, ciContext: ciContext)
                    #else
                    try renderBarcode(barcode, in: context)
                    #endif
                } catch {
                    continue
                }

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

        // Move to text position, then rotate about that origin.
        context.translateBy(x: CGFloat(text.x), y: CGFloat(text.y))
        applyRotation(text.rotation, in: context)

        // ZPL scales glyph width independently of height (`^A0N,h,w`). The
        // bundled font is drawn at `fontHeight` and stretched horizontally.
        if text.fontHeight > 0, text.fontWidth > 0, text.fontWidth != text.fontHeight {
            context.scaleBy(x: CGFloat(text.fontWidth) / CGFloat(text.fontHeight), y: 1)
        }

        // Get text bounds for proper positioning
        let bounds = CTLineGetBoundsWithOptions(line, [])

        // Un-flip for text rendering (context is flipped, but CoreText expects unflipped)
        // This makes text render right-side up
        context.scaleBy(x: 1, y: -1)

        // `^FT` anchors the baseline at the field origin; `^FO` anchors the
        // glyph top. In the un-flipped local space the baseline sits at y = 0
        // for `^FT`, and at -height - minY (glyph top at 0) for `^FO`.
        let baselineY: CGFloat = text.useBaseline ? 0 : -bounds.height - bounds.minY
        let boxY: CGFloat = text.useBaseline ? bounds.minY : -bounds.height

        // If reversed, draw background box
        if text.isReversed {
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: boxY, width: bounds.width, height: bounds.height))
        }

        context.textPosition = CGPoint(x: 0, y: baselineY)
        CTLineDraw(line, context)

        context.restoreGState()
    }

    private static func renderTextBlock(_ textBlock: ParsedTextBlock, in context: CGContext, fontConfig: ZPLRenderer.FontConfiguration) {
        let fontSize = CGFloat(textBlock.fontHeight)

        guard let font = fontSource(for: textBlock.font, config: fontConfig).createFont(size: fontSize) else {
            return // Skip rendering if font unavailable
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        ]

        let attributedString = NSAttributedString(string: textBlock.text, attributes: attributes)

        // Lay lines out manually with a CTTypesetter: `^FB` caps the line count
        // exactly (extra text is dropped), advances one `fontHeight` (+/- the
        // line-spacing delta) per line, indents the second and later lines by the
        // hanging indent, and aligns per line (L/C/R, J on all but the last line).
        // Defense in depth: clamp values so a hand-built `ParsedTextBlock` cannot
        // trap or balloon allocations.
        let clampedLines = min(max(textBlock.maxLines, 1), RenderLimits.maxTextBlockLines)
        let clampedFontHeight = min(max(textBlock.fontHeight, 0), RenderLimits.maxFontHeight)
        let lineAdvance = CGFloat(clampedFontHeight) + CGFloat(textBlock.lineSpacing)

        // ZPL scales glyph width independently of height; line breaking happens
        // in unscaled text units against a proportionally narrower block width.
        let widthScale: CGFloat = (textBlock.fontHeight > 0 && textBlock.fontWidth > 0 && textBlock.fontWidth != textBlock.fontHeight)
            ? CGFloat(textBlock.fontWidth) / CGFloat(textBlock.fontHeight)
            : 1
        let blockWidth = max(CGFloat(textBlock.blockWidth) / widthScale, 1)

        let typesetter = CTTypesetterCreateWithAttributedString(attributedString)
        let length = attributedString.length
        let ascent = CTFontGetAscent(font)

        context.saveGState()
        // Move to the block origin, apply width scaling, then un-flip for CoreText.
        // Local space is y-up: a baseline `b` dots below the block top is at -b.
        context.translateBy(x: CGFloat(textBlock.x), y: CGFloat(textBlock.y))
        if widthScale != 1 {
            context.scaleBy(x: widthScale, y: 1)
        }
        context.scaleBy(x: 1, y: -1)

        var start = 0
        var lineIndex = 0
        while start < length && lineIndex < clampedLines {
            // Hanging indent applies to the second and remaining lines.
            let indent = lineIndex == 0 ? 0 : CGFloat(max(textBlock.hangingIndent, 0))
            let available = max(blockWidth - indent, 1)
            let count = CTTypesetterSuggestLineBreak(typesetter, start, Double(available))
            guard count > 0 else { break }
            var line = CTTypesetterCreateLine(typesetter, CFRange(location: start, length: count))

            let isLastLine = (start + count >= length) || (lineIndex == clampedLines - 1)
            var penX = indent
            switch textBlock.alignment {
            case "C":
                penX = indent + CGFloat(CTLineGetPenOffsetForFlush(line, 0.5, Double(available)))
            case "R":
                penX = indent + CGFloat(CTLineGetPenOffsetForFlush(line, 1.0, Double(available)))
            case "J":
                if !isLastLine, let justified = CTLineCreateJustifiedLine(line, 1.0, Double(available)) {
                    line = justified
                }
            default:
                break
            }

            // `^FT` puts the first line's BASELINE at the field origin; `^FO`
            // puts the glyph top there (baseline one ascent further down).
            let baselineFromTop = (textBlock.useBaseline ? 0 : ascent) + CGFloat(lineIndex) * lineAdvance
            context.textPosition = CGPoint(x: penX, y: -baselineFromTop)
            CTLineDraw(line, context)

            start += count
            lineIndex += 1
        }

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

        // ZPL draws the ^GB border INSIDE the w x h box; CoreGraphics strokes
        // centered on the path, so inset by half the thickness.
        let strokeRect = rect.insetBy(dx: CGFloat(box.thickness) / 2, dy: CGFloat(box.thickness) / 2)

        if box.cornerRadius > 0 {
            let radius = CGFloat(box.cornerRadius)

            if box.thickness >= min(box.width, box.height) / 2 {
                let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
                context.addPath(path)
                context.fillPath()
            } else {
                let insetRadius = max(radius - CGFloat(box.thickness) / 2, 0)
                let path = CGPath(roundedRect: strokeRect, cornerWidth: insetRadius, cornerHeight: insetRadius, transform: nil)
                context.addPath(path)
                context.strokePath()
            }
        } else {
            if box.thickness >= min(box.width, box.height) / 2 {
                context.fill(rect)
            } else {
                context.stroke(strokeRect)
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
    ///
    /// The render context is y-flipped (top-left origin), which mirrors rotation
    /// direction: a POSITIVE angle here appears clockwise on the output. ZPL
    /// `R` = 90° clockwise, `B` = 270° clockwise.
    private static func applyRotation(_ rotation: String, in context: CGContext) {
        switch rotation {
        case "R":
            context.rotate(by: .pi / 2)
        case "I":
            context.rotate(by: .pi)
        case "B":
            context.rotate(by: -.pi / 2)
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
    /// A `caption` (the human-readable interpretation line) is drawn in the same
    /// rotated local space, below the bars, so it rotates with the symbol.
    ///
    /// For the unrotated (`N`) case this is pixel-identical to the previous direct
    /// `context.draw(cgImage, in: CGRect(x: barcode.x, y: barcode.y, ...))`: the
    /// translation just relocates that origin, and `applyRotation` is a no-op.
    private static func drawBarcodeImage(_ cgImage: CGImage, barcode: ParsedBarcode, in context: CGContext, caption: String? = nil) {
        let width = cgImage.width
        let height = cgImage.height

        context.saveGState()
        // Move to the field origin, then rotate about it (same convention as renderText).
        context.translateBy(x: CGFloat(barcode.x), y: CGFloat(barcode.y))
        applyRotation(barcode.rotation, in: context)
        // `^FT` anchors the field's bottom-left rather than its top-left.
        if barcode.useBaseline {
            context.translateBy(x: 0, y: -CGFloat(height))
        }
        // Draw in the (now possibly rotated) local space. The rect matches the original
        // draw exactly for rotation "N".
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        if let caption {
            drawBarcodeText(caption, at: CGPoint(x: 0, y: CGFloat(height) + 5), in: context)
        }
        context.restoreGState()
    }

    /// Splits `^BQ` field data into its in-data header and the payload.
    ///
    /// ZPL `^BQ` field data starts with `<errorCorrection><inputMode>,` (e.g.
    /// `QA,` or `MM,`) — that header selects the EC level and input mode and is
    /// NOT part of the encoded content.
    static func qrFieldData(_ data: String) -> (errorCorrection: String, payload: String) {
        let chars = Array(data)
        if chars.count >= 3,
           "HQML".contains(chars[0]),
           "AM".contains(chars[1]),
           chars[2] == "," {
            return (String(chars[0]), String(chars[3...]))
        }
        return ("M", data)
    }

    private static func renderQRCode(_ barcode: ParsedBarcode, in context: CGContext, ciContext: CIContext) throws {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw ZPLRendererError.renderError("QR Code filter not available")
        }

        let (errorCorrection, payload) = qrFieldData(barcode.data)
        guard let data = payload.data(using: .utf8) else {
            throw ZPLRendererError.renderError("Invalid QR code data")
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(errorCorrection, forKey: "inputCorrectionLevel")

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

    /// Strips ZPL Code 128 in-data invocation codes (`>` sequences) so they are
    /// not encoded literally into the symbol.
    ///
    /// `>0` escapes a literal `>`; subset selectors (`>9` A, `>:` B, `>;` C) and
    /// function codes (`>1`-`>8`, `><`, `>=`) steer the printer's encoder and
    /// have no content representation, so they are dropped. CoreImage picks its
    /// own optimal subsets, so the selectors are safely ignorable for preview.
    static func code128Payload(_ data: String) -> String {
        var result = ""
        result.reserveCapacity(data.count)
        var iterator = data.makeIterator()
        while let ch = iterator.next() {
            guard ch == ">" else {
                result.append(ch)
                continue
            }
            guard let next = iterator.next() else {
                result.append(ch)
                break
            }
            if next == "0" {
                result.append(">")
            } else if "123456789:;<=".contains(next) {
                // Invocation/function code: no content representation.
                continue
            } else {
                // Unknown pair: keep both characters as data.
                result.append(ch)
                result.append(next)
            }
        }
        return result
    }

    private static func renderCode128(_ barcode: ParsedBarcode, in context: CGContext, ciContext: CIContext) throws {
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else {
            throw ZPLRendererError.renderError("Code128 filter not available")
        }

        let payload = code128Payload(barcode.data)
        guard let data = payload.data(using: .ascii) else {
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

        // The interpretation line is drawn inside the same rotated local space
        // as the bars so it follows the barcode's rotation.
        drawBarcodeImage(cgImage, barcode: barcode, in: context, caption: barcode.showText ? payload : nil)
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
        // `^FT` anchors the field's bottom-left rather than its top-left.
        if barcode.useBaseline {
            context.translateBy(x: 0, y: -height)
        }

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
        // Draw a placeholder box with barcode type label. `^FT` anchors the
        // field's bottom-left rather than its top-left.
        let y = barcode.useBaseline ? barcode.y - barcode.height : barcode.y
        let rect = CGRect(x: barcode.x, y: y, width: 100, height: barcode.height)
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
