import Foundation
import SwiftTUI
import ZPLKit
import ZPLKitPrinter

#if canImport(Darwin)
import Darwin
#endif

// MARK: - Recent Printers (persist to disk)

enum RecentPrinters {
    struct RecentEntry: Codable {
        let host: String
        var name: String?
        var lastUsed: Date
    }

    private static let dirPath = NSHomeDirectory() + "/.zpltool"
    private static let filePath = dirPath + "/recent.json"

    static func load() -> [RecentEntry] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
              let entries = try? JSONDecoder().decode([RecentEntry].self, from: data) else {
            return []
        }
        return entries.sorted { $0.lastUsed > $1.lastUsed }
    }

    static func save(host: String, name: String? = nil) {
        var entries = load()
        if let idx = entries.firstIndex(where: { $0.host == host }) {
            entries[idx].lastUsed = Date()
            if let name { entries[idx].name = name }
        } else {
            entries.append(RecentEntry(host: host, name: name, lastUsed: Date()))
        }
        entries.sort { $0.lastUsed > $1.lastUsed }
        if entries.count > 10 { entries = Array(entries.prefix(10)) }

        try? FileManager.default.createDirectory(
            atPath: dirPath, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: URL(fileURLWithPath: filePath))
        }
    }
}

// MARK: - Subnet Detection

func getLocalSubnet() -> String? {
    #if canImport(Darwin)
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }

    var result: String?
    var ptr: UnsafeMutablePointer<ifaddrs>? = first
    while let ifa = ptr {
        let name = String(cString: ifa.pointee.ifa_name)
        if name == "en0",
           let addr = ifa.pointee.ifa_addr,
           addr.pointee.sa_family == UInt8(AF_INET) {
            addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { sin in
                var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                var inAddr = sin.pointee.sin_addr
                inet_ntop(AF_INET, &inAddr, &buf, socklen_t(INET_ADDRSTRLEN))
                let ip = String(cString: buf)
                if let lastDot = ip.lastIndex(of: ".") {
                    result = String(ip[...lastDot])
                }
            }
        }
        ptr = ifa.pointee.ifa_next
    }
    return result
    #else
    return nil
    #endif
}

// MARK: - Scene Art Helpers

enum Art {
    static let bullet = "▸"

    // Dynamic-width logo: ░ bars and ░▒▓█ frame scale to terminal width
    static func logo(width w: Int) -> [String] {
        let inner = "Z · P · L · T · O · O · L"
        let sub   = "zebra printer cmd station"
        let contentWidth = max(inner.count, sub.count) + 4  // 4 for padding inside frame
        let frameWidth = max(contentWidth + 8, min(w - 4, 60))  // 8 for ░▒▓█ borders both sides
        let barWidth = frameWidth + 4  // outer ░ bars slightly wider

        let bar = String(repeating: "░", count: barWidth)
        let innerWidth = frameWidth - 8  // space between █ markers

        func centeredLine(_ text: String) -> String {
            let pad = innerWidth - text.count
            let left = pad / 2
            let right = pad - left
            return "  ░▒▓█" + String(repeating: " ", count: left) + text + String(repeating: " ", count: right) + "█▓▒░"
        }

        let blank = centeredLine(String(repeating: " ", count: 0))
        return [
            "  " + bar,
            blank,
            centeredLine(inner),
            centeredLine(sub),
            blank,
            "  " + bar,
        ]
    }

    // Dynamic-width divider: ──── ·· ──── pattern fills available width
    static func divider(width w: Int) -> String {
        let usable = max(20, w - 4)
        let seg = "────"
        let dot = " ·· "
        // Build pattern: seg dot [fill] dot seg
        let fixed = seg.count + dot.count + dot.count + seg.count
        let fillCount = max(0, usable - fixed)
        let fill = String(repeating: "─", count: fillCount)
        return "  " + seg + dot + fill + dot + seg
    }

    // Dynamic-width section header with ░▒▓ wings
    static func sectionHeader(_ title: String, width w: Int) -> String {
        let label = " \(title.uppercased()) "
        let inner = "▓▒" + label + "▒▓"
        let usable = max(inner.count + 6, w - 4)
        let wingTotal = usable - inner.count
        let leftWing = wingTotal / 2
        let rightWing = wingTotal - leftWing
        return "  " + String(repeating: "░", count: leftWing) + inner + String(repeating: "░", count: rightWing)
    }

