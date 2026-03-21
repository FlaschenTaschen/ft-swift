import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "simple-example")

@main
struct SimpleExample {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs

        let hostname = args.count > 0 ? args[0] : nil

        let socket = openFlaschenTaschenSocket(hostname: hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: 25, height: 20)

        let options = SimpleExampleDemo.Options(hostname: hostname, width: 25, height: 20)
        await SimpleExampleDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Simple Example (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: simple-example [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
        print("  <host>    : FT host")
    }
}
