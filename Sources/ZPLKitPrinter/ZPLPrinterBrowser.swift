import Foundation
import Network

/// Discovers Zebra printers on the local network via Bonjour/mDNS.
///
/// ZPLPrinterBrowser scans for printers advertising the `_pdl-datastream._tcp`
/// service, which is the standard service type for raw TCP printing.
///
/// ## Usage
///
/// ```swift
/// let browser = ZPLPrinterBrowser()
///
/// // Async iteration
/// for await printer in browser.printers {
///     print("Found: \(printer.name) at \(printer.host)")
/// }
///
/// // Or get current list
/// let current = browser.discoveredPrinters
/// ```
///
/// ## Lifecycle
///
/// The browser starts automatically when you access `printers` or call `start()`.
/// Call `stop()` when you're done to release resources.
public final class ZPLPrinterBrowser: @unchecked Sendable {
    /// Service type for raw TCP printing (used by Zebra and other label printers).
    public static let serviceType = "_pdl-datastream._tcp"

    // NWBrowser is terminal once cancelled and cannot be restarted, so it is
    // recreated on the next start() after a stop(). Guarded by `lock`.
    private var browser: NWBrowser
    private let queue = DispatchQueue(label: "ZPLPrinterBrowser", qos: .userInitiated)

    private var discovered: [String: DiscoveredPrinter] = [:]
    private var continuations: [UUID: AsyncStream<DiscoveredPrinter>.Continuation] = [:]
    private let lock = NSLock()

    private var isStarted = false

    // Set when the current browser instance has been cancelled. A cancelled
    // NWBrowser is dead and must be replaced before browsing can resume.
    private var browserIsTerminal = false

    /// Creates a new printer browser.
    public init() {
        self.browser = Self.makeBrowser()
        setupBrowser()
    }

    /// Builds a fresh NWBrowser configured for the printing service type.
    private static func makeBrowser() -> NWBrowser {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        return NWBrowser(
            for: .bonjour(type: Self.serviceType, domain: nil),
            using: parameters
        )
    }

    deinit {
        stop()
    }

    /// The currently discovered printers.
    public var discoveredPrinters: [DiscoveredPrinter] {
        lock.lock()
        defer { lock.unlock() }
        return Array(discovered.values)
    }

    /// An async sequence of discovered printers.
    ///
    /// Each printer is emitted as it's discovered. The sequence continues
    /// until the browser is stopped.
    public var printers: AsyncStream<DiscoveredPrinter> {
        start()

        return AsyncStream { continuation in
            let id = UUID()

            lock.lock()
            continuations[id] = continuation
            // Emit already-discovered printers
            for printer in discovered.values {
                continuation.yield(printer)
            }
            lock.unlock()

            continuation.onTermination = { [weak self] _ in
                self?.lock.lock()
                self?.continuations.removeValue(forKey: id)
                self?.lock.unlock()
            }
        }
    }

    /// Starts browsing for printers.
    ///
    /// Browsing starts automatically when you access `printers`. Call this
    /// method explicitly if you want to pre-warm the discovery.
    public func start() {
        lock.lock()
        defer { lock.unlock() }

        guard !isStarted else { return }

        // If the previous browser was cancelled (via stop()), it is terminal
        // and cannot be restarted. Replace it with a fresh instance so the
        // public API keeps working after stop().
        if browserIsTerminal {
            browser = Self.makeBrowser()
            browserIsTerminal = false
            setupBrowser()
        }

        isStarted = true
        browser.start(queue: queue)
    }

    /// Stops browsing and releases resources.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        guard isStarted else { return }
        isStarted = false
        browser.cancel()
        // The cancelled browser is terminal; the next start() must recreate it.
        browserIsTerminal = true

        for continuation in continuations.values {
            continuation.finish()
        }
        continuations.removeAll()
        discovered.removeAll()
    }

    private func setupBrowser() {
        browser.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed:
                // NOTE: NWBrowser failed. There is no error channel on the
                // public AsyncStream API, so we stop browsing (which finishes
                // the stream) rather than leaking to the host app's console.
                self?.stop()
            case .cancelled:
                break
            default:
                break
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, changes in
            self?.handleResults(results, changes: changes)
        }
    }

    private func handleResults(_ results: Set<NWBrowser.Result>, changes: Set<NWBrowser.Result.Change>) {
        for change in changes {
            switch change {
            case .added(let result):
                resolveEndpoint(result)

            case .removed(let result):
                removeResult(result)

            case .changed(old: _, new: let result, flags: _):
                resolveEndpoint(result)

            case .identical:
                break

            @unknown default:
                break
            }
        }
    }

    private func resolveEndpoint(_ result: NWBrowser.Result) {
        // Extract name from the result
        guard case .service(let name, _, _, _) = result.endpoint else { return }

        let id = endpointID(result)

        // Create a connection to resolve the endpoint
        let connection = NWConnection(to: result.endpoint, using: .tcp)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                // Get the resolved endpoint
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = endpoint {
                    let hostString: String
                    switch host {
                    case .ipv4(let addr):
                        hostString = self?.ipv4String(addr) ?? "unknown"
                    case .ipv6(let addr):
                        hostString = self?.ipv6String(addr) ?? "unknown"
                    case .name(let hostname, _):
                        hostString = hostname
                    @unknown default:
                        hostString = "unknown"
                    }

                    let printer = DiscoveredPrinter(
                        id: id,
                        name: name,
                        host: hostString,
                        port: port.rawValue,
                        metadata: self?.extractMetadata(result) ?? [:]
                    )

                    self?.addPrinter(printer)
                }
                connection.cancel()

            case .failed, .cancelled:
                connection.cancel()

            default:
                break
            }
        }

        connection.start(queue: queue)

        // Cancel after timeout to avoid hanging
        queue.asyncAfter(deadline: .now() + 5) {
            connection.cancel()
        }
    }

    private func addPrinter(_ printer: DiscoveredPrinter) {
        lock.lock()
        let isNew = discovered[printer.id] == nil
        discovered[printer.id] = printer

        if isNew {
            for continuation in continuations.values {
                continuation.yield(printer)
            }
        }
        lock.unlock()
    }

    private func removeResult(_ result: NWBrowser.Result) {
        let id = endpointID(result)

        lock.lock()
        discovered.removeValue(forKey: id)
        lock.unlock()
    }

    private func endpointID(_ result: NWBrowser.Result) -> String {
        if case .service(let name, let type, let domain, _) = result.endpoint {
            return "\(name).\(type).\(domain)"
        }
        return UUID().uuidString
    }

    private func extractMetadata(_ result: NWBrowser.Result) -> [String: String] {
        guard case .bonjour(let record) = result.metadata else {
            return [:]
        }

        var metadata: [String: String] = [:]
        for (key, value) in record.dictionary {
            metadata[key] = value
        }
        return metadata
    }

    private func ipv4String(_ addr: IPv4Address) -> String {
        addr.debugDescription
    }

    private func ipv6String(_ addr: IPv6Address) -> String {
        addr.debugDescription
    }
}