    // Dynamic-width footer
    static func footer(width w: Int) -> String {
        let label = " zpltool · zplkit · 2026 "
        let usable = max(label.count + 4, w - 4)
        let wingTotal = usable - label.count - 4  // 4 for ░▒ and ▒░
        let leftWing = wingTotal / 2
        let rightWing = wingTotal - leftWing
        return "  " + String(repeating: "░", count: leftWing) + "▒" + label + "▒" + String(repeating: "░", count: rightWing)
    }
}

// MARK: - Reusable Views

struct ArtHeader: View {
    let width: Int
    var body: some View {
        let lines = Art.logo(width: width)
        ForEach(0..<lines.count, id: \.self) { i in
            Text(lines[i]).foregroundColor(.cyan)
        }
    }
}

struct ArtDivider: View {
    let width: Int
    var body: some View {
        Text(Art.divider(width: width)).foregroundColor(.brightBlack)
    }
}

struct SectionTitle: View {
    let title: String
    let width: Int
    var body: some View {
        Text(Art.sectionHeader(title, width: width)).foregroundColor(.magenta).bold()
    }
}

struct StatusBar: View {
    let text: String
    var body: some View {
        if !text.isEmpty {
            Text("  \(Art.bullet) \(text)").foregroundColor(.yellow)
        }
    }
}

struct ArtFooter: View {
    let width: Int
    var body: some View {
        Text("  arrows: navigate · enter: select · ctrl+c: quit").foregroundColor(.brightBlack)
        Text(Art.footer(width: width)).foregroundColor(.brightBlack)
    }
}

// MARK: - App Root

enum Screen {
    case home
    case dashboard
    case configure
    case rawZPL
}

struct TUIApp: View {
    @State private var screen: Screen = .home
    @State private var printerHost: String = ""
    @State private var printer: ZPLPrinter? = nil
    @State private var statusText: String = ""
    @State private var discoveredPrinters: [(name: String, host: String, port: UInt16)] = []

    var body: some View {
        VStack {
            switch screen {
            case .home:
                HomeScreen(
                    printerHost: $printerHost,
                    printer: $printer,
                    screen: $screen,
                    statusText: $statusText,
                    discoveredPrinters: $discoveredPrinters
                )
            case .dashboard:
                DashboardScreen(
                    printerHost: $printerHost,
                    printer: $printer,
                    screen: $screen,
                    statusText: $statusText
                )
            case .configure:
                ConfigureScreen(
                    printerHost: $printerHost,
                    printer: $printer,
                    screen: $screen,
                    statusText: $statusText
                )
            case .rawZPL:
                RawZPLScreen(
                    printerHost: $printerHost,
                    printer: $printer,
                    screen: $screen,
                    statusText: $statusText
                )
            }
        }
    }
}

// MARK: - Home Screen

struct HomeScreen: View {
    @Binding var printerHost: String
    @Binding var printer: ZPLPrinter?
    @Binding var screen: Screen
    @Binding var statusText: String
    @Binding var discoveredPrinters: [(name: String, host: String, port: UInt16)]

    @State private var recentPrinters: [RecentPrinters.RecentEntry] = []
    @State private var subnet: String = ""

