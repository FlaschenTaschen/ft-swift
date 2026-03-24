// Depth - Visualization which shows depth via parallax scrolling layers

import Foundation
import os.log

private let logger = Logger(subsystem: Logging.subsystem, category: "depth")

private struct HillLayer {
    let baseColor: Color
    let scrollSpeed: Double
    let frequency: Double
    let amplitude: Double
    let midY: Double
    let fillBottom: Int
    var offset: Double = 0
}

private struct DepthBox {
    var x: Double          // left edge, can be negative off-screen
    let y: Int
    let sizeIndex: Int
    let speed: Double = 0.6
}

private struct BallState {
    var positionHistory: [(x: Int, y: Int)] = []  // track last 3 positions for tail
    var colorIndex: Int = 0  // cycles through palette for rainbow effect
}

private let boxSizes: [(w: Int, h: Int)] = [
    (4, 4), (6, 5), (8, 7), (10, 9), (13, 11)
]

private final class DepthState: @unchecked Sendable {
    var hills: [HillLayer]
    var boxes: [DepthBox]
    var ball: BallState
    var blurPixels: [UInt8]
    var palette: [Color]
    var groundOffset: Int = 0

    init(width: Int, height: Int) {
        let groundRows = 3
        let usableHeight = height - groundRows

        // Initialize hills - back layer is higher and taller to be visible above front layers
        self.hills = [
            HillLayer(baseColor: Color(r: 30, g: 60, b: 20),
                     scrollSpeed: 0.15,
                     frequency: 0.18,
                     amplitude: 10.0,
                     midY: Double(usableHeight) * 0.25,
                     fillBottom: usableHeight - 1),
            HillLayer(baseColor: Color(r: 50, g: 100, b: 35),
                     scrollSpeed: 0.25,
                     frequency: 0.22,
                     amplitude: 7.0,
                     midY: Double(usableHeight) * 0.45,
                     fillBottom: usableHeight - 1),
            HillLayer(baseColor: Color(r: 80, g: 160, b: 55),
                     scrollSpeed: 0.40,
                     frequency: 0.28,
                     amplitude: 5.0,
                     midY: Double(usableHeight) * 0.60,
                     fillBottom: usableHeight - 1)
        ]

        // Initialize boxes spread across display, positioned near the bottom like buildings
        self.boxes = []
        var x = Double(randomInt(min: 0, max: 15))
        while x < Double(width + 60) {
            let sizeIdx = randomInt(min: 0, max: 4)
            let bh = boxSizes[sizeIdx].h
            // Position boxes near the bottom (above ground strip) like buildings
            let y = randomInt(min: max(0, usableHeight - bh - 4), max: usableHeight - bh - 1)
            self.boxes.append(DepthBox(x: x, y: y, sizeIndex: sizeIdx))
            let gap = Double(randomInt(min: 20, max: 60))
            x += Double(boxSizes[sizeIdx].w) + gap
        }

        // Initialize ball
        self.ball = BallState()

        // Initialize blur buffer and palette
        self.blurPixels = [UInt8](repeating: 0, count: width * height)

        self.palette = [Color](repeating: Color(), count: 256)
        self.palette[0] = Color(r: 0, g: 0, b: 0)  // black

        // Build rainbow palette 1-255
        colorGradient(start: 1, end: 32,
                     r1: 255, g1: 0, b1: 255, r2: 0, g2: 0, b2: 255, palette: &self.palette)
        colorGradient(start: 33, end: 64,
                     r1: 0, g1: 0, b1: 255, r2: 0, g2: 255, b2: 255, palette: &self.palette)
        colorGradient(start: 65, end: 96,
                     r1: 0, g1: 255, b1: 255, r2: 0, g2: 255, b2: 0, palette: &self.palette)
        colorGradient(start: 97, end: 128,
                     r1: 0, g1: 255, b1: 0, r2: 127, g2: 255, b2: 0, palette: &self.palette)
        colorGradient(start: 129, end: 160,
                     r1: 127, g1: 255, b1: 0, r2: 255, g2: 255, b2: 0, palette: &self.palette)
        colorGradient(start: 161, end: 192,
                     r1: 255, g1: 255, b1: 0, r2: 255, g2: 127, b2: 0, palette: &self.palette)
        colorGradient(start: 193, end: 224,
                     r1: 255, g1: 127, b1: 0, r2: 255, g2: 0, b2: 0, palette: &self.palette)
        colorGradient(start: 225, end: 255,
                     r1: 255, g1: 0, b1: 0, r2: 255, g2: 0, b2: 255, palette: &self.palette)
    }
}

