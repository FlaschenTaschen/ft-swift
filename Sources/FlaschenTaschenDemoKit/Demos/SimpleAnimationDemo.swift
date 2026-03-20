// Simple animation - Animates a space invader sprite moving across the display
// Ported from simple-animation.cc

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "simple-animation")

let invaderPatterns: [[String]] = [
    ["  #     #  ", "   #   #   ", "  #######  ", " ## ### ## ", "###########", "# ####### #", "# #     # #", "  ##   ##  "],
    ["  #     #  ", "#  #   #  #", "# ####### #", "### ### ###", " ######### ", "  #######  ", "  #     #  ", " #       #"],
]

public struct SimpleAnimationDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var fileDescriptor: Int32

        public init(standardOptions: StandardOptions, fileDescriptor: Int32) {
            self.standardOptions = standardOptions
            self.fileDescriptor = fileDescriptor
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("simple-animation: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public)")

        let frame1 = createSpriteFromPattern(options.fileDescriptor, pattern: invaderPatterns[0], color: Color(r: 255, g: 255, b: 0))
        let frame2 = createSpriteFromPattern(options.fileDescriptor, pattern: invaderPatterns[1], color: Color(r: 255, g: 0, b: 255))

        let frames = [frame1, frame2]
        let maxAnimationX = 20
        let maxAnimationY = 20
        var animationX = 0
        var animationY = 0
        var animationDirection = 1

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: 300)

        await loop.run { i in
            let currentFrame = frames[i % frames.count]

            currentFrame.setOffset(x: animationX, y: animationY, z: 1)
            currentFrame.send()

            if i % 2 == 0 {
                animationX += animationDirection
                if animationX > maxAnimationX {
                    animationDirection = -1
                    animationY += 1
                }
                if animationX < 1 {
                    animationDirection = 1
                    animationY += 1
                }
                if animationY >= maxAnimationY {
                    animationY = 0
                }
            }
        }
    }
}
