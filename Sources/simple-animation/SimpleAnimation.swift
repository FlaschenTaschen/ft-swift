import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "simple-animation")

@main
struct SimpleAnimation {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = SimpleAnimationDemo.Options(standardOptions: standardOptions, fileDescriptor: socket)
        await SimpleAnimationDemo.run(options: options, canvas: canvas)
    }
}
