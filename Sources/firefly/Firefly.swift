// Firefly - Animated firefly pattern swarms
// Ported from firefly by Dana Sniezko
// https://github.com/danasf/firefly/

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "firefly")

@main
struct Firefly {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs

        // Firefly options
        var patternName: String? = nil
        var numLights = 5
        var patternSwitchSeconds = 15

        // Parse custom firefly options
        var i = 0
        while i < args.count {
            let arg = args[i]
            guard arg.hasPrefix("-") else {
                i += 1
                continue
            }

            let option = String(arg.dropFirst())
            switch option {
            case "p":
                i += 1
                if i < args.count {
                    patternName = args[i]
                }
            case "n":
                i += 1
                if i < args.count, let n = Int(args[i]), n >= 1 && n <= 25 {
                    numLights = n
                }
            case "s":
                i += 1
                if i < args.count, let s = Int(args[i]), s >= 1 {
                    patternSwitchSeconds = s
                }
            default:
                break
            }
            i += 1
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = FireflyDemo.Options(
            standardOptions: standardOptions,
            patternName: patternName,
            numLights: numLights,
            patternSwitchSeconds: patternSwitchSeconds
        )

        await FireflyDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Firefly (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: firefly [options] [all]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  -p             : Set color palette to: (default cycles)")
        print("                   \(FireflyPattern.allNames)")
        print("  -n             : Number of lights")
        print("  -s             : Seconds between switches")
    }
}
