import Foundation
import ZPLKitPrinter

let args = Array(CommandLine.arguments.dropFirst())

guard !args.isEmpty else {
    print("Usage: swift run StatusCheck <command> <IP> [<IP> ...]")
    print("Commands:")
    print("  status <IP>       Query printer status")
    print("  feed <IP>         Feed one label")
    print("  send <IP> <ZPL>   Send raw ZPL string")
    exit(1)
}

let command = args[0]

switch command {
case "status":
    let hosts = Array(args.dropFirst())
    guard !hosts.isEmpty else {
        print("Usage: swift run StatusCheck status <IP> [<IP> ...]")
        exit(1)
    }
    for host in hosts {
        let printer = ZPLPrinter(host: host, timeout: 5)
        print("[\(host)]")

        do {
            let info = try await printer.queryInfo()
            print("  Model: \(info.model)")
            print("  Firmware: \(info.firmwareVersion)")
            print("  DPI: \(info.dpi)")
        } catch {
            print("  Info failed: \(error)")
        }

        do {
            let status = try await printer.queryStatus()
            print("  Ready: \(status.isReadyToPrint)")
            if status.isPaperOut { print("  *** PAPER OUT ***") }
            if status.isHeadOpen { print("  *** HEAD OPEN ***") }
            if status.isRibbonOut { print("  *** RIBBON OUT ***") }
            if status.isPaused { print("  *** PAUSED ***") }
            if status.isHeadTooHot { print("  *** HEAD TOO HOT ***") }
            if status.isReceiveBufferFull { print("  *** BUFFER FULL ***") }
            if status.formatsInBuffer > 0 { print("  Formats in buffer: \(status.formatsInBuffer)") }
            if status.labelsRemainingInBatch > 0 { print("  Labels remaining: \(status.labelsRemainingInBatch)") }
            print("  Label length: \(status.labelLengthInDots) dots")
        } catch {
            print("  Status failed: \(error)")
        }

        do {
            let memory = try await printer.queryMemory()
            print("  Memory: \(memory)")
        } catch {
            print("  Memory failed: \(error)")
        }

        print()
    }

case "feed":
    let hosts = Array(args.dropFirst())
    guard !hosts.isEmpty else {
        print("Usage: swift run StatusCheck feed <IP>")
        exit(1)
    }
    for host in hosts {
        let printer = ZPLPrinter(host: host, timeout: 5)
        print("Feeding \(host)...")

        // Try multiple approaches
        let feedCommands = [
            ("~FF (form feed)", "~FF"),
            ("^XA^FO0,0^FD ^FS^XZ (label with space)", "^XA^FO0,0^FD ^FS^XZ"),
            ("^XA^FO0,0^GB1,1,1^FS^XZ (label with dot)", "^XA^FO0,0^GB1,1,1^FS^XZ"),
        ]

        for (desc, cmd) in feedCommands {
            do {
                print("  Trying \(desc)...")
                try await printer.send(cmd)
                print("    Sent OK")
                // Wait a moment to see if it worked
                try await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                print("    Failed: \(error)")
            }
        }
    }

case "send":
    guard args.count >= 3 else {
        print("Usage: swift run StatusCheck send <IP> <ZPL>")
        exit(1)
    }
    let host = args[1]
    let zpl = args[2]
    let printer = ZPLPrinter(host: host, timeout: 5)
    print("Sending to \(host): \(zpl)")
    do {
        try await printer.send(zpl)
        print("  Done")
    } catch {
        print("  Failed: \(error)")
    }

default:
    // Legacy behavior: treat all args as hosts for status
    let hosts = args
    for host in hosts {
        let printer = ZPLPrinter(host: host, timeout: 5)
        print("[\(host)]")

        do {
            let info = try await printer.queryInfo()
            print("  Model: \(info.model)")
            print("  Firmware: \(info.firmwareVersion)")
            print("  DPI: \(info.dpi)")
        } catch {
            print("  Info failed: \(error)")
        }

        do {
            let status = try await printer.queryStatus()
            print("  Ready: \(status.isReadyToPrint)")
            if status.isPaperOut { print("  *** PAPER OUT ***") }
            if status.isHeadOpen { print("  *** HEAD OPEN ***") }
            if status.isRibbonOut { print("  *** RIBBON OUT ***") }
            if status.isPaused { print("  *** PAUSED ***") }
            if status.isHeadTooHot { print("  *** HEAD TOO HOT ***") }
            if status.isReceiveBufferFull { print("  *** BUFFER FULL ***") }
            if status.formatsInBuffer > 0 { print("  Formats in buffer: \(status.formatsInBuffer)") }
            if status.labelsRemainingInBatch > 0 { print("  Labels remaining: \(status.labelsRemainingInBatch)") }
            print("  Label length: \(status.labelLengthInDots) dots")
        } catch {
            print("  Status failed: \(error)")
        }

        do {
            let memory = try await printer.queryMemory()
            print("  Memory: \(memory)")
        } catch {
            print("  Memory failed: \(error)")
        }

        print()
    }
}
