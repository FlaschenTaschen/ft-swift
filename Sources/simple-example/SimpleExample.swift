import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "simple-example")

@main
struct SimpleExample {
    static func main() {
        let args = ArgumentPreprocessor.preprocess(args: CommandLine.arguments)
        let argString = args.count > 1 ? args.dropFirst().joined(separator: " ") : "(none)"
        logger.info("Arguments: \(argString, privacy: .public)")

        let hostname = args.count > 1 ? args[1] : nil

        let socket = openFlaschenTaschenSocket(hostname: hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: 25, height: 20)

        let options = SimpleExampleDemo.Options(hostname: hostname, width: 25, height: 20)
        Task {
            await SimpleExampleDemo.run(options: options, canvas: canvas)
        }
    }
}
