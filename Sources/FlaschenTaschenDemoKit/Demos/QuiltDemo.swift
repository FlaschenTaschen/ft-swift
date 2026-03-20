// Quilt - Quilt pattern animation
// Ported from quilt.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "quilt")

let SKIP_NUM = 5

public struct QuiltDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var bgColor: Color = Color(r: 1, g: 1, b: 1)

        public init(standardOptions: StandardOptions, bgColor: Color = Color(r: 1, g: 1, b: 1)) {
            self.standardOptions = standardOptions
            self.bgColor = bgColor
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("quilt: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms")

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        let w = options.standardOptions.width
        let h = options.standardOptions.height

        // State for drawing pattern incrementally
        var currentColor = randomColor()
        var currentX1 = Int.random(in: 0..<SKIP_NUM)
        var currentY1 = Int.random(in: 0..<SKIP_NUM)
        var currentX = currentX1
        var currentY = currentY1

        await loop.run { _ in
            // Draw one group of 8 mirrored pixels
            canvas.setPixel(x: currentX, y: currentY, color: currentColor)
            canvas.setPixel(x: w - 1 - currentX, y: currentY, color: currentColor)
            canvas.setPixel(x: currentX, y: h - 1 - currentY, color: currentColor)
            canvas.setPixel(x: w - 1 - currentX, y: h - 1 - currentY, color: currentColor)

            canvas.setPixel(x: currentY, y: currentX, color: currentColor)
            canvas.setPixel(x: w - 1 - currentY, y: currentX, color: currentColor)
            canvas.setPixel(x: currentY, y: h - 1 - currentX, color: currentColor)
            canvas.setPixel(x: w - 1 - currentY, y: h - 1 - currentX, color: currentColor)

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()

            // Advance to next position in the grid
            currentX += SKIP_NUM
            if currentX >= options.standardOptions.width {
                currentX = currentX1
                currentY += SKIP_NUM
                if currentY >= options.standardOptions.height {
                    // Pattern complete, pick new color and offset
                    currentColor = randomColor()
                    currentX1 = Int.random(in: 0..<SKIP_NUM)
                    currentY1 = Int.random(in: 0..<SKIP_NUM)
                    currentX = currentX1
                    currentY = currentY1
                }
            }
        }
    }
}
