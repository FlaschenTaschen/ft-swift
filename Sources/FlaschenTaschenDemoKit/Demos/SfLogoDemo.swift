// SF Logo - SF logo display
// Ported from sf-logo.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "sf-logo")

private let SF_LOGO_WIDTH = 24
private let SF_LOGO_HEIGHT = 34

// SVG to pixel scale factors
// SVG viewBox: 11.811159 × 16.708437 → 24 × 34 pixels
private let SVG_SCALE_X = 24.0 / 11.811159
private let SVG_SCALE_Y = 34.0 / 16.708437
private let SVG_OFFSET_X = 99.218739  // Layer translate offset
private let SVG_OFFSET_Y = 140.22917

// Helper function to apply SVG transform
private func applyTransform(_ points: [(Double, Double)], a: Double, e: Double, f: Double) -> [(Double, Double)] {
    return points.map { (x, y) in
        let tx = a * x + e
        let ty = a * y + f
        return (tx, ty)
    }
}

// Trunk lines (3 horizontal lines in lower section)
private let TRUNK_LINES: [((Double, Double), (Double, Double))] = [
    ((102.42126, 155.28395), (107.13085, 155.28395)),  // Top
    ((103.02981, 155.99834), (106.41648, 155.99834)),  // Middle
    ((103.74419, 156.73917), (105.7021, 156.73917))    // Bottom
]

// Center vertical line
private let CENTER_LINE = ((106.7869, 143.45709), (106.7869, 147.5052))

// Canopy outline - approximated from SVG bezier path
// Simplified as connected line segments following the organic shape (open path, clean right edge)
private let CANOPY_OUTLINE: [(Double, Double)] = [
    (100.83, 143.74),   // Center bottom of canopy
    (99.72, 142.89),    // Left curve
    (99.51, 142.17),    // Left upper
    (99.65, 141.31),    // Left top bulge
    (100.08, 140.73),   // Upper left node area
    (101.48, 139.84),   // Upper left to center
    (102.85, 139.52),   // Upper center left
    (104.65, 139.34),   // Top center
    (106.30, 139.23),   // Upper center right
    (107.69, 139.78),   // Upper right
    (108.69, 141.06),   // Right side
    (108.85, 142.39)    // Right lower (stops here, no connecting line)
]

// Branch nodes (circles)
private let BRANCH_NODES: [(Double, Double)] = [
    (102.5271, 147.955),      // Bottom center
    (102.28898, 142.76917),   // Upper left
    (104.64377, 143.66875),   // Middle
    (106.7869, 142.92792),    // Right middle
    (108.18919, 145.25626)    // Far right
]

