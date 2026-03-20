// black - Clears the Flaschen Taschen display
// Ported from black.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "black")

public struct BlackDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var useBlack = false
        public var useColor = false
        public var color = Color()
        public var clearAll = false

        public init(standardOptions: StandardOptions, useBlack: Bool = false, useColor: Bool = false, color: Color = Color(),
                    clearAll: Bool = false) {
            self.standardOptions = standardOptions
            self.useBlack = useBlack
            self.useColor = useColor
            self.color = color
            self.clearAll = clearAll
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("black: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms clearAll=\(options.clearAll, privacy: .public)")

        // Fill with color, black, or clear
        if options.useColor {
            canvas.fill(color: options.color)
        } else if options.useBlack {
            canvas.fill(color: Color(r: 1, g: 1, b: 1))
        } else {
            canvas.clear()
        }

        // Use AnimationLoop for consistent timeout handling (1 second per frame)
        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: 1000)

        // Capture immutable copies for the async closure
        let clearAll = options.clearAll
        let xoff = options.standardOptions.xoff
        let yoff = options.standardOptions.yoff
        let layer = options.standardOptions.layer

        await loop.run { @Sendable _ in
            if clearAll {
                // Clear all layers
                for layer in 0...15 {
                    canvas.setOffset(x: xoff, y: yoff, z: layer)
                    canvas.send()
                }
            } else {
                // Clear single layer
                canvas.setOffset(x: xoff, y: yoff, z: layer)
                canvas.send()
            }
        }
    }
}
