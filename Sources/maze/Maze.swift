// Maze - Maze generation and solving animation
// Ported from maze.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "maze")

@main
struct Maze {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs

        var options = MazeDemo.Options(
            hostname: standardOptions.hostname,
            layer: standardOptions.layer,
            timeout: standardOptions.timeout,
            width: standardOptions.width,
            height: standardOptions.height,
            xoff: standardOptions.xoff,
            yoff: standardOptions.yoff,
            delay: standardOptions.delay
        )

        var i = 0

        while i < args.count && args[i].hasPrefix("-") {
            let arg = args[i]
            let option = arg.dropFirst()

            switch option {
            case "c":
                i += 1
                if i < args.count, let color = parseHexColor(args[i]) {
                    options.fgColor = color
                    options.useFGColor = true
                }

            case "v":
                i += 1
                if i < args.count, let color = parseHexColor(args[i]) {
                    options.visitedColor = color
                    options.useVisitedColor = true
                }

            case "b":
                i += 1
                if i < args.count, let color = parseHexColor(args[i]) {
                    options.bgColor = color
                    options.useBGColor = true
                }

            default:
                break
            }

            i += 1
        }

        let socket = openFlaschenTaschenSocket(hostname: options.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: options.width, height: options.height)

        await MazeDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Maze (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: maze [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -c <RRGGBB>    : Maze color in hex (-c0 = transparent, default white)")
        print("  -v <RRGGBB>    : Visited color in hex (-v0 = transparent, default cycles)")
        print("  -b <RRGGBB>    : Background color in hex (-b0 = #010101, default transparent)")
    }
}