// Polylines (roots and branches) with their transforms
private let POLYLINES_WITH_TRANSFORM: [[(Double, Double)]] = [
    // Transform: matrix(0.26458333, 0, 0, 0.26458333, 78.952727, 43.391667)
    // Polyline 1 - right root
    applyTransform([(99.8, 422.9), (99.8, 398.5), (110.5, 388.6), (110.5, 386.7)],
                   a: 0.26458333, e: 78.952727, f: 43.391667),
    // Polyline 2 - left root
    applyTransform([(95.3, 422.9), (95.3, 393.5), (88.2, 386.7), (88.2, 377.5)],
                   a: 0.26458333, e: 78.952727, f: 43.391667),
    // Polyline 3 - left branch
    applyTransform([(97.1, 381.1), (97.1, 384.3), (91.8, 390.1)],
                   a: 0.26458333, e: 78.952727, f: 43.391667),
    // Polyline 4 - right branch
    applyTransform([(89.1, 397.3), (89.1, 400.2), (95.3, 406.5)],
                   a: 0.26458333, e: 78.952727, f: 43.391667)
]

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
        var x = -1
        var y = -1
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

            // Animate position (move every 8 frames, like nb-logo)
            if (colorIndex % 8) == 0 {
                x += sx
                if x > (options.standardOptions.width - SF_LOGO_WIDTH) {
                    x -= sx
                    sy = 1
                    y += sy
                }
                if y > (options.standardOptions.height - SF_LOGO_HEIGHT) {
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

    // Convert SVG coordinates to pixel coordinates
    private static func svgToPixel(_ svgX: Double, _ svgY: Double) -> (Int, Int) {
        let x = Int((svgX - SVG_OFFSET_X) * SVG_SCALE_X + 0.5)
        let y = Int((svgY - SVG_OFFSET_Y) * SVG_SCALE_Y + 0.5)
        return (x, y)
    }

    private static func drawTreeLogoFlat(offsetX: Int, offsetY: Int, color: Color, width: Int, height: Int, canvas: inout UDPFlaschenTaschen) {
        let hw = width >> 1
        let hh = height >> 1

        // Helper to apply offset and bounds checking
        func screenPos(_ px: Int, _ py: Int) -> (Int, Int) {
            let sx = offsetX + px + hw - (LOGO_WIDTH / 2)
            let sy = offsetY + py + hh - (LOGO_HEIGHT / 2)
            return (sx, sy)
        }

        // Draw canopy outline (organic shape at top)
        for i in 0..<(CANOPY_OUTLINE.count - 1) {
            let (x0, y0) = svgToPixel(CANOPY_OUTLINE[i].0, CANOPY_OUTLINE[i].1)
            let (x1, y1) = svgToPixel(CANOPY_OUTLINE[i + 1].0, CANOPY_OUTLINE[i + 1].1)
            let (sx0, sy0) = screenPos(x0, y0)
            let (sx1, sy1) = screenPos(x1, y1)
            drawLine(x0: sx0, y0: sy0, x1: sx1, y1: sy1, color: color, width: width, height: height, canvas: &canvas)
        }

        // Draw trunk lines (3 horizontal lines)
        for line in TRUNK_LINES {
            let (x0, y0) = svgToPixel(line.0.0, line.0.1)
            let (x1, y1) = svgToPixel(line.1.0, line.1.1)
            let (sx0, sy0) = screenPos(x0, y0)
            let (sx1, sy1) = screenPos(x1, y1)
            drawLine(x0: sx0, y0: sy0, x1: sx1, y1: sy1, color: color, width: width, height: height, canvas: &canvas)
        }

        // Draw center vertical line
        let (cx0, cy0) = svgToPixel(CENTER_LINE.0.0, CENTER_LINE.0.1)
        let (cx1, cy1) = svgToPixel(CENTER_LINE.1.0, CENTER_LINE.1.1)
        let (scx0, scy0) = screenPos(cx0, cy0)
        let (scx1, scy1) = screenPos(cx1, cy1)
        drawLine(x0: scx0, y0: scy0, x1: scx1, y1: scy1, color: color, width: width, height: height, canvas: &canvas)

        // Draw polylines (roots and branches)
        for polyline in POLYLINES_WITH_TRANSFORM {
            for i in 0..<(polyline.count - 1) {
                let (x0, y0) = svgToPixel(polyline[i].0, polyline[i].1)
                let (x1, y1) = svgToPixel(polyline[i + 1].0, polyline[i + 1].1)
                let (sx0, sy0) = screenPos(x0, y0)
                let (sx1, sy1) = screenPos(x1, y1)
                drawLine(x0: sx0, y0: sy0, x1: sx1, y1: sy1, color: color, width: width, height: height, canvas: &canvas)
            }
        }

        // Draw branch nodes (circles with radius 1-2 pixels)
        let nodeRadius = 1
        for node in BRANCH_NODES {
            let (px, py) = svgToPixel(node.0, node.1)
            let (sx, sy) = screenPos(px, py)
            // Draw filled circle
            for dy in -nodeRadius...nodeRadius {
                for dx in -nodeRadius...nodeRadius {
                    if dx * dx + dy * dy <= nodeRadius * nodeRadius {
                        let x = sx + dx
                        let y = sy + dy
                        if x >= 0 && x < width && y >= 0 && y < height {
                            canvas.setPixel(x: x, y: y, color: color)
                        }
                    }
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
