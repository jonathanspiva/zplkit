/// PartsBinLabel.swift
/// Labels for parts bins, storage containers, and component organization.

import ZPLKit

// MARK: - Small Parts Bin Label

/// Compact label for small parts bins
let smallPartsBinLabel = ZPLLabel(width: 2, height: 1, dpi: .dpi203) {
    // Part number (prominent)
    Text("M6-NUT-SS", at: .inches(0.1, 0.1))
        .font(.default, height: .inches(0.18))

    // Description
    Text("M6 Hex Nut, Stainless", at: .inches(0.1, 0.35))
        .font(.default, height: .inches(0.08))

    // Bin location
    Text("BIN: A-14", at: .inches(1.4, 0.1))
        .font(.default, height: .inches(0.1))

    // Small barcode
    Barcode128("M6NUTSS", at: .inches(0.1, 0.5))
        .height(.inches(0.25))
        .moduleWidth(1)

    // Min/Max stock levels
    Text("Min:100 Max:500", at: .inches(0.1, 0.85))
        .font(.default, height: .inches(0.06))

    // Border
    Box(at: .inches(0.02, 0.02), width: .inches(1.96), height: .inches(0.96))
        .thickness(2)
}

// MARK: - Medium Parts Bin Label (with reorder info)

/// Label with full part details and reorder information
let mediumPartsBinLabel = ZPLLabel(width: 3, height: 2, dpi: .dpi203) {
    // Header bar
    Box(at: .inches(0.05, 0.05), width: .inches(2.9), height: .inches(0.35))
        .filled()
    Text("FASTENERS", at: .inches(0.15, 0.12))
        .font(.default, height: .inches(0.15))
        .reversed()

    // Part number
    Text("M8-BOLT-HEX-30", at: .inches(0.15, 0.5))
        .font(.default, height: .inches(0.2))

    // Description
    Text("M8 x 30mm Hex Bolt", at: .inches(0.15, 0.75))
        .font(.default, height: .inches(0.1))
    Text("Grade 8.8, Zinc Plated", at: .inches(0.15, 0.9))
        .font(.default, height: .inches(0.08))

    // Barcode
    Barcode128("M8BOLTHEX30", at: .inches(0.15, 1.05))
        .height(.inches(0.35))
        .showText(true)

    // Stock info box
    Box(at: .inches(0.1, 1.55), width: .inches(1.3), height: .inches(0.35))
        .thickness(1)
    Text("MIN: 50  MAX: 200", at: .inches(0.15, 1.62))
        .font(.default, height: .inches(0.1))

    // Location box
    Box(at: .inches(1.55, 1.55), width: .inches(1.3), height: .inches(0.35))
        .thickness(1)
    Text("LOC: C-22-4", at: .inches(1.65, 1.62))
        .font(.default, height: .inches(0.1))

    // Outer border
    Box(at: .inches(0.02, 0.02), width: .inches(2.96), height: .inches(1.96))
        .thickness(3)
}

// MARK: - Kanban Card Label

