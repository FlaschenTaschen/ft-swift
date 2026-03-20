// Plasma - Plasma effect with color palettes
// Ported from plasma.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "plasma")

@main
struct Plasma {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs
        var paletteIndex = 0

        var i = 0
        while i < args.count && args[i].hasPrefix("-") {
            let arg = args[i]
            let optChar = String(arg.dropFirst())

            switch optChar {
            case "p":
                i += 1
                if i < args.count, let palette = Int(args[i]), palette >= 0 && palette <= 8 {
                    paletteIndex = palette
                }

            default:
                break
            }

            i += 1
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = PlasmaDemo.Options(standardOptions: standardOptions, paletteIndex: paletteIndex)
        await PlasmaDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Plasma (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: plasma [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -p <palette>   : Palette (0-8, cycles if not set)")
    }
}
