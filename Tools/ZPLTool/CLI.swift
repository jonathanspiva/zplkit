import Foundation
import ZPLKit
import ZPLKitPrinter

enum CLI {
    static func run(_ args: [String]) async {
        let command = args[0]

        switch command {

        // MARK: - Status & Info

        case "status":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)

            do {
                let info = try await printer.queryInfo()
                print("model: \(info.model)")
                print("firmware: \(info.firmwareVersion)")
                print("dpi: \(info.dpi)")
                print("dpmm: \(info.dotsPerMillimeter)")
                print("memory: \(info.memoryFormatted)")
                if !info.options.isEmpty {
                    print("options: \(info.options.joined(separator: ", "))")
                }
            } catch {
                printError("info", error)
            }

            do {
                let status = try await printer.queryStatus()
                print("ready: \(status.isReadyToPrint)")
                print("paused: \(status.isPaused)")
                print("paper_out: \(status.isPaperOut)")
                print("ribbon_out: \(status.isRibbonOut)")
                print("head_open: \(status.isHeadOpen)")
                print("head_too_hot: \(status.isHeadTooHot)")
                print("head_cold: \(status.isHeadCold)")
                print("buffer_full: \(status.isReceiveBufferFull)")
                print("formats_in_buffer: \(status.formatsInBuffer)")
                print("labels_remaining: \(status.labelsRemainingInBatch)")
                print("label_length_dots: \(status.labelLengthInDots)")
            } catch {
                printError("status", error)
            }

            do {
                let mem = try await printer.queryMemory()
                print("ram_total: \(mem.totalFormatted)")
                print("ram_used: \(mem.usedFormatted)")
                print("ram_available: \(mem.availableFormatted)")
                print("ram_usage_percent: \(mem.usagePercent)")
            } catch {
                printError("memory", error)
            }

        case "info":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let info = try await printer.queryInfo()
                print("model: \(info.model)")
                print("firmware: \(info.firmwareVersion)")
                print("dpi: \(info.dpi)")
                print("dpmm: \(info.dotsPerMillimeter)")
                print("memory: \(info.memoryFormatted)")
                if !info.options.isEmpty {
                    print("options: \(info.options.joined(separator: ", "))")
                }
            } catch {
                printError("info", error)
                exit(1)
            }

