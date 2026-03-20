// Quilt - Quilt pattern animation
// Ported from quilt.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "quilt")

@main
struct Quilt {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs
        var bgColor = Color(r: 1, g: 1, b: 1)

        var i = 0
        while i < args.count {
            let arg = args[i]
            guard arg.hasPrefix("-") else { i += 1; continue }
            let optChar = String(arg.dropFirst())

            switch optChar {
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
        canvas.fill(color: bgColor)

        let options = QuiltDemo.Options(standardOptions: standardOptions, bgColor: bgColor)
        await QuiltDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Quilt (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: quilt [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -b <RRGGBB>    : Background color (default FFFFFF)")
    }
}
