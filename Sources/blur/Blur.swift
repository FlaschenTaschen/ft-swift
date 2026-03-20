// Blur - Animated blur effect with pattern options
// Ported from blur.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "blur")

@main
struct Blur {
    static func main() async {
        var standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs

        // Blur options
        var palette = -1
        var demo = BlurDemoType.bolt
        var orient = 0

        var i = 0
        while i < args.count && args[i].hasPrefix("-") {
            let arg = args[i]
            let option = arg.dropFirst()

            switch option {
            case "p":
                i += 1
                if i < args.count, let p = Int(args[i]), p >= 1 && p <= 8 {
                    palette = p
                }
            case "o":
                i += 1
                if i < args.count, let o = Int(args[i]) {
                    orient = o
                }
            default:
                return
            }
            i += 1
        }

        while i < args.count {
            switch args[i].lowercased() {
            case "all": demo = .all
            case "bolt": demo = .bolt
            case "boxes": demo = .boxes
            case "circles": demo = .circles
            case "target": demo = .target
            case "fire": demo = .fire
            default: return
            }
            i += 1
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = BlurDemo.Options(standardOptions: standardOptions, palette: palette, demo: demo, orient: orient)
        await BlurDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Blur (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: blur [options] [all]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -p             : Set color palette to: (default cycles)")
        print("                   1=Nebula, 2=Fire, 3=Bluegreen")
        print("  -0             : Set orientation: 0=default, 1=XY-swapped")
    }
}

