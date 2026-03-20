// Random Dots - Random dot animation
// Ported from random-dots.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "random-dots")

@main
struct RandomDots {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = RandomDotsDemo.Options(standardOptions: standardOptions)
        await RandomDotsDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Random Dots (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: random-dots [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
    }
}