/// Two-bin kanban system card
let kanbanCardLabel = ZPLLabel(width: 4, height: 3, dpi: .dpi203) {
    // KANBAN header
    Box(at: .inches(0.1, 0.1), width: .inches(3.8), height: .inches(0.4))
        .filled()
    Text("KANBAN", at: .inches(1.6, 0.18))
        .font(.default, height: .inches(0.2))
        .reversed()

    // Part info
    Text("PART:", at: .inches(0.2, 0.6))
        .font(.default, height: .inches(0.1))
    Text("WASHER-M10-FLAT", at: .inches(0.2, 0.75))
        .font(.default, height: .inches(0.18))

    Text("DESC:", at: .inches(0.2, 1.0))
        .font(.default, height: .inches(0.1))
    Text("M10 Flat Washer, Zinc", at: .inches(0.2, 1.15))
        .font(.default, height: .inches(0.12))

    // Quantity box
    Box(at: .inches(0.15, 1.4), width: .inches(1.5), height: .inches(0.5))
        .thickness(2)
    Text("QTY: 100", at: .inches(0.35, 1.55))
        .font(.default, height: .inches(0.18))

    // Supplier info
    Text("SUPPLIER:", at: .inches(2.0, 1.4))
        .font(.default, height: .inches(0.08))
    Text("FastenerCo", at: .inches(2.0, 1.55))
        .font(.default, height: .inches(0.12))
    Text("P/N: FC-W10F", at: .inches(2.0, 1.7))
        .font(.default, height: .inches(0.1))

    // Barcodes
    Barcode128("WASHERM10FLAT", at: .inches(0.2, 2.05))
        .height(.inches(0.4))
        .showText(true)

    QRCode("https://inventory.example.com/reorder/WASHER-M10-FLAT", at: .inches(3.0, 2.0))
        .magnification(3)
    Text("SCAN TO", at: .inches(2.95, 2.55))
        .font(.default, height: .inches(0.06))
    Text("REORDER", at: .inches(2.95, 2.65))
        .font(.default, height: .inches(0.06))

    // Storage location
    Text("STORE: D-08-1", at: .inches(0.2, 2.6))
        .font(.default, height: .inches(0.12))

    // Border
    Box(at: .inches(0.05, 0.05), width: .inches(3.9), height: .inches(2.9))
        .thickness(3)
}

// MARK: - Tool Crib Label

/// Label for tool storage and checkout systems
let toolCribLabel = ZPLLabel(width: 3, height: 1.5, dpi: .dpi203) {
    // Tool ID
    Text("TOOL ID:", at: .inches(0.15, 0.1))
        .font(.default, height: .inches(0.08))
    Text("DRL-1/4-HSS", at: .inches(0.15, 0.22))
        .font(.default, height: .inches(0.18))

    // Description
    Text("1/4\" HSS Drill Bit", at: .inches(0.15, 0.45))
        .font(.default, height: .inches(0.1))

    // Drawer/location
    Box(at: .inches(2.0, 0.1), width: .inches(0.85), height: .inches(0.5))
        .thickness(2)
    Text("DRAWER", at: .inches(2.15, 0.15))
        .font(.default, height: .inches(0.08))
    Text("B-4", at: .inches(2.2, 0.32))
        .font(.default, height: .inches(0.15))

    // Barcode for checkout system
    Barcode128("DRL14HSS", at: .inches(0.15, 0.65))
        .height(.inches(0.35))
        .showText(true)

    // Calibration/replacement date
    Text("REPLACE BY: 2024-06", at: .inches(0.15, 1.15))
        .font(.default, height: .inches(0.08))

    // Border
    Box(at: .inches(0.05, 0.05), width: .inches(2.9), height: .inches(1.4))
        .thickness(2)
}

// MARK: - Template for Batch Printing

/// Template for printing many bin labels from a data source
let partsBinTemplate = ZPLTemplate(width: 2, height: 1, dpi: .dpi203) {
    Text("{{part_number}}", at: .inches(0.1, 0.1))
        .font(.default, height: .inches(0.15))

    Text("{{description}}", at: .inches(0.1, 0.3))
        .font(.default, height: .inches(0.07))

    Text("BIN: {{location}}", at: .inches(1.3, 0.1))
        .font(.default, height: .inches(0.08))

    Barcode128("{{barcode}}", at: .inches(0.1, 0.45))
        .height(.inches(0.25))
        .moduleWidth(1)

    Text("Min:{{min}} Max:{{max}}", at: .inches(0.1, 0.8))
        .font(.default, height: .inches(0.06))

    Box(at: .inches(0.02, 0.02), width: .inches(1.96), height: .inches(0.96))
        .thickness(2)
}

// Usage:
// let labels = parts.map { part in
//     partsBinTemplate.render(with: [
//         "part_number": part.number,
//         "description": part.description,
//         "location": part.binLocation,
//         "barcode": part.barcode,
//         "min": String(part.minStock),
//         "max": String(part.maxStock)
//     ])
// }
