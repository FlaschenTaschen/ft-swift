// Black - Clear display or fill with color
// Ported from black.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "black")

@main
struct Black {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs

        var useBlack = false
        var color = Color()
        var useColor = false
        var clearAll = false

        var i = 0
        while i < args.count {
            let arg = args[i]

            if arg.hasPrefix("-") {
                let option = arg.dropFirst()

                switch option {
                case "b":
                    useBlack = true
                case "c":
                    i += 1
                    if i < args.count, let colorArg = parseHexColor(args[i]) {
                        color = colorArg
                        useColor = true
                    }
                default:
                    break
                }
            } else if arg == "all" {
                clearAll = true
            }

            i += 1
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = BlackDemo.Options(standardOptions: standardOptions, useBlack: useBlack, useColor: useColor, color: color, clearAll: clearAll)

        await BlackDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Black (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: black [options] [all]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -b             : Black out with color (1,1,1)")
        print("  -c <RRGGBB>    : Fill with color as hex")
        print("  all            : Clear ALL layers")
    }

}
