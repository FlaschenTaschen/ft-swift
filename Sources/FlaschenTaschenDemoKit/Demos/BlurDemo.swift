// Blur - Animated blur effect with pattern options
// Ported from blur.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "blur")

public enum BlurDemoType: Sendable {
    case bolt
    case boxes
    case circles
    case target
    case fire
    case all
}

public struct BlurDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var palette: Int = -1  // default cycles
        public var demo: BlurDemoType = .bolt
        public var orient: Int = 0

        public init(standardOptions: StandardOptions, palette: Int = -1, demo: BlurDemoType = .bolt, orient: Int = 0) {
            self.standardOptions = standardOptions
            self.palette = palette
            self.demo = demo
            self.orient = orient
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("blur: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms palette=\(options.palette, privacy: .public) orient=\(options.orient, privacy: .public) demo=\(String(describing: options.demo), privacy: .public)")

        var pixels = [UInt8](repeating: 0, count: options.standardOptions.width * options.standardOptions.height)

        var palette = [Color](repeating: Color(), count: 256)
        var curPalette = getPaletteType(rawValue: options.palette < 0 ? 1 : options.palette)
        curPalette.apply(to: &palette)

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        var curDemo = options.demo == .all ? BlurDemoType.bolt : options.demo

        await loop.run { count in
            if count % 100 == 0 && options.palette < 0 {
                curPalette = nextPaletteType(curPalette)
                curPalette.apply(to: &palette)
            }

            if options.demo == .all && count % 300 == 0 {
                switch curDemo {
                case .bolt: curDemo = .boxes
                case .boxes: curDemo = .circles
                case .circles: curDemo = .target
                case .target: curDemo = .fire
                case .fire: curDemo = .bolt
                case .all: curDemo = .bolt
                }
            }

            if count % 2 == 0 {
                switch curDemo {
                case .bolt: drawRandomBolt(width: options.standardOptions.width, height: options.standardOptions.height, pixels: &pixels)
                case .boxes: drawRandomBox(width: options.standardOptions.width, height: options.standardOptions.height, pixels: &pixels)
                case .circles: drawRandomCircle(width: options.standardOptions.width, height: options.standardOptions.height, pixels: &pixels)
                case .target: drawRandomTarget(width: options.standardOptions.width, height: options.standardOptions.height, pixels: &pixels)
                case .fire, .all: break
                }
            }

            if curDemo == .fire {
                drawRandomFire(width: options.standardOptions.width, height: options.standardOptions.height, orient: options.orient, pixels: &pixels)
                blurFire(width: options.standardOptions.width, height: options.standardOptions.height, orient: options.orient, pixels: &pixels)
                clearBottomRow(width: options.standardOptions.width, height: options.standardOptions.height, orient: options.orient, pixels: &pixels)
            } else {
                blur3(width: options.standardOptions.width, height: options.standardOptions.height, pixels: &pixels)
            }

            for y in 0..<options.standardOptions.height {
                for x in 0..<options.standardOptions.width {
                    let pixelIndex = y * options.standardOptions.width + x
                    let paletteIndex = Int(pixels[pixelIndex])
                    canvas.setPixel(x: x, y: y, color: palette[paletteIndex])
                }
            }

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()
        }
    }

    private static func drawBox(x1: Int, y1: Int, x2: Int, y2: Int, color: UInt8, width: Int, height: Int, pixels: inout [UInt8]) {
        for x in x1...x2 {
            if y1 < height { pixels[y1 * width + x] = color }
            if y2 < height { pixels[y2 * width + x] = color }
        }
        for y in y1...y2 {
            pixels[y * width + x1] = color
            pixels[y * width + x2] = color
        }
    }

    private static func drawRandomBox(width: Int, height: Int, pixels: inout [UInt8]) {
        let x1 = randomInt(min: 0, max: width - 2)
        let y1 = randomInt(min: 0, max: height - 2)
        let x2 = randomInt(min: x1, max: width - 1)
        let y2 = randomInt(min: y1, max: height - 1)
        drawBox(x1: x1, y1: y1, x2: x2, y2: y2, color: 0xFF, width: width, height: height, pixels: &pixels)
    }

    private static func setPixel(x0: Int, y0: Int, color: UInt8, width: Int, height: Int, pixels: inout [UInt8]) {
        if x0 >= 0 && x0 < width && y0 >= 0 && y0 < height {
            pixels[y0 * width + x0] = color
        }
    }

    private static func drawCircle(x0: Int, y0: Int, radius: Int, color: UInt8, width: Int, height: Int, pixels: inout [UInt8]) {
        var x = radius
        var y = 0
        var radiusError = 1 - x

        while y <= x {
            setPixel(x0: x + x0, y0: y + y0, color: color, width: width, height: height, pixels: &pixels)
            setPixel(x0: y + x0, y0: x + y0, color: color, width: width, height: height, pixels: &pixels)
            setPixel(x0: -x + x0, y0: y + y0, color: color, width: width, height: height, pixels: &pixels)
            setPixel(x0: -y + x0, y0: x + y0, color: color, width: width, height: height, pixels: &pixels)
            setPixel(x0: -x + x0, y0: -y + y0, color: color, width: width, height: height, pixels: &pixels)
            setPixel(x0: -y + x0, y0: -x + y0, color: color, width: width, height: height, pixels: &pixels)
            setPixel(x0: x + x0, y0: -y + y0, color: color, width: width, height: height, pixels: &pixels)
            setPixel(x0: y + x0, y0: -x + y0, color: color, width: width, height: height, pixels: &pixels)

            y += 1
            if radiusError < 0 {
                radiusError += 2 * y + 1
            } else {
                x -= 1
                radiusError += 2 * (y - x + 1)
            }
        }
    }

    private static func drawRandomCircle(width: Int, height: Int, pixels: inout [UInt8]) {
        let x0 = randomInt(min: 0, max: width - 2)
        let y0 = randomInt(min: 0, max: height - 2)
        let radius = randomInt(min: 2, max: width / 3)
        drawCircle(x0: x0, y0: y0, radius: radius, color: 0xFF, width: width, height: height, pixels: &pixels)
    }

    private static func drawRandomTarget(width: Int, height: Int, pixels: inout [UInt8]) {
        let x0 = width / 2
        let y0 = width / 2
        let radius = randomInt(min: 2, max: width / 2)
        drawCircle(x0: x0, y0: y0, radius: radius, color: 0xFF, width: width, height: height, pixels: &pixels)
    }

    private static func drawRandomBolt(width: Int, height: Int, pixels: inout [UInt8]) {
        let hh = height >> 1
        var wave = 0

        for x in 0..<width {
            wave += randomInt(min: -1, max: 1)
            var y = hh + wave
            if y < 0 || y >= height { y = hh }
            pixels[y * width + x] = 0xFF
        }
    }

    private static func drawRandomFire(width: Int, height: Int, orient: Int, pixels: inout [UInt8]) {
        let color: UInt8 = 0xFF

        if orient == 0 {
            let num = randomInt(min: 1, max: width - 2)
            for _ in 0..<num {
                let x = randomInt(min: 1, max: width - 2)
                let y = height - 1
                pixels[y * width + x] = color
            }
        } else {
            let num = randomInt(min: 1, max: height - 2)
            for _ in 0..<num {
                let x = width - 1
                let y = randomInt(min: 1, max: height - 2)
                pixels[y * width + x] = color
            }
        }
    }

    private static func clearBottomRow(width: Int, height: Int, orient: Int, pixels: inout [UInt8]) {
        if orient == 0 {
            let by = (height - 1) * width
            for x in 0..<width {
                pixels[by + x] = 0
            }
        } else {
            let bx = width - 1
            for y in 0..<height {
                pixels[y * width + bx] = 0
            }
        }
    }

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

    private static func blurFire(width: Int, height: Int, orient: Int, pixels: inout [UInt8]) {
        let step: UInt8 = 4

        if orient == 0 {
            for i in 1..<(width * (height - 1) - 1) {
                let vals = [
                    Int(pixels[i - 1]),
                    Int(pixels[i + 1]),
                    Int(pixels[i + width - 1]),
                    Int(pixels[i + width]),
                    Int(pixels[i + width + 1]),
                    Int(pixels[i + 2 * width - 1]),
                    Int(pixels[i + 2 * width]),
                    Int(pixels[i + 2 * width + 1])
                ]
                var dot = UInt8((vals.reduce(0, +)) >> 3)
                dot = dot <= step ? 0 : dot - step
                pixels[i] = dot
            }
        } else {
            for i in 1..<(width * (height - 1) - 1) {
                if i % width == 0 { continue }
                let vals = [
                    Int(pixels[i - 1]),
                    Int(pixels[i]),
                    Int(pixels[i + 1]),
                    Int(pixels[i + width]),
                    Int(pixels[i + width + 1]),
                    Int(pixels[i + 2 * width - 1]),
                    Int(pixels[i + 2 * width]),
                    Int(pixels[i + 2 * width + 1])
                ]
                var dot = UInt8((vals.reduce(0, +)) >> 3)
                dot = dot <= step ? 0 : dot - step
                pixels[i + width - 1] = dot
            }
        }
    }
}
