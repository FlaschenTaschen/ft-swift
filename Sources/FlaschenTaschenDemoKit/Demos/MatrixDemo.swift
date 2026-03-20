// Matrix - The Matrix code rain effect
// Ported from matrix.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "matrix")

class MatrixState: @unchecked Sendable {
    var columns: [Int]
    var brightness: [Int]

    init(width: Int, height: Int) {
        columns = (0..<width).map { _ in randomInt(min: 0, max: height - 1) }
        brightness = (0..<width).map { _ in randomInt(min: 100, max: 255) }
    }
}

public struct MatrixDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions

        public init(standardOptions: StandardOptions) {
            self.standardOptions = standardOptions
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("matrix: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms")

        canvas.clear()

        let state = MatrixState(width: options.standardOptions.width, height: options.standardOptions.height)
        let trailLength = 12
        let headColor = Color(r: 255, g: 255, b: 255)

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        await loop.run { _ in
            canvas.clear()

            for x in 0..<options.standardOptions.width {
                let trailStart = max(0, state.columns[x] - trailLength)
                for trailY in trailStart..<state.columns[x] {
                    let distFromHead = state.columns[x] - trailY
                    let trailBrightness = UInt8(max(0, state.brightness[x] - (distFromHead * 32)))
                    let trailColor = Color(r: 0, g: trailBrightness, b: 0)
                    canvas.setPixel(x: x, y: trailY, color: trailColor)
                }

                canvas.setPixel(x: x, y: state.columns[x], color: headColor)

                state.columns[x] += 1
                if state.columns[x] >= options.standardOptions.height {
                    state.columns[x] = 0
                    state.brightness[x] = randomInt(min: 100, max: 255)
                }
            }

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()
        }
    }
}
