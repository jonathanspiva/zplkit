/// ProductLabel.swift
/// Retail and product labeling examples.

import ZPLKit

// MARK: - Price Tag

/// Simple retail price tag
let priceTag = ZPLLabel(width: 2, height: 1.25, dpi: .dpi203) {
    // Product name
    Text("Organic Coffee", at: .inches(0.15, 0.1))
        .font(.default, height: .inches(0.12))
    Text("Dark Roast, 12oz", at: .inches(0.15, 0.25))
        .font(.default, height: .inches(0.08))

    // Price (large)
    Text("$12.99", at: .inches(0.15, 0.45))
        .font(.default, height: .inches(0.3))

    // UPC barcode
    UPCA("012345678905", at: .inches(0.15, 0.85))
        .height(.inches(0.25))
        .showText(true)

    // Border
    Box(at: .inches(0.05, 0.05), width: .inches(1.9), height: .inches(1.15))
        .thickness(2)
}

// MARK: - Product Info Label

/// Detailed product label with specs
let productInfoLabel = ZPLLabel(width: 4, height: 3, dpi: .dpi203) {
    // Brand/Product header
    Text("TechGear Pro", at: .inches(0.25, 0.2))
        .font(.default, height: .inches(0.08))
    Text("Wireless Mouse", at: .inches(0.25, 0.35))
        .font(.default, height: .inches(0.2))
    Text("Model: WM-500", at: .inches(0.25, 0.6))
        .font(.default, height: .inches(0.1))

    // QR code for product page
    QRCode("https://techgear.example.com/wm500", at: .inches(3.0, 0.2))
        .magnification(4)

    HorizontalLine(at: .inches(0.2, 0.8), length: .inches(3.6), thickness: 2)

    // Specs in text block style
    Text("Features:", at: .inches(0.25, 0.9))
        .font(.default, height: .inches(0.1))
    Text("- 2.4GHz Wireless", at: .inches(0.25, 1.05))
        .font(.default, height: .inches(0.08))
    Text("- 1600 DPI Optical", at: .inches(0.25, 1.18))
        .font(.default, height: .inches(0.08))
    Text("- 12-month battery", at: .inches(0.25, 1.31))
        .font(.default, height: .inches(0.08))
    Text("- USB-C Receiver", at: .inches(0.25, 1.44))
        .font(.default, height: .inches(0.08))

    // Right column
    Text("Color: Matte Black", at: .inches(2.0, 1.05))
        .font(.default, height: .inches(0.08))
    Text("Weight: 85g", at: .inches(2.0, 1.18))
        .font(.default, height: .inches(0.08))
    Text("Warranty: 2 years", at: .inches(2.0, 1.31))
        .font(.default, height: .inches(0.08))

    HorizontalLine(at: .inches(0.2, 1.65), length: .inches(3.6), thickness: 1)

    // SKU and barcode
    Text("SKU: WM500-BLK", at: .inches(0.25, 1.75))
        .font(.default, height: .inches(0.1))

    Barcode128("WM500BLK", at: .inches(0.25, 1.95))
        .height(.inches(0.4))
        .showText(true)

    // Price
    Box(at: .inches(2.5, 1.75), width: .inches(1.3), height: .inches(0.7))
        .thickness(2)
    Text("$49.99", at: .inches(2.65, 1.95))
        .font(.default, height: .inches(0.25))

    // EAN barcode at bottom
    EAN13("5901234123457", at: .inches(1.0, 2.55))
        .height(.inches(0.3))
        .showText(true)

    // Border
    Box(at: .inches(0.1, 0.1), width: .inches(3.8), height: .inches(2.8))
        .thickness(3)
}

// MARK: - Jewelry Tag (Small)

/// Tiny tag for jewelry with string hole
let jewelryTag = ZPLLabel(width: 1.5, height: 0.75, dpi: .dpi300) {  // Higher DPI for small label
    // Small circle for string hole
    Circle(at: .inches(0.1, 0.3), diameter: .inches(0.15))
        .thickness(1)

    // Style code
    Text("NKL-925-18", at: .inches(0.3, 0.15))
        .font(.default, height: .inches(0.1))

    // Price
    Text("$89", at: .inches(0.3, 0.35))
        .font(.default, height: .inches(0.15))

    // Tiny barcode
    Barcode128("NKL92518", at: .inches(0.3, 0.55))
        .height(.inches(0.12))
        .moduleWidth(1)
}

// MARK: - Food Label (with nutrition placeholder)

