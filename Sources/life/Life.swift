// Life - Game of Life cellular automaton
// Ported from life.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "life")

@main
struct Life {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs

        var respawn: Double = 0.0

        var hasCustomFgColor: Bool = false
        var fgColor: Color = Color()

        var hasCustomBgColor: Bool = false
        var bgColor = Color()

        var numDots: Int = 6

        var i = 0
        while i < args.count && args[i].hasPrefix("-") {
            let arg = args[i]
            let option = arg.dropFirst()

            switch option {
            case "r":
                i += 1
                if i < args.count {
                    respawn = Double(args[i]) ?? 0.0
                }
            case "c":
                i += 1
                if i < args.count, let colorArg = parseHexColor(args[i]) {
                    fgColor = colorArg
                    hasCustomFgColor = true
                }
            case "b":
                i += 1
                if i < args.count, let colorArg = parseHexColor(args[i]) {
                    bgColor = colorArg
                    hasCustomBgColor = true
                }
            case "n":
                i += 1
                if i < args.count {
                    numDots = Int(args[i]) ?? 6
                }
            default:
                break
            }
            i += 1
        }

        let options = LifeDemo.Options(standardOptions: standardOptions, respawn: respawn, hasCustomFgColor: hasCustomFgColor, fgColor: fgColor, hasCustomBgColor: hasCustomBgColor, bgColor: bgColor, numDots: numDots)

        let socket = openFlaschenTaschenSocket(hostname: options.standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: options.standardOptions.width, height: options.standardOptions.height)

        await LifeDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Life (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: life [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -r <value>     : Respawn rate")
        print("  -c <RRGGBB>    : Foreground color")
        print("  -b <RRGGBB>    : Background color")
        print("  -n <dots>      : Number of dots")
    }
}
