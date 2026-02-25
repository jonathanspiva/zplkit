import Foundation
import SwiftTUI
import ZPLKit
import ZPLKitPrinter

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

    var body: some View {
        VStack(alignment: .leading) {
            Text("ZPLTool").bold()
            Divider()

            Text("Enter printer IP:")
            TextField(placeholder: "192.168.x.x") { ip in
                let host = ip.trimmingCharacters(in: .whitespaces)
                guard !host.isEmpty else { return }
                printerHost = host
                printer = ZPLPrinter(host: host, timeout: 10)
                statusText = "Connected to \(host)"
                screen = .dashboard
            }

            Spacer()
            Divider()

            Button("Discover Printers (Bonjour)") {
                statusText = "Scanning..."
                Task {
                    let browser = ZPLPrinterBrowser()
                    browser.start()
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    browser.stop()
                    let found = browser.discoveredPrinters
                    discoveredPrinters = found.map { (name: $0.name, host: $0.host, port: $0.port) }
                    if found.isEmpty {
                        statusText = "No printers found"
                    } else {
                        statusText = "Found \(found.count) printer(s)"
                    }
                }
            }

            if !discoveredPrinters.isEmpty {
                Spacer()
                Text("Found printers:")
                ForEach(0..<discoveredPrinters.count, id: \.self) { i in
                    let p = discoveredPrinters[i]
                    Button("\(p.name) (\(p.host))") {
                        printerHost = p.host
                        printer = ZPLPrinter(host: p.host, port: p.port, timeout: 10)
                        statusText = "Connected to \(p.name)"
                        screen = .dashboard
                    }
                }
            }

            if !statusText.isEmpty {
                Spacer()
                Text(statusText).foregroundColor(.yellow)
            }
        }
        .padding()
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
        VStack(alignment: .leading) {
            HStack {
                Text("Printer: \(printerHost)").bold()
                Spacer()
                Button("< Home") {
                    screen = .home
                }
            }
            Divider()

            if !infoLines.isEmpty {
                ForEach(0..<infoLines.count, id: \.self) { i in
                    Text(infoLines[i])
                }
                Spacer()
            }
            if !statusLines.isEmpty {
                ForEach(0..<statusLines.count, id: \.self) { i in
                    let line = statusLines[i]
                    if line.contains("***") {
                        Text(line).foregroundColor(.red).bold()
                    } else if line.starts(with: "ready: true") {
                        Text(line).foregroundColor(.green)
                    } else {
                        Text(line)
                    }
                }
                Spacer()
            }

            Divider()
            Text("Actions:").bold()

            HStack {
                Button("Refresh Status") {
                    refreshStatus()
                }
                Button("Send Test Label") {
                    sendTestLabel()
                }
                Button("Feed Label") {
                    feedLabel()
                }
            }

            HStack {
                Button("Calibrate") {
                    runCommand("calibrate") {
                        try await printer?.calibrate()
                    }
                }
                Button("Pause/Resume") {
                    runCommand("pause") {
                        try await printer?.send("~PP")
                    }
                }
                Button("Cancel Jobs") {
                    runCommand("cancel") {
                        try await printer?.send("~JA")
                    }
                }
            }

            HStack {
                Button("Configure >") {
                    screen = .configure
                }
                Button("Raw ZPL >") {
                    screen = .rawZPL
                }
            }

            if !statusText.isEmpty {
                Spacer()
                Text(statusText).foregroundColor(.yellow)
            }
        }
        .padding()
        .onAppear {
            refreshStatus()
        }
    }

    private func refreshStatus() {
        guard let printer else { return }
        statusText = "Querying..."
        Task {
            var info: [String] = []
            var status: [String] = []

            do {
                let i = try await printer.queryInfo()
                info.append("Model: \(i.model)")
                info.append("Firmware: \(i.firmwareVersion)")
                info.append("DPI: \(i.dpi)")
                info.append("Memory: \(i.memoryFormatted)")
                if !i.options.isEmpty {
                    info.append("Options: \(i.options.joined(separator: ", "))")
                }
            } catch {
                info.append("Info error: \(error)")
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
                status.append("Label length: \(s.labelLengthInDots) dots")
            } catch {
                status.append("Status error: \(error)")
            }

            do {
                let m = try await printer.queryMemory()
                status.append("RAM: \(m.usedFormatted)/\(m.totalFormatted) (\(m.usagePercent)%)")
            } catch {
                status.append("Memory error: \(error)")
            }

            infoLines = info
            statusLines = status
            statusText = ""
        }
    }

    private func sendTestLabel() {
        guard let printer else { return }
        statusText = "Sending test label..."
        Task {
            let now = ISO8601DateFormatter().string(from: Date())
            let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
                Text("ZPLTool Test Label", at: .dots(30, 30))
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
                statusText = "Test label sent"
            } catch {
                statusText = "Send error: \(error)"
            }
        }
    }

    private func feedLabel() {
        runCommand("feed") {
            try await printer?.send("^XA^XZ")
        }
    }

    private func runCommand(_ name: String, action: @escaping () async throws -> Void) {
        statusText = "\(name)..."
        Task {
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

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Configure: \(printerHost)").bold()
                Spacer()
                Button("< Dashboard") {
                    screen = .dashboard
                }
            }
            Divider()

            Group {
                Text("Darkness (0-30):")
                TextField(placeholder: "e.g. 15") { value in
                    guard let v = Int(value), v >= 0, v <= 30 else {
                        statusText = "Darkness must be 0-30"
                        return
                    }
                    applyConfig("darkness=\(v)") {
                        PrinterConfiguration().darkness(v)
                    }
                }
                Spacer()
                Text("Print Speed (IPS):")
                TextField(placeholder: "e.g. 4") { value in
                    guard let v = Int(value), v >= 1, v <= 14 else {
                        statusText = "Speed must be 1-14"
                        return
                    }
                    applyConfig("speed=\(v)") {
                        PrinterConfiguration().printSpeedIPS(v)
                    }
                }
            }

            Group {
                Spacer()
                Text("Media Type:").bold()
                HStack {
                    Button("Direct Thermal") {
                        applyConfig("media=direct-thermal") {
                            PrinterConfiguration().mediaType(.directThermal)
                        }
                    }
                    Button("Thermal Transfer") {
                        applyConfig("media=thermal-transfer") {
                            PrinterConfiguration().mediaType(.thermalTransfer)
                        }
                    }
                }
                Spacer()
                Text("Media Tracking:").bold()
                HStack {
                    Button("Gap") {
                        applyConfig("tracking=gap") {
                            PrinterConfiguration().mediaTracking(.gap)
                        }
                    }
                    Button("Continuous") {
                        applyConfig("tracking=continuous") {
                            PrinterConfiguration().mediaTracking(.continuous)
                        }
                    }
                    Button("Mark") {
                        applyConfig("tracking=mark") {
                            PrinterConfiguration().mediaTracking(.mark)
                        }
                    }
                    Button("Auto") {
                        applyConfig("tracking=auto") {
                            PrinterConfiguration().mediaTracking(.auto)
                        }
                    }
                }
            }

            Group {
                Divider()
                Text("Persistence:").bold()
                HStack {
                    Button("Save to EEPROM") {
                        runPrinterCommand("save") {
                            try await printer?.saveConfiguration()
                        }
                    }
                    Button("Restore Saved") {
                        runPrinterCommand("restore") {
                            try await printer?.restoreConfiguration()
                        }
                    }
                    Button("Factory Reset") {
                        runPrinterCommand("factory reset") {
                            try await printer?.factoryReset()
                        }
                    }
                }
            }

            if !statusText.isEmpty {
                Spacer()
                Text(statusText).foregroundColor(.yellow)
            }
        }
        .padding()
    }

    private func applyConfig(_ desc: String, config: () -> PrinterConfiguration) {
        guard let printer else { return }
        let c = config()
        statusText = "Applying \(desc)..."
        Task {
            do {
                try await printer.apply(c)
                try await printer.saveConfiguration()
                statusText = "\(desc) applied and saved"
            } catch {
                statusText = "Error: \(error)"
            }
        }
    }

    private func runPrinterCommand(_ name: String, action: @escaping () async throws -> Void) {
        statusText = "\(name)..."
        Task {
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
        VStack(alignment: .leading) {
            HStack {
                Text("Raw ZPL: \(printerHost)").bold()
                Spacer()
                Button("< Dashboard") {
                    screen = .dashboard
                }
            }
            Divider()

            Text("Send ZPL (press Enter):")
            TextField(placeholder: "^XA...^XZ or ~HS") { zpl in
                let cmd = zpl.trimmingCharacters(in: .whitespaces)
                guard !cmd.isEmpty, let printer else { return }
                statusText = "Sending..."
                Task {
                    do {
                        try await printer.send(cmd)
                        statusText = "Sent OK"
                    } catch {
                        statusText = "Send error: \(error)"
                    }
                }
            }

            Spacer()
            Text("Query (send + read response):")
            TextField(placeholder: "~HI or ~HS or ^XA^HZa^XZ") { cmd in
                let command = cmd.trimmingCharacters(in: .whitespaces)
                guard !command.isEmpty, let printer else { return }
                statusText = "Querying..."
                Task {
                    do {
                        let data = try await printer.query(command, responseTimeout: 10)
                        if let str = String(data: data, encoding: .utf8) {
                            responseText = str
                        } else {
                            responseText = "(\(data.count) bytes, non-UTF8)"
                        }
                        statusText = "Response received"
                    } catch {
                        responseText = ""
                        statusText = "Query error: \(error)"
                    }
                }
            }

            if !responseText.isEmpty {
                Spacer()
                Divider()
                Text("Response:").bold()
                Text(responseText).foregroundColor(.cyan)
            }

            if !statusText.isEmpty {
                Spacer()
                Text(statusText).foregroundColor(.yellow)
            }
        }
        .padding()
    }
}
