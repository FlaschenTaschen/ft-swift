// Sierpinski - Sierpinski's Triangle fractal
// Ported from sierpinski.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "sierpinski")

@main
struct Sierpinski {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs
        var paletteMode = true
        var fgColor = Color()
        var bgColor = Color(r: 1, g: 1, b: 1)

        var i = 0
        while i < args.count {
            let arg = args[i]
            guard arg.hasPrefix("-") else { i += 1; continue }
            let optChar = String(arg.dropFirst())

            switch optChar {
            case "c":
                i += 1
                if i < args.count, let color = parseHexColor(args[i]) {
                    fgColor = color
                    paletteMode = false
                }
            case "b":
                i += 1
                if i < args.count, let color = parseHexColor(args[i]) {
                    bgColor = color
                }
            default:
                break
            }
            i += 1
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)
        canvas.clear()

        let options = SierpinskiDemo.Options(standardOptions: standardOptions, paletteMode: paletteMode, fgColor: fgColor, bgColor: bgColor)
        await SierpinskiDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Sierpinski (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: sierpinski [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -c <RRGGBB>    : Foreground color (palette mode if not set)")
        print("  -b <RRGGBB>    : Background color")
    }
}
