/// ShippingLabel.swift
/// Shipping label examples for packages and envelopes.

import ZPLKit

// MARK: - Standard Shipping Label (4x6)

/// A typical 4x6 shipping label with sender, recipient, and tracking barcode
let shippingLabel = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
    // FROM section
    Text("FROM:", at: .inches(0.2, 0.2))
        .font(.default, height: .inches(0.1))
    Text("Acme Corporation", at: .inches(0.2, 0.35))
        .font(.default, height: .inches(0.12))
    Text("123 Industrial Way", at: .inches(0.2, 0.5))
        .font(.default, height: .inches(0.1))
    Text("Austin, TX 78701", at: .inches(0.2, 0.65))
        .font(.default, height: .inches(0.1))

    // Divider
    HorizontalLine(at: .inches(0.1, 0.9), length: .inches(3.8), thickness: 3)

    // TO section (larger, prominent)
    Text("SHIP TO:", at: .inches(0.2, 1.0))
        .font(.default, height: .inches(0.12))
    Text("Jane Smith", at: .inches(0.2, 1.2))
        .font(.default, height: .inches(0.2))
    Text("456 Oak Street, Apt 2B", at: .inches(0.2, 1.5))
        .font(.default, height: .inches(0.15))
    Text("San Francisco, CA 94102", at: .inches(0.2, 1.75))
        .font(.default, height: .inches(0.15))

    // Postal barcode (Intelligent Mail or Code128)
    HorizontalLine(at: .inches(0.1, 2.1), length: .inches(3.8), thickness: 2)

    Text("TRACKING NUMBER", at: .inches(0.2, 2.2))
        .font(.default, height: .inches(0.1))
    Barcode128("1Z999AA10123456784", at: .inches(0.2, 2.4))?
        .height(.inches(0.8))
        .showText(true)
        .moduleWidth(2)

    // Service type
    Box(at: .inches(2.8, 0.2), width: .inches(1.0), height: .inches(0.5))
        .filled()
    Text("PRIORITY", at: .inches(2.85, 0.35))
        .font(.default, height: .inches(0.15))
        .reversed()

    // Weight
    Text("WT: 2.5 LBS", at: .inches(0.2, 3.5))
        .font(.default, height: .inches(0.12))

    // Routing barcode at bottom
    HorizontalLine(at: .inches(0.1, 3.75), length: .inches(3.8), thickness: 2)
    Barcode128("94102", at: .inches(1.0, 3.9))?
        .height(.inches(0.6))
        .showText(true)

    // MaxiCode for carrier sorting (approximate position)
    DataMatrix("[)>01 94102 456 OAK ST", at: .inches(2.8, 3.9))
        .moduleSize(6)

    // Border
    Box(at: .inches(0.05, 0.05), width: .inches(3.9), height: .inches(5.9))
        .thickness(4)
}

// MARK: - Return Label

/// Small return label with QR code for easy scanning
let returnLabel = ZPLLabel(width: 4, height: 3, dpi: .dpi203) {
    Text("RETURN LABEL", at: .inches(0.25, 0.2))
        .font(.default, height: .inches(0.2))

    HorizontalLine(at: .inches(0.2, 0.5), length: .inches(3.6), thickness: 2)

    Text("Scan to initiate return:", at: .inches(0.25, 0.65))
        .font(.default, height: .inches(0.1))

    QRCode("https://returns.example.com/RMA-2024-001234", at: .inches(0.25, 0.85))
        .magnification(5)

    Text("RMA# 2024-001234", at: .inches(1.6, 1.0))
        .font(.default, height: .inches(0.15))

    Text("Return to:", at: .inches(1.6, 1.3))
        .font(.default, height: .inches(0.1))
    Text("Returns Center", at: .inches(1.6, 1.45))
        .font(.default, height: .inches(0.12))
    Text("PO Box 12345", at: .inches(1.6, 1.6))
        .font(.default, height: .inches(0.1))
    Text("Memphis, TN 38118", at: .inches(1.6, 1.75))
        .font(.default, height: .inches(0.1))

    Box(at: .inches(0.1, 0.1), width: .inches(3.8), height: .inches(2.8))
        .thickness(2)
}

// MARK: - Template for Batch Shipping

/// Reusable template for printing many shipping labels
let shippingTemplate = ZPLTemplate(width: 4, height: 6, dpi: .dpi203) {
    Text("FROM: {{sender_name}}", at: .inches(0.2, 0.2))
        .font(.default, height: .inches(0.1))
    Text("{{sender_address}}", at: .inches(0.2, 0.35))
        .font(.default, height: .inches(0.1))

    HorizontalLine(at: .inches(0.1, 0.6), length: .inches(3.8), thickness: 3)

    Text("SHIP TO:", at: .inches(0.2, 0.7))
        .font(.default, height: .inches(0.1))
    Text("{{recipient_name}}", at: .inches(0.2, 0.9))
        .font(.default, height: .inches(0.18))
    Text("{{recipient_address}}", at: .inches(0.2, 1.15))
        .font(.default, height: .inches(0.12))
    Text("{{recipient_city_state_zip}}", at: .inches(0.2, 1.35))
        .font(.default, height: .inches(0.12))

    Barcode128("{{tracking_number}}", at: .inches(0.2, 1.7))?
        .height(.inches(0.7))
        .showText(true)
}

// MARK: - Usage

func printShippingExamples() {
    print("=== Shipping Label ===")
    print(shippingLabel.render())
    print()

    print("=== Return Label ===")
    print(returnLabel.render())
    print()

    // Template usage
    let customLabel = shippingTemplate.render(substituting: [
        "sender_name": "My Company",
        "sender_address": "100 Main St, Anytown USA",
        "recipient_name": "John Doe",
        "recipient_address": "789 Elm Street",
        "recipient_city_state_zip": "Chicago, IL 60601",
        "tracking_number": "1Z999AA10123456784"
    ])
    print("=== Template Label ===")
    print(customLabel)
}