/// Food product label with required info
let foodLabel = ZPLLabel(width: 4, height: 4, dpi: .dpi203) {
    // Product name
    Text("Artisan Sourdough", at: .inches(0.25, 0.2))
        .font(.default, height: .inches(0.2))
    Text("Bread Loaf", at: .inches(0.25, 0.45))
        .font(.default, height: .inches(0.15))

    // Net weight
    Text("NET WT 24 OZ (680g)", at: .inches(0.25, 0.7))
        .font(.default, height: .inches(0.1))

    HorizontalLine(at: .inches(0.2, 0.9), length: .inches(3.6), thickness: 2)

    // Ingredients (text block would be ideal here)
    Text("INGREDIENTS:", at: .inches(0.25, 1.0))
        .font(.default, height: .inches(0.08))
    Text("Wheat flour, water, salt,", at: .inches(0.25, 1.12))
        .font(.default, height: .inches(0.07))
    Text("sourdough culture.", at: .inches(0.25, 1.22))
        .font(.default, height: .inches(0.07))

    Text("CONTAINS: WHEAT", at: .inches(0.25, 1.4))
        .font(.default, height: .inches(0.1))

    // Nutrition facts box (simplified)
    Box(at: .inches(2.2, 1.0), width: .inches(1.6), height: .inches(1.2))
        .thickness(2)
    Text("Nutrition Facts", at: .inches(2.3, 1.08))
        .font(.default, height: .inches(0.08))
    HorizontalLine(at: .inches(2.25, 1.2), length: .inches(1.5), thickness: 1)
    Text("Serv. Size 1 slice", at: .inches(2.3, 1.25))
        .font(.default, height: .inches(0.06))
    Text("Calories 120", at: .inches(2.3, 1.35))
        .font(.default, height: .inches(0.08))
    Text("Total Fat 0.5g", at: .inches(2.3, 1.48))
        .font(.default, height: .inches(0.06))
    Text("Sodium 230mg", at: .inches(2.3, 1.58))
        .font(.default, height: .inches(0.06))
    Text("Carbs 24g", at: .inches(2.3, 1.68))
        .font(.default, height: .inches(0.06))
    Text("Protein 4g", at: .inches(2.3, 1.78))
        .font(.default, height: .inches(0.06))

    HorizontalLine(at: .inches(0.2, 2.3), length: .inches(3.6), thickness: 1)

    // Best by date
    Text("BEST BY: SEE BOTTOM", at: .inches(0.25, 2.4))
        .font(.default, height: .inches(0.1))

    // Storage
    Text("STORE AT ROOM TEMP", at: .inches(0.25, 2.55))
        .font(.default, height: .inches(0.08))

    // Barcode
    UPCA("012345678905", at: .inches(0.5, 2.8))
        .height(.inches(0.5))
        .showText(true)

    // QR for more info
    QRCode("https://bakery.example.com/sourdough", at: .inches(2.8, 2.75))
        .magnification(4)

    // Company info
    Text("Artisan Bakery Co.", at: .inches(0.25, 3.5))
        .font(.default, height: .inches(0.08))
    Text("Portland, OR 97201", at: .inches(0.25, 3.62))
        .font(.default, height: .inches(0.07))

    // Border
    Box(at: .inches(0.1, 0.1), width: .inches(3.8), height: .inches(3.8))
        .thickness(3)
}

// MARK: - Clearance/Sale Tag

/// Bold clearance tag with original and sale price
let clearanceTag = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
    // SALE header (reversed)
    Box(at: .inches(0.1, 0.1), width: .inches(1.8), height: .inches(0.4))
        .filled()
    Text("CLEARANCE", at: .inches(0.3, 0.18))
        .font(.default, height: .inches(0.18))
        .reversed()

    // Original price (struck through effect with line)
    Text("Was: $79.99", at: .inches(0.2, 0.6))
        .font(.default, height: .inches(0.12))
    HorizontalLine(at: .inches(0.2, 0.68), length: .inches(1.0), thickness: 2)

    // Sale price (large)
    Text("NOW", at: .inches(0.2, 0.85))
        .font(.default, height: .inches(0.1))
    Text("$29.99", at: .inches(0.2, 1.0))
        .font(.default, height: .inches(0.35))

    // Savings
    Text("SAVE $50!", at: .inches(0.2, 1.4))
        .font(.default, height: .inches(0.12))

    // SKU barcode
    Barcode128("CLR-12345", at: .inches(0.2, 1.6))
        .height(.inches(0.25))
        .showText(true)

    // Border
    Box(at: .inches(0.05, 0.05), width: .inches(1.9), height: .inches(1.9))
        .thickness(4)
}

// MARK: - Template for Price Tags

/// Reusable template for retail price tags
let priceTagTemplate = ZPLTemplate(width: 2, height: 1.25, dpi: .dpi203) {
    Text("{{product_name}}", at: .inches(0.15, 0.1))
        .font(.default, height: .inches(0.12))
    Text("{{product_desc}}", at: .inches(0.15, 0.25))
        .font(.default, height: .inches(0.08))

    Text("${{price}}", at: .inches(0.15, 0.45))
        .font(.default, height: .inches(0.3))

    UPCA("{{upc}}", at: .inches(0.15, 0.85))
        .height(.inches(0.25))
        .showText(true)

    Box(at: .inches(0.05, 0.05), width: .inches(1.9), height: .inches(1.15))
        .thickness(2)
}
