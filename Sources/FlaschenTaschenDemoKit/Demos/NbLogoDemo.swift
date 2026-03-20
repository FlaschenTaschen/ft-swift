// NB Logo - NB logo display
// Ported from nb-logo.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "nb-logo")

let LOGO_WIDTH = 16
let LOGO_HEIGHT = 15

let NB_LOGO: [String] = [
    "      ##.       ",
    "     #..#.      ",
    "   ###  ###.    ",
    "  #...  ...#.   ",
    "  #.      .#. #.",
    "##.      ..#.##.",
    "..###.   ####.#.",
    "###..    #..#.#.",
    "..###.   #..#.#.",
    "###..    ####.#.",
    "...## .. ..#.##.",
    "  #...##.  #..#.",
    "  #..#..#..#. . ",
    "   ###. ###.    ",
    "   ...  ...     "
]

public struct NbLogoDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var logoColor: Color?

        public init(standardOptions: StandardOptions, logoColor: Color? = nil) {
            self.standardOptions = standardOptions
            self.logoColor = logoColor
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("nb-logo: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms")

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

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        let blackColor = Color(r: 1, g: 1, b: 1)

        var colorIndex = 0
        var x = -1
        var y = -1
        var sx = 1
        var sy = 1

        await loop.run { _ in
            // Get current color (fixed or from palette)
            let currentColor = options.logoColor ?? palette[colorIndex]

            // Clear and draw logo
            canvas.clear()

            for logoY in 0..<LOGO_HEIGHT {
                let line = NB_LOGO[logoY]
                for (logoX, char) in line.enumerated() {
                    if char == "#" {
                        canvas.setPixel(x: x + logoX + 1, y: y + logoY + 1, color: currentColor)
                    } else if char == "." {
                        canvas.setPixel(x: x + logoX + 1, y: y + logoY + 1, color: blackColor)
                    }
                }
            }

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()

            // Animate position (move every 8 frames)
            if (colorIndex % 8) == 0 {
                x += sx
                if x > (options.standardOptions.width - LOGO_WIDTH) {
                    x -= sx
                    sy = 1
                    y += sy
                }
                if y > (options.standardOptions.height - LOGO_HEIGHT) {
                    y -= sy
                    sx = -1
                    x += sx
                }
                if x < -1 {
                    x -= sx
                    sy = -1
                    y += sy
                }
                if y < -1 {
                    y -= sy
                    sx = 1
                    x += sx
                }
            }

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
