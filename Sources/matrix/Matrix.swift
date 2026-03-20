// Matrix - The Matrix code rain effect
// Ported from matrix.cc by Carl Gorringe

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "matrix")

@main
struct Matrix {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = MatrixDemo.Options(standardOptions: standardOptions)
        await MatrixDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Matrix (c) 2016 Carl Gorringe (carl.gorringe.org)")
        print("Usage: matrix [options]")
        print("Options:")
        StandardOptions.printStandardOptions()
    }
}
