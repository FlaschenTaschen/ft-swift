// Lines - Random line drawing animation
// Ported from lines.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "lines")

@main
struct Lines {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs

        guard !args.isEmpty else {
            printUsage()
            exit(EXIT_FAILURE)
        }

        let drawMode = args[0]
        var drawNum = 1
        if drawMode.hasPrefix("one") {
            drawNum = 1
        } else if drawMode.hasPrefix("two") {
            drawNum = 2
        } else if drawMode.hasPrefix("four") {
            drawNum = 4
        } else {
            printUsage()
            exit(EXIT_FAILURE)
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = LinesDemo.Options(standardOptions: standardOptions, drawNum: drawNum)
        await LinesDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Lines (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: lines [options] {one|two|four}")
        print("Options:")
        StandardOptions.printStandardOptions()
    }
}
