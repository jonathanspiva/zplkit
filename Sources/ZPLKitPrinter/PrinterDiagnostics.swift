import Foundation

/// Aggregate diagnostic snapshot from a Zebra printer.
///
/// Combines results from multiple query commands (`~HI`, `~HS`, `~HM`, `^HH`)
/// into a single struct. Use ``ZPLPrinter/queryDiagnostics()`` to retrieve this.
///
/// The ``settings`` field is optional because `^HH` can timeout when the
/// printer is in an error state (paper out, head open, etc.), while the
/// other commands typically still respond.
///
/// ## Example
///
/// ```swift
/// let printer = ZPLPrinter(host: "192.168.1.100")
/// let diag = try await printer.queryDiagnostics()
///
/// print("Model: \(diag.info.model)")
/// print("Serial: \(diag.serialNumber ?? "unknown")")
/// print("Ready: \(diag.isReadyToPrint)")
/// print("Lifetime: \(diag.lifetimeUsageInches ?? 0) inches")
/// ```
public struct PrinterDiagnostics: Sendable {
    /// Printer identification from `~HI`.
    public var info: PrinterInfo

    /// Current operational status from `~HS`.
    public var status: PrinterStatus

    /// RAM memory status from `~HM`.
    public var memory: MemoryStatus

    /// Parsed configuration settings from `^HH`. Nil if the query timed out.
    public var settings: PrinterSettings?

    // MARK: - Convenience Accessors

    /// Serial number from `^HH`, if available.
    public var serialNumber: String? {
        settings?.serialNumber
    }

    /// Lifetime usage counter in inches, if available.
    public var lifetimeUsageInches: Int? {
        settings?.nonresetCounterInches
    }

    /// Whether the printer is ready to accept and print labels.
    public var isReadyToPrint: Bool {
        status.isReadyToPrint
    }

    public init(
        info: PrinterInfo,
        status: PrinterStatus,
        memory: MemoryStatus,
        settings: PrinterSettings? = nil
    ) {
        self.info = info
        self.status = status
        self.memory = memory
        self.settings = settings
    }
}

// MARK: - CustomStringConvertible

extension PrinterDiagnostics: CustomStringConvertible {
    public var description: String {
        var lines: [String] = []

        lines.append("model: \(info.model)")
        lines.append("firmware: \(info.firmwareVersion)")
        lines.append("dpi: \(info.dpi)")
        lines.append("memory: \(memory.availableFormatted) free of \(memory.totalFormatted)")

        if let serial = settings?.serialNumber {
            lines.append("serial: \(serial)")
        }
        if let fw = settings?.firmware {
            lines.append("config_firmware: \(fw)")
        }
        if let lifetime = settings?.nonresetCounterInches {
            lines.append("lifetime_usage: \(lifetime) in")
        }
        if let headUsage = settings?.resetCounterInches {
            lines.append("head_usage: \(headUsage) in")
        }
        if let lastCleaned = settings?.lastCleanedInches {
            lines.append("last_cleaned: \(lastCleaned) in")
        }
        if let maxLen = settings?.maximumLengthInches {
            lines.append("max_length: \(maxLen) in")
        }

        lines.append("ready: \(status.isReadyToPrint)")
        if status.hasError {
            lines.append("errors: \(status)")
        }

        return lines.joined(separator: "\n")
    }
}