    var body: some View {
        GeometryReader { size in
            let w = size.width.intValue
            VStack(alignment: .leading) {
                ArtHeader(width: w)

                SectionTitle(title: "connect", width: w)
                Group {
                    if subnet.isEmpty {
                        Text("  enter printer ip:").foregroundColor(.white)
                        TextField(placeholder: "192.168.x.x") { ip in
                            connectTo(host: ip)
                        }
                    } else {
                        Text("  enter printer ip:").foregroundColor(.white)
                        TextField(placeholder: "\(subnet)x") { ip in
                            let trimmed = ip.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            // If user typed just a number, prepend subnet
                            let host: String
                            if trimmed.contains(".") {
                                host = trimmed
                            } else {
                                host = subnet + trimmed
                            }
                            connectTo(host: host)
                        }
                    }
                }

                if !recentPrinters.isEmpty {
                    ArtDivider(width: w)
                    SectionTitle(title: "recent printers", width: w)
                    ForEach(0..<recentPrinters.count, id: \.self) { i in
                        let entry = recentPrinters[i]
                        let label = entry.name.map { "\($0) · \(entry.host)" } ?? entry.host
                        Button("  [ \(label) ]") {
                            connectTo(host: entry.host, name: entry.name)
                        }
                    }
                }

                Group {
                    ArtDivider(width: w)
                    SectionTitle(title: "discover", width: w)
                    Button("  \(Art.bullet) scan network (bonjour)") {
                        statusText = "scanning..."
                        Task { @MainActor in
                            let browser = ZPLPrinterBrowser()
                            browser.start()
                            try? await Task.sleep(nanoseconds: 5_000_000_000)
                            browser.stop()
                            let found = browser.discoveredPrinters
                            discoveredPrinters = found.map { (name: $0.name, host: $0.host, port: $0.port) }
                            if found.isEmpty {
                                statusText = "no printers found"
                            } else {
                                statusText = "found \(found.count) printer(s)"
                            }
                        }
                    }
                }

                if !discoveredPrinters.isEmpty {
                    ForEach(0..<discoveredPrinters.count, id: \.self) { i in
                        let p = discoveredPrinters[i]
                        Button("    \(Art.bullet) \(p.name) [\(p.host)]") {
                            printerHost = p.host
                            printer = ZPLPrinter(host: p.host, port: p.port, timeout: 10)
                            RecentPrinters.save(host: p.host, name: p.name)
                            statusText = "linked to \(p.name)"
                            screen = .dashboard
                        }
                    }
                }

                Group {
                    StatusBar(text: statusText)
                    ArtDivider(width: w)
                    ArtFooter(width: w)
                }
            }
            .padding()
            .onAppear {
                recentPrinters = RecentPrinters.load()
                subnet = getLocalSubnet() ?? ""
            }
        }
    }

    private func connectTo(host: String, name: String? = nil) {
        let h = host.trimmingCharacters(in: .whitespaces)
        guard !h.isEmpty else { return }
        printerHost = h
        printer = ZPLPrinter(host: h, timeout: 10)
        RecentPrinters.save(host: h, name: name)
        statusText = "linked to \(h)"
        screen = .dashboard
    }
}

// MARK: - Dashboard Screen

struct DashboardScreen: View {
    @Binding var printerHost: String
    @Binding var printer: ZPLPrinter?
    @Binding var screen: Screen
    @Binding var statusText: String

    @State private var infoLines: [String] = []
    @State private var statusLines: [String] = []

    var body: some View {
        GeometryReader { size in
            let w = size.width.intValue
            VStack(alignment: .leading) {
                Group {
                    HStack {
                        Text("  ░▒▓ \(printerHost) ▓▒░").foregroundColor(.cyan).bold()
                        Spacer()
                        Button("[ home ]") { screen = .home }
                    }
                    ArtDivider(width: w)
                    SectionTitle(title: "printer info", width: w)
                }

                if !infoLines.isEmpty {
                    ForEach(0..<infoLines.count, id: \.self) { i in
                        Text("  \(Art.bullet) \(infoLines[i])").foregroundColor(.white)
                    }
                }

                Group {
                    SectionTitle(title: "status", width: w)
                    if !statusLines.isEmpty {
                        ForEach(0..<statusLines.count, id: \.self) { i in
                            let line = statusLines[i]
                            if line.contains("***") {
                                Text("  \(Art.bullet) \(line)").foregroundColor(.red).bold()
                            } else if line.starts(with: "ready: true") {
                                Text("  \(Art.bullet) \(line)").foregroundColor(.green)
                            } else {
                                Text("  \(Art.bullet) \(line)").foregroundColor(.brightBlack)
                            }
                        }
                    }
                }

                Group {
                    ArtDivider(width: w)
                    SectionTitle(title: "actions", width: w)
                    HStack {
                        Button("[ refresh ]") { refreshStatus() }
                        Button("[ test label ]") { sendTestLabel() }
                        Button("[ feed ]") {
                            runCommand("feed") { try await printer?.feedLabel() }
                        }
                    }
                    HStack {
                        Button("[ calibrate ]") {
                            runCommand("calibrate") { try await printer?.calibrate() }
                        }
                        Button("[ calibrate-full ]") {
                            runCommand("calibrate-full") { try await printer?.calibrateFull() }
                        }
                        Button("[ pause ]") {
                            runCommand("pause") { try await printer?.togglePause() }
                        }
                    }
                    HStack {
                        Button("[ cancel all ]") {
                            runCommand("cancel all") { try await printer?.cancelAll() }
                        }
                        Button("[ power-on reset ]") {
                            runCommand("power-on reset") { try await printer?.powerOnReset() }
                        }
                    }
                    HStack {
                        Button("[ configure \(Art.bullet) ]") { screen = .configure }
                        Button("[ raw zpl \(Art.bullet) ]") { screen = .rawZPL }
                    }
                }

                Group {
                    StatusBar(text: statusText)
                    ArtFooter(width: w)
                }
            }
            .padding()
            .onAppear { refreshStatus() }
        }
    }

