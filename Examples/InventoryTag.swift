/// InventoryTag.swift
/// Warehouse and inventory management label examples.

import ZPLKit

// MARK: - Warehouse Location Tag

/// Label for marking warehouse shelf locations
let warehouseLocationTag = ZPLLabel(width: 3, height: 2, dpi: .dpi203) {
    // Large location code
    Text("A-14-3", at: .inches(0.25, 0.25))
        .font(.default, height: .inches(0.5))

    // Zone indicator
    Box(at: .inches(2.0, 0.15), width: .inches(0.8), height: .inches(0.4))
        .filled()
    Text("ZONE A", at: .inches(2.05, 0.25))
        .font(.default, height: .inches(0.12))
        .reversed()

    // Divider
    HorizontalLine(at: .inches(0.1, 0.85), length: .inches(2.8), thickness: 2)

    // Barcode for scanning
    Barcode128("LOC-A-14-3", at: .inches(0.25, 1.0))
        .height(.inches(0.4))
        .showText(true)

    // Capacity info
    Text("Cap: 500 units", at: .inches(0.25, 1.6))
        .font(.default, height: .inches(0.1))

    // Border
    Box(at: .inches(0.05, 0.05), width: .inches(2.9), height: .inches(1.9))
        .thickness(3)
}

// MARK: - Asset Tag

/// Tag for tracking equipment and assets
let assetTag = ZPLLabel(width: 2, height: 0.75, dpi: .dpi203) {
    Text("ASSET #", at: .inches(0.1, 0.08))
        .font(.default, height: .inches(0.08))

    Text("A-2024-00147", at: .inches(0.1, 0.2))
        .font(.default, height: .inches(0.15))

    // Small barcode
    Barcode128("A2024147", at: .inches(0.1, 0.4))
        .height(.inches(0.2))
        .moduleWidth(1)

    // Company logo area (placeholder box)
    Box(at: .inches(1.5, 0.1), width: .inches(0.4), height: .inches(0.4))
        .thickness(1)
}

// MARK: - Pallet Label

/// Large label for pallets with multiple barcodes
let palletLabel = ZPLLabel(width: 4, height: 6, dpi: .dpi203) {
    // Header
    Box(at: .inches(0.1, 0.1), width: .inches(3.8), height: .inches(0.6))
        .filled()
    Text("PALLET ID", at: .inches(1.4, 0.25))
        .font(.default, height: .inches(0.25))
        .reversed()

    // Large pallet number
    Text("PLT-2024-001234", at: .inches(0.25, 0.9))
        .font(.default, height: .inches(0.35))

    // Main barcode (large, scannable from distance)
    Barcode128("PLT2024001234", at: .inches(0.25, 1.4))
        .height(.inches(1.0))
        .showText(true)
        .moduleWidth(3)

    // Divider
    HorizontalLine(at: .inches(0.1, 2.7), length: .inches(3.8), thickness: 4)

    // Contents summary
    Text("CONTENTS:", at: .inches(0.25, 2.85))
        .font(.default, height: .inches(0.12))

    Text("SKU: WIDGET-PRO-BLK", at: .inches(0.25, 3.05))
        .font(.default, height: .inches(0.15))
    Text("QTY: 48 CASES", at: .inches(0.25, 3.3))
        .font(.default, height: .inches(0.15))
    Text("WEIGHT: 432 LBS", at: .inches(0.25, 3.55))
        .font(.default, height: .inches(0.15))

    // SKU barcode
    Barcode128("WIDGET-PRO-BLK", at: .inches(0.25, 3.85))
        .height(.inches(0.5))
        .showText(true)

    // Destination
    HorizontalLine(at: .inches(0.1, 4.6), length: .inches(3.8), thickness: 2)
    Text("DEST: DOCK 7 - OUTBOUND", at: .inches(0.25, 4.75))
        .font(.default, height: .inches(0.15))

    // Date/time
    Text("2024-01-15 14:30", at: .inches(0.25, 5.0))
        .font(.default, height: .inches(0.1))

    // QR for full pallet manifest
    QRCode("https://wms.example.com/pallet/PLT2024001234", at: .inches(2.5, 4.7))
        .magnification(4)

    // Outer border
    Box(at: .inches(0.05, 0.05), width: .inches(3.9), height: .inches(5.9))
        .thickness(4)
}

// MARK: - Receiving Label

/// Label printed when items are received into inventory
let receivingLabel = ZPLLabel(width: 4, height: 3, dpi: .dpi203) {
    Text("RECEIVED", at: .inches(0.25, 0.2))
        .font(.default, height: .inches(0.2))

    // PO Number
    Text("PO# 78432", at: .inches(2.5, 0.25))
        .font(.default, height: .inches(0.12))

    HorizontalLine(at: .inches(0.1, 0.5), length: .inches(3.8), thickness: 2)

    // Item details
    Text("SKU: BOLT-M6-SS-25", at: .inches(0.25, 0.65))
        .font(.default, height: .inches(0.12))
    Text("M6 x 25mm Stainless Bolt", at: .inches(0.25, 0.85))
        .font(.default, height: .inches(0.15))
    Text("QTY RECEIVED: 500", at: .inches(0.25, 1.1))
        .font(.default, height: .inches(0.15))

    // Barcodes
    Barcode128("BOLT-M6-SS-25", at: .inches(0.25, 1.4))
        .height(.inches(0.4))
        .showText(true)

    // Location assignment
    Box(at: .inches(0.15, 2.0), width: .inches(1.8), height: .inches(0.4))
        .thickness(2)
    Text("PUT AWAY: B-07-2", at: .inches(0.25, 2.1))
        .font(.default, height: .inches(0.15))

    // Receiver initials box
    Text("RCVD BY:", at: .inches(2.5, 2.0))
        .font(.default, height: .inches(0.08))
    Box(at: .inches(2.5, 2.1), width: .inches(0.5), height: .inches(0.3))
        .thickness(1)

    // Date
    Text("2024-01-15", at: .inches(3.1, 2.2))
        .font(.default, height: .inches(0.1))

    // Border
    Box(at: .inches(0.05, 0.05), width: .inches(3.9), height: .inches(2.9))
        .thickness(2)
}

// MARK: - Batch Inventory Labels with Serial Numbers

/// Print multiple labels with incrementing serial numbers
let serializedInventoryLabels = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
    Text("ITEM #", at: .inches(0.1, 0.1))
        .font(.default, height: .inches(0.1))

    SerialNumber("00001", at: .inches(0.1, 0.25))
        .font(.default, height: .inches(0.2))
        .increment(1)
        .padWithZeros(true)

    Barcode128("ITM00001", at: .inches(0.1, 0.55))
        .height(.inches(0.25))
        .moduleWidth(1)
}
// Use with .printQuantity(100) to print items 00001-00100
