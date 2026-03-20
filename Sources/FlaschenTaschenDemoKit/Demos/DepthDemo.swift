// Depth - Visualization which shows depth

import Foundation
import os.log

private let logger = Logger(subsystem: Logging.subsystem, category: "depth")

public struct DepthDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions

        public init(standardOptions: StandardOptions) {
            self.standardOptions = standardOptions
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("depth: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms")

//        var pixels = [UInt8](repeating: 0, count: options.standardOptions.width * options.standardOptions.height)

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)

        await loop.run { count in
            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()
        }
    }

}