    private func refreshStatus() {
        guard let printer else { return }
        statusText = "querying..."
        Task { @MainActor in
            var info: [String] = []
            var status: [String] = []

            do {
                let i = try await printer.queryInfo()
                info.append("model: \(i.model)")
                info.append("firmware: \(i.firmwareVersion)")
                info.append("dpi: \(i.dpi)  dpmm: \(i.dotsPerMillimeter)")
                info.append("memory: \(i.memoryFormatted)")
                if !i.options.isEmpty {
                    info.append("options: \(i.options.joined(separator: ", "))")
                }
                // Save printer name for recent list
                RecentPrinters.save(host: printerHost, name: i.model)
            } catch {
                info.append("info error: \(error)")
            }

            do {
                let s = try await printer.queryStatus()
                status.append("ready: \(s.isReadyToPrint)")
                if s.isPaperOut { status.append("*** PAPER OUT ***") }
                if s.isRibbonOut { status.append("*** RIBBON OUT ***") }
                if s.isHeadOpen { status.append("*** HEAD OPEN ***") }
                if s.isPaused { status.append("*** PAUSED ***") }
                if s.isHeadTooHot { status.append("*** HEAD TOO HOT ***") }
                if s.isHeadCold { status.append("*** HEAD COLD ***") }
                if s.isReceiveBufferFull { status.append("*** BUFFER FULL ***") }
                status.append("label length: \(s.labelLengthInDots) dots")
            } catch {
                status.append("status error: \(error)")
            }

            do {
                let m = try await printer.queryMemory()
                status.append("ram: \(m.usedFormatted)/\(m.totalFormatted) (\(m.usagePercent)%)")
            } catch {
                status.append("memory error: \(error)")
            }

            infoLines = info
            statusLines = status
            statusText = ""
        }
    }

    private func sendTestLabel() {
        guard let printer else { return }
        statusText = "printing test label..."
        Task { @MainActor in
            let now = ISO8601DateFormatter().string(from: Date())
            let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
                ZPLKit.Text("ZPLTool Test Label", at: .dots(30, 30))
                    .font(.default, height: .dots(30))
                Barcode128("ZPLTOOL-TEST", at: .dots(30, 80))!
                    .height(.dots(60))
                    .showText(true)
                ZPLKit.Text(now, at: .dots(30, 170))
                    .font(.default, height: .dots(16))
                ZPLKit.Text("Host: \(printerHost)", at: .dots(30, 195))
                    .font(.default, height: .dots(16))
                Box(at: .dots(5, 5), width: .dots(802), height: .dots(396))
                    .thickness(2)
            }
            do {
                try await printer.send(label.render())
                statusText = "test label sent"
            } catch {
                statusText = "send error: \(error)"
            }
        }
    }

    private func runCommand(_ name: String, action: @escaping () async throws -> Void) {
        statusText = "\(name)..."
        Task { @MainActor in
            do {
                try await action()
                statusText = "\(name): ok"
            } catch {
                statusText = "\(name) error: \(error)"
            }
        }
    }
}

// MARK: - Configure Screen

