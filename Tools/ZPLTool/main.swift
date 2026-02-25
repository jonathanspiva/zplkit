import Foundation
import SwiftTUI
import ZPLKit
import ZPLKitPrinter

let args = Array(CommandLine.arguments.dropFirst())

if args.isEmpty || args.first == "tui" {
    Application(rootView: TUIApp()).start()
} else {
    await CLI.run(args)
}
