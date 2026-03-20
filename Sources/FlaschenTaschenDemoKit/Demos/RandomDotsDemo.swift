// random-dots - Displays random colored dots at random positions continuously
// Ported from random-dots.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "random-dots")

public struct RandomDotsDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions

        public init(standardOptions: StandardOptions) {
            self.standardOptions = standardOptions
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("random-dots: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms")

        canvas.clear()

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        await loop.run { _ in
            let r = UInt8(randomInt(min: 0, max: 255))
            let g = UInt8(randomInt(min: 0, max: 255))
            let b = UInt8(randomInt(min: 0, max: 255))

            let x = randomInt(min: 0, max: options.standardOptions.width - 1)
            let y = randomInt(min: 0, max: options.standardOptions.height - 1)

            canvas.setPixel(x: x, y: y, color: Color(r: r, g: g, b: b))

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()
        }
    }
}
