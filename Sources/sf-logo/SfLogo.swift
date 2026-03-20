// SF Logo - SF logo display
// Ported from sf-logo.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "sf-logo")

@main
struct SfLogo {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs
        var logoColor: Color? = nil

        var i = 0
        while i < args.count {
            let arg = args[i]
            guard arg.hasPrefix("-") else { i += 1; continue }
            let optChar = String(arg.dropFirst())

            switch optChar {
            case "c":
                i += 1
                if i < args.count, let color = parseHexColor(args[i]) {
                    logoColor = color
                }
            default:
                break
            }
            i += 1
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)
        canvas.clear()

        let options = SfLogoDemo.Options(standardOptions: standardOptions, logoColor: logoColor)
        await SfLogoDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("SF Logo (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: sf-logo [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -c <RRGGBB>    : Logo color")
    }
}