public struct DepthDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions

        public init(standardOptions: StandardOptions) {
            self.standardOptions = standardOptions
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        let w = options.standardOptions.width
        let h = options.standardOptions.height

        logger.info("depth: geometry=\(w, privacy: .public)x\(h, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms")

        let state = DepthState(width: w, height: h)
        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        let groundRows = 3

        await loop.run { count in
            canvas.clear()

            // Draw hills (back to front)
            for hillIdx in 0..<state.hills.count {
                let layer = state.hills[hillIdx]
                for x in 0..<w {
                    let hillTopY = Int(layer.midY + layer.amplitude * sin(Double(x) * layer.frequency + layer.offset))
                    let clampedTop = max(0, min(layer.fillBottom, hillTopY))
                    guard clampedTop < layer.fillBottom else { continue }
                    for y in clampedTop...layer.fillBottom {
                        canvas.setPixel(x: x, y: y, color: layer.baseColor)
                    }
                }
            }

            // Draw ground strip with gray brick pattern (bottom 3 rows)
            let brickGray = Color(r: 160, g: 160, b: 160)       // standard gray brick
            let darkBrick = Color(r: 110, g: 110, b: 110)       // dark gray brick
            let grout = Color(r: 70, g: 70, b: 70)              // dark grout/mortar
            let lightBrick = Color(r: 190, g: 190, b: 190)      // light gray brick for variation

            for gy in (h - groundRows)..<h {
                let rowOffset = gy - (h - groundRows)  // 0, 1, or 2
                for gx in 0..<w {
                    let scrollPos = gx + state.groundOffset
                    let brickX = scrollPos % 6  // bricks are 5 pixels wide + 1 grout
                    let brickY = (rowOffset + (scrollPos / 6) % 2) % 2  // staggered rows

                    var pixelColor: Color
                    if brickX == 5 {
                        // Grout lines
                        pixelColor = grout
                    } else if brickY == 0 {
                        // Odd rows: standard gray brick
                        pixelColor = (brickX % 2 == 0) ? brickGray : darkBrick
                    } else {
                        // Even rows: lighter gray brick for variation
                        pixelColor = (brickX % 2 == 0) ? lightBrick : brickGray
                    }

                    canvas.setPixel(x: gx, y: gy, color: pixelColor)
                }
            }

            // Draw boxes directly to canvas with solid colors
            let boxColors: [Color] = [
                Color(r: 200, g: 100, b: 50),   // Size 0: orange-brown
                Color(r: 100, g: 200, b: 150),  // Size 1: cyan-green
                Color(r: 200, g: 150, b: 100),  // Size 2: sandy brown
                Color(r: 150, g: 100, b: 200),  // Size 3: purple
                Color(r: 100, g: 150, b: 200)   // Size 4: blue
            ]
            for box in state.boxes {
                let bw = boxSizes[box.sizeIndex].w
                let bh = boxSizes[box.sizeIndex].h
                let bx = Int(box.x)
                let by = box.y
                let color = boxColors[box.sizeIndex]

                // Draw solid rectangle for the box
                for y in by..<(by + bh) {
                    for x in bx..<(bx + bw) {
                        if x >= 0 && x < w && y >= 0 && y < h {
                            canvas.setPixel(x: x, y: y, color: color)
                        }
                    }
                }
            }

            // Calculate ball position
            let frameF = Double(count)
            // Vertical motion: bouncing up and down
            let ballYRaw = Double(h / 2) + Double(h / 4 - 3) * sin(frameF * 0.05)
            let ballY = max(2, min(h - groundRows - 1, Int(ballYRaw)))
            // Horizontal position: fixed in view (appears to move right due to parallax)
            let ballX = w * 2 / 3  // Fixed position, right side of screen
            let ballPos = (x: ballX, y: ballY)

            // Draw balls with progressively darker shades (25% smaller)
            let ballRadii = [6, 4, 3, 1]
            let ballColor = state.palette[state.ball.colorIndex]

            // Brightness levels for each ball (100%, 75%, 50%, 25%)
            let brightnesses = [255, 190, 128, 64]

            // Draw main ball (radius 8, full brightness)
            drawFilledCircleWithBrightness(cx: ballPos.x, cy: ballPos.y, radius: ballRadii[0],
                                          color: ballColor, brightness: brightnesses[0],
                                          width: w, height: h, canvas: canvas)

            // Draw trailing balls from position history, ensuring no overlaps
            // Minimum distances needed to prevent overlap: radius1 + radius2
            let minDistances = [
                ballRadii[0] + ballRadii[1],  // lead ball (8) + trail 1 (6) = 14
                ballRadii[1] + ballRadii[2],  // trail 1 (6) + trail 2 (4) = 10
                ballRadii[2] + ballRadii[3]   // trail 2 (4) + trail 3 (2) = 6
            ]

            // Draw trailing balls showing the path the lead ball took
            // Each trail ball is at a previous position in the history with corresponding X offset
            let trailHistoryIndices = [12, 24, 36]  // frames back to sample
            let trailXOffsets = [10, 18, 26]  // horizontal distance to the left (closer together)

            for (idx, historyIdx) in trailHistoryIndices.enumerated() {
                if historyIdx < state.ball.positionHistory.count {
                    let trailPos = state.ball.positionHistory[historyIdx]
                    let trailX = ballX - trailXOffsets[idx]
                    let trailY = trailPos.y  // Get the Y position from when the ball was at this point in history

                    if trailX >= 0 {  // Only draw if within view
                        let radius = ballRadii[idx + 1]
                        let brightness = brightnesses[idx + 1]
                        drawFilledCircleWithBrightness(cx: trailX, cy: trailY, radius: radius,
                                                      color: ballColor, brightness: brightness,
                                                      width: w, height: h, canvas: canvas)
                    }
                }
            }

            // Send frame
            canvas.setOffset(x: options.standardOptions.xoff,
                            y: options.standardOptions.yoff,
                            z: options.standardOptions.layer)
            canvas.send()

            // Advance state
            for i in state.hills.indices {
                state.hills[i].offset += state.hills[i].scrollSpeed
            }

            // Update boxes
            for i in state.boxes.indices {
                state.boxes[i].x -= state.boxes[i].speed
            }
            state.boxes.removeAll { box in
                let bw = boxSizes[box.sizeIndex].w
                return box.x + Double(bw) < 0
            }

            // Spawn new boxes if needed
            if let rightmost = state.boxes.max(by: { $0.x < $1.x }) {
                let rightEdge = rightmost.x + Double(boxSizes[rightmost.sizeIndex].w)
                if rightEdge < Double(w + 40) {
                    let sizeIdx = randomInt(min: 0, max: 4)
                    let bh = boxSizes[sizeIdx].h
                    let gap = Double(randomInt(min: 20, max: 60))
                    let newX = max(rightEdge + gap, Double(w + 5))
                    let y = randomInt(min: max(0, h - groundRows - bh - 4), max: h - groundRows - bh - 1)
                    state.boxes.append(DepthBox(x: newX, y: y, sizeIndex: sizeIdx))
                }
            } else {
                // Seed initial box if empty (shouldn't happen)
                let sizeIdx = randomInt(min: 0, max: 4)
                let bh = boxSizes[sizeIdx].h
                let y = randomInt(min: max(0, h - groundRows - bh - 4), max: h - groundRows - bh - 1)
                state.boxes.append(DepthBox(x: Double(w / 2), y: y, sizeIndex: sizeIdx))
            }

            // Update ball position history (for tail effect)
            // Keep extensive history since the ball moves slowly horizontally
            state.ball.positionHistory.insert(ballPos, at: 0)
            if state.ball.positionHistory.count > 40 {
                state.ball.positionHistory.removeLast()
            }

            // Advance ball color
            state.ball.colorIndex = (state.ball.colorIndex + 1) % 256

            // Advance ground offset
            state.groundOffset = (state.groundOffset + 1) % 3
        }
    }

    // Draw a filled circle on the canvas with adjustable brightness
    private static func drawFilledCircleWithBrightness(cx: Int, cy: Int, radius: Int, color: Color,
                                                       brightness: Int, width: Int, height: Int,
                                                       canvas: UDPFlaschenTaschen) {
        let radiusSq = radius * radius
        let r = UInt8((Int(color.r) * brightness) / 255)
        let g = UInt8((Int(color.g) * brightness) / 255)
        let b = UInt8((Int(color.b) * brightness) / 255)
        let dimColor = Color(r: r, g: g, b: b)

        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx * dx + dy * dy <= radiusSq {
                    let x = cx + dx
                    let y = cy + dy
                    if x >= 0 && x < width && y >= 0 && y < height {
                        canvas.setPixel(x: x, y: y, color: dimColor)
                    }
                }
            }
        }
    }

    // Copy of blur3 from BlurDemo
    private static func blur3(width: Int, height: Int, pixels: inout [UInt8]) {
        var i = 0

        for _ in 0..<(height - 1) {
            for _ in 0..<(width - 1) {
                let dot1 = Int(pixels[i])
                let dot2 = Int(pixels[i + 1])
                let dot3 = Int(pixels[i + width])
                let dot4 = Int(pixels[i + width + 1])
                var dot = UInt8((dot1 + dot2 + dot3 + dot4) >> 2)
                dot = dot <= 8 ? 0 : dot - 8
                pixels[i] = dot
                i += 1
            }
            let dot1 = Int(pixels[i])
            let dot2 = Int(pixels[i + width])
            var dot = UInt8((dot1 + dot2) >> 2)
            dot = dot <= 8 ? 0 : dot - 8
            pixels[i] = dot
            i += 1
        }

        for _ in 0..<(width - 1) {
            let dot1 = Int(pixels[i])
            let dot2 = Int(pixels[i + 1])
            var dot = UInt8((dot1 + dot2) >> 2)
            dot = dot <= 8 ? 0 : dot - 8
            pixels[i] = dot
            i += 1
        }
        pixels[i] = 0
    }
}
