// Hack - Text display with Matrix-style effect
// Ported from hack.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "hack")

@main
struct Hack {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs
        let text = args.first ?? ""

        let options = HackDemo.Options(standardOptions: standardOptions, text: text)

        let socket = openFlaschenTaschenSocket(hostname: options.standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: options.standardOptions.width, height: options.standardOptions.height)

        await HackDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Hack (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: hack [options] [text]")
        print("Options:")
        StandardOptions.printStandardOptions()
    }
}
