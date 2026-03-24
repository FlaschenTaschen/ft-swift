// SF Logo - SF logo display
// Ported from sf-logo.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "sf-logo")

private let SF_LOGO_WIDTH = 40
private let SF_LOGO_HEIGHT = 56

public struct SfLogoDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var logoColor: Color?

        public init(standardOptions: StandardOptions, logoColor: Color? = nil) {
            self.standardOptions = standardOptions
            self.logoColor = logoColor
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("sf-logo: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms")

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

        var colorIndex = 0
        var x = 0
        var y = 0
        var sx = 1
        var sy = 1
        var canvas = canvas  // Make mutable copy for inout passing

        await loop.run { _ in
            // Get current color (fixed or from palette)
            let currentColor = options.logoColor ?? palette[colorIndex]

            // Clear canvas
            canvas.clear()

            // Draw tree logo at current position
            drawTreeLogoFlat(offsetX: x, offsetY: y, color: currentColor, width: options.standardOptions.width, height: options.standardOptions.height, canvas: &canvas)

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()

            // Animate position (move every 8 frames)
            if (colorIndex % 8) == 0 {
                // Calculate next position
                let nextX = x + sx
                let nextY = y + sy

                // Bounce off left/right edges
                if nextX < 0 {
                    x = 0
                    sx = 1
                } else if nextX + SF_LOGO_WIDTH > options.standardOptions.width {
                    x = options.standardOptions.width - SF_LOGO_WIDTH
                    sx = -1
                } else {
                    x = nextX
                }

                // Bounce off top/bottom edges
                if nextY < 0 {
                    y = 0
                    sy = 1
                } else if nextY + SF_LOGO_HEIGHT > options.standardOptions.height {
                    y = options.standardOptions.height - SF_LOGO_HEIGHT
                    sy = -1
                } else {
                    y = nextY
                }
            }

            colorIndex = (colorIndex + 1) % 256
        }
    }

    private static func drawTreeLogoFlat(offsetX: Int, offsetY: Int, color: Color, width: Int, height: Int, canvas: inout UDPFlaschenTaschen) {
        // Draw logo from grayscale pixel data
        for pixelY in 0..<SF_LOGO_GRAYSCALE.count {
            for pixelX in 0..<SF_LOGO_GRAYSCALE[pixelY].count {
                let grayValue = SF_LOGO_GRAYSCALE[pixelY][pixelX]

                // Skip white pixels (background)
                if grayValue >= 240 {
                    continue
                }

                // Apply color based on grayscale intensity
                // Dark pixels (low grayscale) get full color, light pixels get darker version
                let intensity = Float(255 - grayValue) / 255.0
                let pixelColor = Color(
                    r: UInt8(Float(color.r) * intensity),
                    g: UInt8(Float(color.g) * intensity),
                    b: UInt8(Float(color.b) * intensity)
                )

                // Place pixel on canvas with logo position offset
                let screenX = offsetX + pixelX
                let screenY = offsetY + pixelY

                if screenX >= 0 && screenX < width && screenY >= 0 && screenY < height {
                    canvas.setPixel(x: screenX, y: screenY, color: pixelColor)
                }
            }
        }
    }

    // Color gradient helper
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
