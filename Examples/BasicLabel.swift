/// BasicLabel.swift
/// A simple "Hello World" label demonstrating core ZPLKit features.

import ZPLKit

// MARK: - Simple Text Label

/// Basic label with text and a border
let helloWorldLabel = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
    Text("Hello, World!", at: .inches(0.15, 0.35))
        .font(.default, height: .inches(0.2))

    Box(at: .inches(0.1, 0.1), width: .inches(1.8), height: .inches(0.8))
        .thickness(2)
}

// MARK: - Label with Multiple Elements

/// Label showing text, barcode, and shapes together
let multiElementLabel = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
    // Header
    Text("SAMPLE LABEL", at: .inches(0.25, 0.2))
        .font(.default, height: .inches(0.15))

    // Divider line
    HorizontalLine(at: .inches(0.25, 0.45), length: .inches(3.5), thickness: 2)

    // Barcode with human-readable text
    Barcode128("SAMPLE-001", at: .inches(0.25, 0.6))
        .height(.inches(0.5))
        .showText(true)

    // QR code in corner
    QRCode("https://example.com", at: .inches(3.0, 0.6))
        .magnification(3)

    // Border
    Box(at: .inches(0.1, 0.1), width: .inches(3.8), height: .inches(1.8))
        .thickness(3)
        .cornerRadius(2)
}

// MARK: - Rotated Text

/// Label with rotated text elements
let rotatedTextLabel = ZPLLabel(width: 2, height: 2, dpi: .dpi203) {
    Text("NORMAL", at: .inches(0.5, 0.25))
        .font(.default, height: .inches(0.12))

    Text("ROTATED 90", at: .inches(1.75, 0.5))
        .font(.default, height: .inches(0.12))
        .rotated(.rotated90)

    Text("ROTATED 180", at: .inches(1.5, 1.75))
        .font(.default, height: .inches(0.12))
        .rotated(.rotated180)

    Text("ROTATED 270", at: .inches(0.25, 1.5))
        .font(.default, height: .inches(0.12))
        .rotated(.rotated270)
}

// MARK: - Usage

func printExamples() {
    print("=== Hello World Label ===")
    print(helloWorldLabel.render())
    print()

    print("=== Multi-Element Label ===")
    print(multiElementLabel.render())
    print()

    print("=== Rotated Text Label ===")
    print(rotatedTextLabel.render())
}
