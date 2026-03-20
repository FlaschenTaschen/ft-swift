// Sierpinski - Sierpinski's Triangle fractal
// Ported from sierpinski.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "sierpinski")

public struct SierpinskiDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var paletteMode: Bool = true
        public var fgColor: Color = Color()
        public var bgColor: Color = Color(r: 1, g: 1, b: 1)

        public init(standardOptions: StandardOptions, paletteMode: Bool = true,
                    fgColor: Color = Color(), bgColor: Color = Color(r: 1, g: 1, b: 1)) {
            self.standardOptions = standardOptions
            self.paletteMode = paletteMode
            self.fgColor = fgColor
            self.bgColor = bgColor
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("sierpinski: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms")

        // Create rainbow palette
        var palette = [Color](repeating: Color(), count: 256)
        colorGradient(start: 0, end: 31, r1: 255, g1: 0, b1: 255, r2: 0, g2: 0, b2: 255, palette: &palette)
        colorGradient(start: 32, end: 63, r1: 0, g1: 0, b1: 255, r2: 0, g2: 255, b2: 255, palette: &palette)
        colorGradient(start: 64, end: 95, r1: 0, g1: 255, b1: 255, r2: 0, g2: 255, b2: 0, palette: &palette)
        colorGradient(start: 96, end: 127, r1: 0, g1: 255, b1: 0, r2: 127, g2: 255, b2: 0, palette: &palette)
        colorGradient(start: 128, end: 159, r1: 127, g1: 255, b1: 0, r2: 255, g2: 255, b2: 0, palette: &palette)
        colorGradient(start: 160, end: 191, r1: 255, g1: 255, b1: 0, r2: 255, g2: 127, b2: 0, palette: &palette)
        colorGradient(start: 192, end: 223, r1: 255, g1: 127, b1: 0, r2: 255, g2: 0, b2: 0, palette: &palette)
        colorGradient(start: 224, end: 255, r1: 255, g1: 0, b1: 0, r2: 255, g2: 0, b2: 255, palette: &palette)

        // Pixel buffer for accumulating points
        var pixels = [UInt8](repeating: 0, count: options.standardOptions.width * options.standardOptions.height)

        // Chaos game: random vertices
        let vertices: [(Double, Double)] = [(0.5, 1.0), (0.0, 0.0), (1.0, 0.0)]

        // Start with random point
        var sx = Double.random(in: 0..<1.0)
        var sy = Double.random(in: 0..<1.0)

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        var colorIndex = 0

        await loop.run { _ in
            // Pick random vertex
            let vertex = vertices.randomElement()!
            sx = (sx + vertex.0) / 2.0
            sy = (sy + vertex.1) / 2.0

            // Convert to pixel coordinates
            let sxp = Int(Double(options.standardOptions.width - 1) * sx)
            let syp = options.standardOptions.height - Int(Double(options.standardOptions.height - 1) * sy) - 1

            // Mark pixel
            if sxp >= 0 && sxp < options.standardOptions.width && syp >= 0 && syp < options.standardOptions.height {
                pixels[syp * options.standardOptions.width + sxp] = 1
            }

            // Get current color
            let drawColor = options.paletteMode ? palette[colorIndex] : options.fgColor

            // Copy pixel buffer to canvas
            for y in 0..<options.standardOptions.height {
                for x in 0..<options.standardOptions.width {
                    let pixelValue = pixels[y * options.standardOptions.width + x]
                    canvas.setPixel(x: x, y: y, color: pixelValue != 0 ? drawColor : options.bgColor)
                }
            }

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()

            colorIndex = (colorIndex + 1) % 256
        }
    }

    private static func colorGradient(
        start: Int,
        end: Int,
        r1: UInt8,
        g1: UInt8,
        b1: UInt8,
        r2: UInt8,
        g2: UInt8,
        b2: UInt8,
        palette: inout [Color]
    ) {
        let range = end - start
        for i in 0...range {
            let k = Float(i) / Float(range)
            let r = UInt8(Float(r1) + (Float(r2) - Float(r1)) * k)
            let g = UInt8(Float(g1) + (Float(g2) - Float(g1)) * k)
            let b = UInt8(Float(b1) + (Float(b2) - Float(b1)) * k)
            palette[start + i] = Color(r: r, g: g, b: b)
        }
    }
}