struct ConfigureScreen: View {
    @Binding var printerHost: String
    @Binding var printer: ZPLPrinter?
    @Binding var screen: Screen
    @Binding var statusText: String

    @State private var configLoaded: Bool = false
    @State private var configFailed: Bool = false
    @State private var currentDarkness: String = "—"
    @State private var currentSpeed: String = "—"
    @State private var currentMediaType: String = "—"
    @State private var currentTracking: String = "—"

    var body: some View {
        GeometryReader { size in
            let w = size.width.intValue
            VStack(alignment: .leading) {
                HStack {
                    Text("  ░▒▓ configure · \(printerHost) ▓▒░").foregroundColor(.cyan).bold()
                    Spacer()
                    Button("[ dashboard ]") { screen = .dashboard }
                }
                ArtDivider(width: w)

                if !configLoaded && !configFailed {
                    Text("  reading configuration from printer...").foregroundColor(.yellow)
                    StatusBar(text: statusText)
                    ArtFooter(width: w)
                } else if configFailed {
                    Text("  config read failed (printer may be in error state)").foregroundColor(.red)
                    HStack {
                        Button("[ retry ]") { loadCurrentConfig() }
                        Button("[ continue anyway ]") { configLoaded = true; configFailed = false }
                    }
                    StatusBar(text: statusText)
                    ArtFooter(width: w)
                } else {
                    Group {
                        SectionTitle(title: "darkness", width: w)
                        Text("  current: \(currentDarkness)").foregroundColor(.green)
                        Text("  value 0-30:").foregroundColor(.brightBlack)
                        TextField(placeholder: "e.g. 15") { value in
                            guard let v = Int(value), v >= 0, v <= 30 else {
                                statusText = "darkness must be 0-30"
                                return
                            }
                            applyConfig("darkness=\(v)") { PrinterConfiguration().darkness(v) }
                        }
                        SectionTitle(title: "speed", width: w)
                        Text("  current: \(currentSpeed)").foregroundColor(.green)
                        Text("  inches per second:").foregroundColor(.brightBlack)
                        TextField(placeholder: "e.g. 4") { value in
                            guard let v = Int(value), v >= 1, v <= 14 else {
                                statusText = "speed must be 1-14"
                                return
                            }
                            applyConfig("speed=\(v)") { PrinterConfiguration().printSpeedIPS(v) }
                        }
                    }

                    Group {
                        ArtDivider(width: w)
                        SectionTitle(title: "media type", width: w)
                        Text("  current: \(currentMediaType)").foregroundColor(.green)
                        HStack {
                            Button("[ direct thermal ]") {
                                applyConfig("media=direct-thermal") {
                                    PrinterConfiguration().mediaType(.directThermal)
                                }
                            }
                            Button("[ thermal transfer ]") {
                                applyConfig("media=thermal-transfer") {
                                    PrinterConfiguration().mediaType(.thermalTransfer)
                                }
                            }
                        }
                        SectionTitle(title: "media tracking", width: w)
                        Text("  current: \(currentTracking)").foregroundColor(.green)
                        HStack {
                            Button("[ gap ]") {
                                applyConfig("tracking=gap") { PrinterConfiguration().mediaTracking(.gap) }
                            }
                            Button("[ continuous ]") {
                                applyConfig("tracking=continuous") { PrinterConfiguration().mediaTracking(.continuous) }
                            }
                            Button("[ mark ]") {
                                applyConfig("tracking=mark") { PrinterConfiguration().mediaTracking(.mark) }
                            }
                            Button("[ auto ]") {
                                applyConfig("tracking=auto") { PrinterConfiguration().mediaTracking(.auto) }
                            }
                        }
                    }

                    Group {
                        ArtDivider(width: w)
                        SectionTitle(title: "eeprom", width: w)
                        HStack {
                            Button("[ save ]") {
                                runPrinterCommand("save") { try await printer?.saveConfiguration() }
                            }
                            Button("[ restore ]") {
                                runPrinterCommand("restore") { try await printer?.restoreConfiguration() }
                            }
                            Button("[ factory reset ]") {
                                runPrinterCommand("factory reset") { try await printer?.factoryReset() }
                            }
                        }
                        StatusBar(text: statusText)
                        ArtFooter(width: w)
                    }
                }
            }
            .padding()
            .onAppear { loadCurrentConfig() }
        }
    }

