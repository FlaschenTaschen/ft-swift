// Fractal - Fractal patterns
// Ported from fractal.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "fractal")

@main
struct Fractal {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = FractalDemo.Options(standardOptions: standardOptions)
        await FractalDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Fractal (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: fractal [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
    }
}
