// Depth - Visualization which shows depth

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "depth")

@main
struct Depth {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = DepthDemo.Options(standardOptions: standardOptions)
        await DepthDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Depth - Parallax scrolling depth visualization")
        print("Usage: depth [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
    }
}