    private func loadCurrentConfig() {
        guard let printer else { return }
        configLoaded = false
        configFailed = false
        statusText = "reading config..."
        Task { @MainActor in
            do {
                let s = try await printer.queryConfiguration()
                currentDarkness = s.darkness.map { "\($0)" } ?? "—"
                currentSpeed = s.printSpeed.map { "\($0) IPS" } ?? "—"
                if let mt = s.mediaType {
                    currentMediaType = mt == .directThermal ? "direct-thermal" : "thermal-transfer"
                }
                if let tr = s.mediaTracking {
                    switch tr {
                    case .gap: currentTracking = "gap"
                    case .continuous: currentTracking = "continuous"
                    case .mark: currentTracking = "mark"
                    case .auto: currentTracking = "auto"
                    }
                }
                configLoaded = true
                statusText = ""
            } catch {
                configFailed = true
                statusText = "config read failed: \(error)"
            }
        }
    }

    private func applyConfig(_ desc: String, config: () -> PrinterConfiguration) {
        guard let printer else { return }
        let c = config()
        statusText = "applying \(desc)..."
        Task { @MainActor in
            do {
                try await printer.apply(c)
                try await printer.saveConfiguration()
                statusText = "\(desc) applied + saved"
                loadCurrentConfig()
            } catch {
                statusText = "error: \(error)"
            }
        }
    }

    private func runPrinterCommand(_ name: String, action: @escaping () async throws -> Void) {
        statusText = "\(name)..."
        Task { @MainActor in
            do {
                try await action()
                statusText = "\(name): ok"
            } catch {
                statusText = "\(name) error: \(error)"
            }
        }
    }
}

// MARK: - Raw ZPL Screen

struct RawZPLScreen: View {
    @Binding var printerHost: String
    @Binding var printer: ZPLPrinter?
    @Binding var screen: Screen
    @Binding var statusText: String

    @State private var responseText: String = ""

    var body: some View {
        GeometryReader { size in
            let w = size.width.intValue
            VStack(alignment: .leading) {
                HStack {
                    Text("  ░▒▓ raw zpl · \(printerHost) ▓▒░").foregroundColor(.cyan).bold()
                    Spacer()
                    Button("[ dashboard ]") { screen = .dashboard }
                }
                ArtDivider(width: w)

                Group {
                    SectionTitle(title: "send", width: w)
                    Text("  fire-and-forget (press enter):").foregroundColor(.brightBlack)
                    TextField(placeholder: "^XA...^XZ or ~PP") { zpl in
                        let cmd = zpl.trimmingCharacters(in: .whitespaces)
                        guard !cmd.isEmpty, let printer else { return }
                        statusText = "sending..."
                        Task { @MainActor in
                            do {
                                try await printer.send(cmd)
                                statusText = "sent ok"
                            } catch {
                                statusText = "send error: \(error)"
                            }
                        }
                    }
                }

                Group {
                    ArtDivider(width: w)
                    SectionTitle(title: "query", width: w)
                    Text("  send + wait for response:").foregroundColor(.brightBlack)
                    TextField(placeholder: "~HI or ~HS or ^XA^HZa^XZ") { cmd in
                        let command = cmd.trimmingCharacters(in: .whitespaces)
                        guard !command.isEmpty, let printer else { return }
                        statusText = "querying..."
                        Task { @MainActor in
                            do {
                                let data = try await printer.query(command, responseTimeout: 10)
                                if let str = String(data: data, encoding: .utf8) {
                                    responseText = str
                                } else {
                                    responseText = "(\(data.count) bytes, non-UTF8)"
                                }
                                statusText = "response received"
                            } catch {
                                responseText = ""
                                statusText = "query error: \(error)"
                            }
                        }
                    }
                }

                if !responseText.isEmpty {
                    SectionTitle(title: "response", width: w)
                    Text("  \(responseText)").foregroundColor(.green)
                }

                Group {
                    StatusBar(text: statusText)
                    ArtFooter(width: w)
                }
            }
            .padding()
        }
    }
}