        case "memory":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let mem = try await printer.queryMemory()
                print("total: \(mem.totalFormatted)")
                print("used: \(mem.usedFormatted)")
                print("available: \(mem.availableFormatted)")
                print("usage_percent: \(mem.usagePercent)")
            } catch {
                printError("memory", error)
                exit(1)
            }

        // MARK: - Sending

        case "send":
            guard args.count >= 3 else {
                printUsage("send <IP> <ZPL|--file PATH>")
                exit(1)
            }
            let host = args[1]
            let printer = ZPLPrinter(host: host, timeout: 10)

            let zpl: String
            if args[2] == "--file" {
                guard args.count >= 4 else {
                    printUsage("send <IP> --file <PATH>")
                    exit(1)
                }
                do {
                    zpl = try String(contentsOfFile: args[3], encoding: .utf8)
                } catch {
                    printError("read file", error)
                    exit(1)
                }
            } else {
                zpl = args[2]
            }

            do {
                try await printer.send(zpl)
                print("ok")
            } catch {
                printError("send", error)
                exit(1)
            }

        case "test":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)

            let now = ISO8601DateFormatter().string(from: Date())
            let label = ZPLLabel(width: 4, height: 2, dpi: .dpi203) {
                Text("ZPLTool Test Label", at: .dots(30, 30))
                    .font(.default, height: .dots(30))
                Barcode128("ZPLTOOL-TEST", at: .dots(30, 80))!
                    .height(.dots(60))
                    .showText(true)
                Text(now, at: .dots(30, 170))
                    .font(.default, height: .dots(16))
                Text("Host: \(host)", at: .dots(30, 195))
                    .font(.default, height: .dots(16))
                Box(at: .dots(5, 5), width: .dots(802), height: .dots(396))
                    .thickness(2)
            }

            do {
                try await printer.send(label.render())
                print("ok: test label sent")
            } catch {
                printError("test", error)
                exit(1)
            }

        case "feed":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                try await printer.feedLabel()
                print("ok")
            } catch {
                printError("feed", error)
                exit(1)
            }

        case "diagnostics", "diag":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let diag = try await printer.queryDiagnostics()
                print("model: \(diag.info.model)")
                print("firmware: \(diag.info.firmwareVersion)")
                print("dpi: \(diag.info.dpi)")
                print("memory: \(diag.memory.availableFormatted) free of \(diag.memory.totalFormatted)")
                print("ready: \(diag.isReadyToPrint)")
                if diag.status.hasError {
                    print("errors: \(diag.status)")
                }
                if diag.status.isPaused {
                    print("paused: true")
                }
                if let settings = diag.settings {
                    if let serial = settings.serialNumber {
                        print("serial: \(serial)")
                    }
                    if let fw = settings.firmware {
                        print("config_firmware: \(fw)")
                    }
                    if let darkness = settings.darkness {
                        print("darkness: \(darkness)")
                    }
                    if let speed = settings.printSpeed {
                        print("speed: \(speed) IPS")
                    }
                    if let mediaType = settings.mediaType {
                        print("media_type: \(mediaType == .directThermal ? "direct-thermal" : "thermal-transfer")")
                    }
                    if let lifetime = settings.nonresetCounterInches {
                        print("lifetime_usage: \(lifetime) in")
                    }
                    if let headUsage = settings.resetCounterInches {
                        print("head_usage: \(headUsage) in")
                    }
                    if let lastCleaned = settings.lastCleanedInches {
                        print("last_cleaned: \(lastCleaned) in")
                    }
                    if let maxLen = settings.maximumLengthInches {
                        print("max_length: \(maxLen) in")
                    }
                } else {
                    print("settings: unavailable (^HH timed out)")
                }
            } catch {
                printError("diagnostics", error)
                exit(1)
            }

        // MARK: - Configuration

        case "darkness":
            guard args.count >= 3 else {
                printUsage("darkness <IP> <0-30>")
                exit(1)
            }
            let host = args[1]
            guard let value = Int(args[2]), value >= 0, value <= 30 else {
                print("error: darkness must be 0-30")
                exit(1)
            }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let config = PrinterConfiguration().darkness(value)
                try await printer.apply(config)
                try await printer.saveConfiguration()
                print("ok: darkness set to \(value)")
            } catch {
                printError("darkness", error)
                exit(1)
            }

        case "media-type":
            guard args.count >= 3 else {
                printUsage("media-type <IP> <direct-thermal|thermal-transfer>")
                exit(1)
            }
            let host = args[1]
            let mediaType: MediaType
            switch args[2] {
            case "direct-thermal", "direct", "dt":
                mediaType = .directThermal
            case "thermal-transfer", "transfer", "tt":
                mediaType = .thermalTransfer
            default:
                print("error: media type must be direct-thermal or thermal-transfer")
                exit(1)
            }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let config = PrinterConfiguration().mediaType(mediaType)
                try await printer.apply(config)
                try await printer.saveConfiguration()
                print("ok: media type set to \(args[2])")
            } catch {
                printError("media-type", error)
                exit(1)
            }

        case "media-tracking":
            guard args.count >= 3 else {
                printUsage("media-tracking <IP> <gap|continuous|mark|auto>")
                exit(1)
            }
            let host = args[1]
            let tracking: MediaTracking
            switch args[2] {
            case "gap": tracking = .gap
            case "continuous": tracking = .continuous
            case "mark": tracking = .mark
            case "auto": tracking = .auto
            default:
                print("error: media tracking must be gap, continuous, mark, or auto")
                exit(1)
            }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let config = PrinterConfiguration().mediaTracking(tracking)
                try await printer.apply(config)
                try await printer.saveConfiguration()
                print("ok: media tracking set to \(args[2])")
            } catch {
                printError("media-tracking", error)
                exit(1)
            }

        case "speed":
            guard args.count >= 3 else {
                printUsage("speed <IP> <IPS>")
                exit(1)
            }
            let host = args[1]
            guard let value = Int(args[2]), value >= 1, value <= 14 else {
                print("error: speed must be 1-14 IPS")
                exit(1)
            }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let config = PrinterConfiguration().printSpeedIPS(value)
                try await printer.apply(config)
                try await printer.saveConfiguration()
                print("ok: speed set to \(value) IPS")
            } catch {
                printError("speed", error)
                exit(1)
            }

        case "name":
            guard args.count >= 3 else {
                printUsage("name <IP> <NAME>")
                exit(1)
            }
            let host = args[1]
            let name = args[2]
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let config = PrinterConfiguration().printerName(name)
                try await printer.apply(config)
                try await printer.saveConfiguration()
                print("ok: name set to \(name)")
            } catch {
                printError("name", error)
                exit(1)
            }

        case "config":
            guard args.count >= 2 else {
                printUsage("config <IP> [--darkness N] [--media-type TYPE] [--media-tracking MODE] [--speed IPS] [--name NAME]")
                exit(1)
            }
            let host = args[1]
            var config = PrinterConfiguration()
            var i = 2
            while i < args.count {
                switch args[i] {
                case "--darkness":
                    i += 1
                    guard i < args.count, let v = Int(args[i]) else {
                        print("error: --darkness requires integer value")
                        exit(1)
                    }
                    config = config.darkness(v)
                case "--media-type":
                    i += 1
                    guard i < args.count else {
                        print("error: --media-type requires value")
                        exit(1)
                    }
                    switch args[i] {
                    case "direct-thermal", "direct", "dt":
                        config = config.mediaType(.directThermal)
                    case "thermal-transfer", "transfer", "tt":
                        config = config.mediaType(.thermalTransfer)
                    default:
                        print("error: unknown media type '\(args[i])'")
                        exit(1)
                    }
                case "--media-tracking":
                    i += 1
                    guard i < args.count else {
                        print("error: --media-tracking requires value")
                        exit(1)
                    }
                    switch args[i] {
                    case "gap": config = config.mediaTracking(.gap)
                    case "continuous": config = config.mediaTracking(.continuous)
                    case "mark": config = config.mediaTracking(.mark)
                    case "auto": config = config.mediaTracking(.auto)
                    default:
                        print("error: unknown media tracking '\(args[i])'")
                        exit(1)
                    }
                case "--speed":
                    i += 1
                    guard i < args.count, let v = Int(args[i]) else {
                        print("error: --speed requires integer value")
                        exit(1)
                    }
                    config = config.printSpeedIPS(v)
                case "--name":
                    i += 1
                    guard i < args.count else {
                        print("error: --name requires value")
                        exit(1)
                    }
                    config = config.printerName(args[i])
                default:
                    print("error: unknown option '\(args[i])'")
                    exit(1)
                }
                i += 1
            }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                try await printer.apply(config)
                try await printer.saveConfiguration()
                print("ok: configuration applied and saved")
            } catch {
                printError("config", error)
                exit(1)
            }

        // MARK: - Calibration & Control

        case "calibrate":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                try await printer.calibrate()
                print("ok: sensor calibration sent (~JC)")
            } catch {
                printError("calibrate", error)
                exit(1)
            }

        case "calibrate-full":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                try await printer.calibrateFull()
                print("ok: full sensor profile sent (~JG)")
            } catch {
                printError("calibrate-full", error)
                exit(1)
            }

        case "pause":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                try await printer.togglePause()
                print("ok: pause toggled (~PP)")
            } catch {
                printError("pause", error)
                exit(1)
            }

        case "cancel":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                try await printer.cancelAll()
                print("ok: all jobs cancelled (~JA)")
            } catch {
                printError("cancel", error)
                exit(1)
            }

        case "reset-printer":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                try await printer.powerOnReset()
                print("ok: power-on reset sent (~JR)")
            } catch {
                printError("reset-printer", error)
                exit(1)
            }

        case "save":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                try await printer.saveConfiguration()
                print("ok: configuration saved to EEPROM (^JUS)")
            } catch {
                printError("save", error)
                exit(1)
            }

        case "restore":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                try await printer.restoreConfiguration()
                print("ok: saved configuration restored (^JUR)")
            } catch {
                printError("restore", error)
                exit(1)
            }

        case "reset":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                try await printer.factoryReset()
                print("ok: factory reset sent (^JUF)")
            } catch {
                printError("reset", error)
                exit(1)
            }

        // MARK: - Raw Query

        case "query":
            guard args.count >= 3 else {
                printUsage("query <IP> <COMMAND>")
                exit(1)
            }
            let host = args[1]
            let command = args[2]
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let data = try await printer.query(command)
                if let str = String(data: data, encoding: .utf8) {
                    print(str)
                } else {
                    print("(\(data.count) bytes, non-UTF8)")
                }
            } catch {
                printError("query", error)
                exit(1)
            }

        case "config-read":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let settings = try await printer.queryConfiguration()
                if let darkness = settings.darkness {
                    print("darkness: \(darkness)")
                }
                if let speed = settings.printSpeed {
                    print("speed: \(speed) IPS")
                }
                if let mediaType = settings.mediaType {
                    print("media_type: \(mediaType == .directThermal ? "direct-thermal" : "thermal-transfer")")
                }
                if let tracking = settings.mediaTracking {
                    let trackingStr: String
                    switch tracking {
                    case .gap: trackingStr = "gap"
                    case .continuous: trackingStr = "continuous"
                    case .mark: trackingStr = "mark"
                    case .auto: trackingStr = "auto"
                    }
                    print("media_tracking: \(trackingStr)")
                }
                if let width = settings.printWidthDots {
                    print("print_width_dots: \(width)")
                }
                if let length = settings.labelLengthDots {
                    print("label_length_dots: \(length)")
                }
                if let mode = settings.printMode {
                    let modeStr: String
                    switch mode {
                    case .tearOff: modeStr = "tear-off"
                    case .peel: modeStr = "peel"
                    case .rewind: modeStr = "rewind"
                    case .cutter: modeStr = "cutter"
                    }
                    print("print_mode: \(modeStr)")
                }
                if let tearOff = settings.tearOffAdjust {
                    print("tear_off_adjust: \(tearOff)")
                }
                if let serial = settings.serialNumber {
                    print("serial: \(serial)")
                }
                if let fw = settings.firmware {
                    print("firmware: \(fw)")
                }
                if let lifetime = settings.nonresetCounterInches {
                    print("lifetime_usage: \(lifetime) in")
                }
                if let headUsage = settings.resetCounterInches {
                    print("head_usage: \(headUsage) in")
                }
                if let lastCleaned = settings.lastCleanedInches {
                    print("last_cleaned: \(lastCleaned) in")
                }
                if let maxLen = settings.maximumLengthInches {
                    print("max_length: \(maxLen) in")
                }
            } catch {
                printError("config-read", error)
                exit(1)
            }

        case "config-dump":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let raw = try await printer.queryConfigurationRaw()
                print(raw)
            } catch {
                printError("config-dump", error)
                exit(1)
            }

        case "config-dump-raw":
            guard let host = requireHost(args) else { return }
            let printer = ZPLPrinter(host: host, timeout: 10)
            do {
                let data = try await printer.query("^XA^HZa^XZ", responseTimeout: 15)
                if let str = String(data: data, encoding: .utf8) {
                    print(str)
                } else {
                    print("(\(data.count) bytes, non-UTF8)")
                }
            } catch {
                printError("config-dump-raw", error)
                exit(1)
            }

        // MARK: - Discovery

        case "discover":
            let durationArg = args.count > 1 ? Int(args[1]) : nil
            let duration = durationArg ?? 5
            print("Scanning for printers (\(duration)s)...")
            let browser = ZPLPrinterBrowser()
            browser.start()
            try? await Task.sleep(nanoseconds: UInt64(duration) * 1_000_000_000)
            browser.stop()
            let printers = browser.discoveredPrinters
            if printers.isEmpty {
                print("No printers found.")
            } else {
                for p in printers {
                    print("\(p.name)\t\(p.host)\t\(p.port)")
                }
            }

        // MARK: - Help

        case "help", "--help", "-h":
            printHelp()

        default:
            print("error: unknown command '\(command)'")
            print()
            printHelp()
            exit(1)
        }
    }

    // MARK: - Helpers

    private static func requireHost(_ args: [String]) -> String? {
        guard args.count >= 2 else {
            printUsage("\(args[0]) <IP>")
            exit(1)
        }
        return args[1]
    }

    private static func printError(_ context: String, _ error: Error) {
        print("error: \(context): \(error)")
    }

    private static func printUsage(_ usage: String) {
        print("Usage: swift run ZPLTool \(usage)")
    }

    private static func printHelp() {
        print("""
        ZPLTool - ZPL printer CLI and TUI

        Usage: swift run ZPLTool <command> [arguments]
               swift run ZPLTool              (launch interactive TUI)

        Status & Info:
          status <IP>                   Full printer status (info + status + memory)
          info <IP>                     Printer identification (~HI)
          memory <IP>                   RAM usage (~HM)
          diagnostics <IP>              Full diagnostic snapshot (diag)

        Sending:
          send <IP> <ZPL>               Send raw ZPL string
          send <IP> --file <PATH>       Send ZPL from file
          test <IP>                     Print a test label
          feed <IP>                     Feed one blank label

        Configuration:
          darkness <IP> <0-30>          Set darkness and save
          media-type <IP> <TYPE>        direct-thermal, thermal-transfer
          media-tracking <IP> <MODE>    gap, continuous, mark, auto
          speed <IP> <IPS>              Print speed in inches/second
          name <IP> <NAME>              Set printer name
          config <IP> [--key val ...]   Set multiple config options

        Calibration & Control:
          calibrate <IP>                Sensor calibration (~JC)
          calibrate-full <IP>           Full sensor profile (~JG)
          pause <IP>                    Toggle pause (~PP)
          cancel <IP>                   Cancel all jobs (~JA)
          save <IP>                     Save config to EEPROM (^JUS)
          restore <IP>                  Restore saved config (^JUR)
          reset <IP>                    Factory reset (^JUF)
          reset-printer <IP>            Power-on reset (~JR)

        Query:
          query <IP> <COMMAND>          Send command, print response
          config-read <IP>              Read and parse current config (^HH)
          config-dump <IP>              Text config dump (^HH)
          config-dump-raw <IP>          Full XML config dump (^HZa)

        Discovery:
          discover [SECONDS]            Bonjour scan (default 5s)
        """)
    }
}
