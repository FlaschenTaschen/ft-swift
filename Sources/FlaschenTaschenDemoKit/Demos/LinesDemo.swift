// Lines - Random line drawing animation
// Ported from lines.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "lines")

struct Line {
    var x1: Int
    var y1: Int
    var x2: Int
    var y2: Int
}

class ColorState: @unchecked Sendable {
    var count = 0
    var oldR = 0, oldG = 0, oldB = 0
    var newR = 0, newG = 0, newB = 0
    var skpR = 0, skpG = 0, skpB = 0
    var curR = 0, curG = 0, curB = 0

    func reset() {
        count = 0
    }
}

class LineState: @unchecked Sendable {
    var linesArray: [Line]
    var linesIdx = 0
    var lineSkip = Line(x1: 0, y1: 0, x2: 0, y2: 0)

    init(numLines: Int) {
        linesArray = (0..<numLines).map { _ in Line(x1: 0, y1: 0, x2: 0, y2: 0) }
    }
}

public struct LinesDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var drawNum: Int = 1

        public init(standardOptions: StandardOptions, drawNum: Int = 1) {
            self.standardOptions = standardOptions
            self.drawNum = drawNum
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("lines: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) drawNum=\(options.drawNum, privacy: .public)")

        canvas.clear()

        let colorState = ColorState()
        let lineState = LineState(numLines: 6)
        let transparent = Color(r: 0, g: 0, b: 0)
        var color = nextColor(colorState, reset: true)
        var line = nextLine(lineState, width: options.standardOptions.width, height: options.standardOptions.height, skipMin: 1, skipMax: 3, reset: true)

        logger.info("Starting animation loop with \(lineState.linesArray.count) lines")

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        var frameCount = 0
        await loop.run { _ in
            frameCount += 1
            if frameCount % 10 == 0 {
                logger.info("Frame \(frameCount): drawing line at (\(line.x1),\(line.y1))-(\(line.x2),\(line.y2))")
            }

            drawAllLines(lastLine(lineState), transparent, width: options.standardOptions.width, height: options.standardOptions.height, drawNum: options.drawNum, canvas: canvas)

            color = nextColor(colorState, reset: false)
            line = nextLine(lineState, width: options.standardOptions.width, height: options.standardOptions.height, skipMin: 1, skipMax: 3, reset: false)
            drawAllLines(line, color, width: options.standardOptions.width, height: options.standardOptions.height, drawNum: options.drawNum, canvas: canvas)

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()
        }
    }

    private static func nextColor(_ colorState: ColorState, reset: Bool) -> Color {
        if reset {
            colorState.reset()
        }

        colorState.count -= 1
        if colorState.count < 0 {
            colorState.count = 15
            colorState.oldR = colorState.newR
            colorState.oldG = colorState.newG
            colorState.oldB = colorState.newB

            repeat {
                colorState.newR = randomInt(min: 0, max: 1) * 255
                colorState.newG = randomInt(min: 0, max: 1) * 255
                colorState.newB = randomInt(min: 0, max: 1) * 255
            } while colorState.newR == 0 && colorState.newG == 0 && colorState.newB == 0

            colorState.skpR = colorState.newR == colorState.oldR ? 0 : (colorState.newR > colorState.oldR ? 16 : -16)
            colorState.skpG = colorState.newG == colorState.oldG ? 0 : (colorState.newG > colorState.oldG ? 16 : -16)
            colorState.skpB = colorState.newB == colorState.oldB ? 0 : (colorState.newB > colorState.oldB ? 16 : -16)
            colorState.curR = colorState.oldR
            colorState.curG = colorState.oldG
            colorState.curB = colorState.oldB
        }

        colorState.curR += colorState.skpR
        colorState.curG += colorState.skpG
        colorState.curB += colorState.skpB

        return Color(
            r: UInt8(Double(colorState.curR) / 256.0 * 255.0),
            g: UInt8(Double(colorState.curG) / 256.0 * 255.0),
            b: UInt8(Double(colorState.curB) / 256.0 * 255.0)
        )
    }

    private static func nextLine(_ lineState: LineState, width: Int, height: Int, skipMin: Int, skipMax: Int, reset: Bool) -> Line {
        let oldIdx = lineState.linesIdx
        lineState.linesIdx += 1
        if lineState.linesIdx >= lineState.linesArray.count {
            lineState.linesIdx = 0
        }

        if reset {
            lineState.linesArray[lineState.linesIdx] = Line(
                x1: randomInt(min: 1, max: width - 2),
                y1: randomInt(min: 1, max: height - 2),
                x2: randomInt(min: 1, max: width - 2),
                y2: randomInt(min: 1, max: height - 2)
            )

            lineState.lineSkip = Line(
                x1: (randomInt(min: 0, max: 1) == 1) ? randomInt(min: skipMin, max: skipMax) : -randomInt(min: skipMin, max: skipMax),
                y1: (randomInt(min: 0, max: 1) == 1) ? randomInt(min: skipMin, max: skipMax) : -randomInt(min: skipMin, max: skipMax),
                x2: (randomInt(min: 0, max: 1) == 1) ? randomInt(min: skipMin, max: skipMax) : -randomInt(min: skipMin, max: skipMax),
                y2: (randomInt(min: 0, max: 1) == 1) ? randomInt(min: skipMin, max: skipMax) : -randomInt(min: skipMin, max: skipMax)
            )
        } else {
            lineState.linesArray[lineState.linesIdx] = Line(
                x1: lineState.linesArray[oldIdx].x1 + lineState.lineSkip.x1,
                y1: lineState.linesArray[oldIdx].y1 + lineState.lineSkip.y1,
                x2: lineState.linesArray[oldIdx].x2 + lineState.lineSkip.x2,
                y2: lineState.linesArray[oldIdx].y2 + lineState.lineSkip.y2
            )

            if lineState.linesArray[lineState.linesIdx].x1 <= 0 {
                lineState.lineSkip.x1 = randomInt(min: skipMin, max: skipMax)
            }
            if lineState.linesArray[lineState.linesIdx].x1 >= width {
                lineState.lineSkip.x1 = -randomInt(min: skipMin, max: skipMax)
            }
            if lineState.linesArray[lineState.linesIdx].y1 <= 0 {
                lineState.lineSkip.y1 = randomInt(min: skipMin, max: skipMax)
            }
            if lineState.linesArray[lineState.linesIdx].y1 >= height {
                lineState.lineSkip.y1 = -randomInt(min: skipMin, max: skipMax)
            }
            if lineState.linesArray[lineState.linesIdx].x2 <= 0 {
                lineState.lineSkip.x2 = randomInt(min: skipMin, max: skipMax)
            }
            if lineState.linesArray[lineState.linesIdx].x2 >= width {
                lineState.lineSkip.x2 = -randomInt(min: skipMin, max: skipMax)
            }
            if lineState.linesArray[lineState.linesIdx].y2 <= 0 {
                lineState.lineSkip.y2 = randomInt(min: skipMin, max: skipMax)
            }
            if lineState.linesArray[lineState.linesIdx].y2 >= height {
                lineState.lineSkip.y2 = -randomInt(min: skipMin, max: skipMax)
            }
        }

        return lineState.linesArray[lineState.linesIdx]
    }

    private static func lastLine(_ lineState: LineState) -> Line {
        var lastIdx = lineState.linesIdx + 1
        if lastIdx >= lineState.linesArray.count {
            lastIdx = 0
        }
        return lineState.linesArray[lastIdx]
    }

    private static func drawAllLines(_ line: Line, _ color: Color, width: Int, height: Int, drawNum: Int, canvas: UDPFlaschenTaschen) {
        drawLine(line.x1, line.y1, line.x2, line.y2, color, width: width, height: height, canvas: canvas)
        if drawNum >= 2 {
            drawLine(width - line.x1, height - line.y1,
                     width - line.x2, height - line.y2, color, width: width, height: height, canvas: canvas)
        }
        if drawNum == 4 {
            drawLine(width - line.x1, line.y1, width - line.x2, line.y2, color, width: width, height: height, canvas: canvas)
            drawLine(line.x1, height - line.y1, line.x2, height - line.y2, color, width: width, height: height, canvas: canvas)
        }
    }

    private static func drawLine(_ x1: Int, _ y1: Int, _ x2: Int, _ y2: Int, _ color: Color, width: Int, height: Int, canvas: UDPFlaschenTaschen) {
        var x = x1
        var y = y1
        let dx = abs(x2 - x1)
        let dy = abs(y2 - y1)
        let sx = x1 < x2 ? 1 : -1
        let sy = y1 < y2 ? 1 : -1
        var err = dx - dy

        while true {
            if x >= 0 && x < width && y >= 0 && y < height {
                canvas.setPixel(x: x, y: y, color: color)
            }

            if x == x2 && y == y2 { break }

            let e2 = 2 * err
            if e2 > -dy {
                err -= dy
                x += sx
            }
            if e2 < dx {
                err += dx
                y += sy
            }
        }
    }
}
