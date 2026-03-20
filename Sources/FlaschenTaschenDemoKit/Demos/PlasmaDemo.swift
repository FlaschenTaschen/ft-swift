// Plasma - Plasma effect with color palettes
// Ported from plasma.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "plasma")

public struct PlasmaDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var paletteIndex: Int = 0

        public init(standardOptions: StandardOptions, paletteIndex: Int = 0) {
            self.standardOptions = standardOptions
            self.paletteIndex = paletteIndex
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("plasma: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms palette=\(options.paletteIndex, privacy: .public)")

        // Set up palette
        var palette = [Color](repeating: Color(), count: 256)
        let paletteType = PaletteType(rawValue: options.paletteIndex) ?? .colorful
        paletteType.apply(to: &palette)

        let lookupQuant = 20
        let slowness = 100.0 / Double(options.standardOptions.delay)

        // Pre-compute two large lookup tables
        let plasmaWidth = lookupQuant * options.standardOptions.width * 2
        let plasmaHeight = lookupQuant * options.standardOptions.height * 2
        let centerX = lookupQuant * options.standardOptions.width
        let centerY = lookupQuant * options.standardOptions.height

        var plasma1 = [[Float]](repeating: [Float](repeating: 0, count: plasmaWidth), count: plasmaHeight)
        var plasma2 = [[Float]](repeating: [Float](repeating: 0, count: plasmaWidth), count: plasmaHeight)

        // Initialize plasma lookup tables
        for y in 0..<plasmaHeight {
            for x in 0..<plasmaWidth {
                let dx = Float(centerX - x)
                let dy = Float(centerY - y)
                plasma1[y][x] = sin(sqrt(dx * dx + dy * dy) / Float(4 * lookupQuant))

                let xNorm = Float(4.0) * Float(x) / Float(lookupQuant)
                let yNorm = Float(4.0) * Float(y) / Float(lookupQuant)
                let denom1 = 37.0 + 15.0 * cos(Float(y) / Float(18.5 * Double(lookupQuant)))
                let denom2 = 31.0 + 11.0 * sin(Float(x) / Float(14.25 * Double(lookupQuant)))
                plasma2[y][x] = sin(xNorm / Float(denom1)) * cos(yNorm / Float(denom2))
            }
        }

        let hw = lookupQuant * options.standardOptions.width / 2
        let hh = lookupQuant * options.standardOptions.height / 2

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        var count: Double = Double.random(in: 0..<100000)
        var lowestValue: Float = 100
        var highestValue: Float = -100

        await loop.run { _ in
            // Calculate sliding window positions
            let x1 = Int(Double(hw) + Double(hw) * cos(count / 97.0 / slowness))
            let x2 = Int(Double(hw) + Double(hw) * sin(-count / 114.0 / slowness))
            let x3 = Int(Double(hw) + Double(hw) * sin(-count / 137.0 / slowness))

            let y1 = Int(Double(hh) + Double(hh) * sin(count / 123.0 / slowness))
            let y2 = Int(Double(hh) + Double(hh) * cos(-count / 75.0 / slowness))
            let y3 = Int(Double(hh) + Double(hh) * cos(-count / 108.0 / slowness))

            // Sample plasma and find range
            lowestValue = 100
            highestValue = -100
            var pixelBuffer = [[Float]](repeating: [Float](repeating: 0, count: options.standardOptions.width), count: options.standardOptions.height)

            for y in 0..<options.standardOptions.height {
                for x in 0..<options.standardOptions.width {
                    let idx1X = clamp(x1 + lookupQuant * x, 0, plasmaWidth - 1)
                    let idx1Y = clamp(y1 + lookupQuant * y, 0, plasmaHeight - 1)
                    let idx2X = clamp(x2 + lookupQuant * x, 0, plasmaWidth - 1)
                    let idx2Y = clamp(y2 + lookupQuant * y, 0, plasmaHeight - 1)
                    let idx3X = clamp(x3 + lookupQuant * x, 0, plasmaWidth - 1)
                    let idx3Y = clamp(y3 + lookupQuant * y, 0, plasmaHeight - 1)

                    let value = plasma1[idx1Y][idx1X] + plasma2[idx2Y][idx2X] + plasma2[idx3Y][idx3X]

                    if value < lowestValue { lowestValue = value }
                    if value > highestValue { highestValue = value }
                    pixelBuffer[y][x] = value
                }
            }

            // Normalize and map to palette
            let valueRange = max(highestValue - lowestValue, 0.001)
            for y in 0..<options.standardOptions.height {
                for x in 0..<options.standardOptions.width {
                    let normalized = (pixelBuffer[y][x] - lowestValue) / valueRange
                    let paletteIdx = min(Int(round(normalized * 255)), 255)
                    canvas.setPixel(x: x, y: y, color: palette[paletteIdx])
                }
            }

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()

            count += 1
        }
    }

    private static func clamp(_ value: Int, _ min: Int, _ max: Int) -> Int {
        if value < min { return min }
        if value > max { return max }
        return value
    }
}
