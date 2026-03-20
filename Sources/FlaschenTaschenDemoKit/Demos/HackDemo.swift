// Hack - Text display with Matrix-style effect
// Ported from hack.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "hack")

// Vector font data: 36 characters (0-9, A-Z), up to 25 line segments each
// Each line is [x1, y1, x2, y2]
// Ported from hack_font.h by Carl Gorringe
let hackFont: [[[Int]]] = [
    // 0
    [[-2,-6, 2,-6],[ 2,-6, 4,-4],[ 4,-4, 4, 4],[ 4, 4, 2, 6],[ 2, 6,-2, 6],[-2, 6,-4, 4],[-4, 4,-4,-4],[-4,-4,-2,-6],[-2,-4, 2,-4],[ 2,-4, 2, 4],[ 2, 4,-2, 4],[-2, 4,-2,-4]],
    // 1
    [[ 1,-2,-1, 0],[-1, 0,-3, 0],[-3, 0, 1,-6],[ 1,-6, 3,-6],[ 3,-6, 3, 6],[ 3, 6, 1, 6],[ 1, 6, 1,-2]],
    // 2
    [[-4,-2,-4,-4],[-4,-4,-2,-6],[-2,-6, 2,-6],[ 2,-6, 4,-4],[ 4,-4, 4,-2],[ 4,-2,-2, 4],[-2, 4, 4, 4],[ 4, 4, 4, 6],[ 4, 6,-4, 6],[-4, 6,-4, 4],[-4, 4, 2,-2],[ 2,-2, 2,-4],[ 2,-4,-2,-4],[-2,-4,-2,-2],[-2,-2,-4,-2]],
    // 3
    [[-4,-2,-4,-4],[-4,-4,-2,-6],[-2,-6, 2,-6],[ 2,-6, 4,-4],[ 4,-4, 4,-2],[ 4,-2, 2, 0],[ 2, 0, 4, 2],[ 4, 2, 4, 4],[ 4, 4, 2, 6],[ 2, 6,-2, 6],[-2, 6,-4, 4],[-4, 4,-4, 2],[-4, 2,-2, 2],[-2, 2,-2, 4],[-2, 4, 2, 4],[ 2, 4, 2, 2],[ 2, 2, 0, 0],[ 0, 0, 2,-2],[ 2,-2, 2,-4],[ 2,-4,-2,-4],[-2,-4,-2,-2],[-2,-2,-4,-2]],
    // 4
    [[-4,-6,-2,-6],[-2,-6,-2,-2],[-2,-2, 2,-2],[ 2,-2, 2,-6],[ 2,-6, 4,-6],[ 4,-6, 4, 6],[ 4, 6, 2, 6],[ 2, 6, 2, 0],[ 2, 0,-4, 0],[-4, 0,-4,-6]],
    // 5
    [[ 4,-6,-4,-6],[-4,-6,-4, 0],[-4, 0, 0, 0],[ 0, 0, 2, 2],[ 2, 2, 0, 4],[ 0, 4,-4, 4],[-4, 4,-4, 6],[-4, 6, 2, 6],[ 2, 6, 4, 4],[ 4, 4, 4, 0],[ 4, 0, 2,-2],[ 2,-2,-2,-2],[-2,-2,-2,-4],[-2,-4, 4,-4],[ 4,-4, 4,-6]],
    // 6
    [[ 4,-6, 4,-4],[ 4,-4,-2,-4],[-2,-4,-2,-2],[-2,-2, 2,-2],[ 2,-2, 4, 0],[ 4, 0, 4, 4],[ 4, 4, 2, 6],[ 2, 6,-2, 6],[-2, 6,-4, 4],[-4, 4,-4,-4],[-4,-4,-2,-6],[-2,-6, 4,-6],[-2, 0, 2, 0],[ 2, 0, 2, 4],[ 2, 4,-2, 4],[-2, 4,-2, 0]],
    // 7
    [[-4,-6, 4,-6],[ 4,-6, 4,-4],[ 4,-4, 0, 6],[ 0, 6,-2, 6],[-2, 6, 2,-4],[ 2,-4,-4,-4],[-4,-4,-4,-6]],
    // 8
    [[-2,-6, 2,-6],[ 2,-6, 4,-4],[ 4,-4, 4,-2],[ 4,-2, 2, 0],[ 2, 0, 4, 2],[ 4, 2, 4, 4],[ 4, 4, 2, 6],[ 2, 6,-2, 6],[-2, 6,-4, 4],[-4, 4,-4, 2],[-4, 2,-2, 0],[-2, 0,-4,-2],[-4,-2,-4,-4],[-4,-4,-2,-6],[-2,-4, 2,-4],[ 2,-4, 2,-2],[ 2,-2,-2,-2],[-2,-2,-2,-4],[-2, 4, 2, 4],[ 2, 4, 2, 2],[ 2, 2,-2, 2],[-2, 2,-2, 4]],
    // 9
    [[-2,-6, 2,-6],[ 2,-6, 4,-4],[ 4,-4, 4, 4],[ 4, 4, 2, 6],[ 2, 6,-2, 6],[-2, 6,-4, 4],[-4, 4,-4, 2],[-4, 2,-2, 2],[-2, 2,-2, 4],[-2, 4, 2, 4],[ 2, 4, 2, 0],[ 2, 0,-2, 0],[-2, 0,-4,-2],[-4,-2,-4,-4],[-4,-4,-2,-6],[-2,-4, 2,-4],[ 2,-4, 2,-2],[ 2,-2,-2,-2],[-2,-2,-2,-4]],
    // A
    [[-2,-6, 2,-6],[ 2,-6, 4,-2],[ 4,-2, 4, 6],[ 4, 6, 2, 6],[ 2, 6, 2, 2],[ 2, 2,-2, 2],[-2, 2,-2, 6],[-2, 6,-4, 6],[-4, 6,-4,-2],[-4,-2,-2,-6],[ 0,-4, 2, 0],[ 2, 0,-2, 0],[-2, 0, 0,-4]],
    // B
    [[-4,-6, 2,-6],[ 2,-6, 4,-4],[ 4,-4, 4,-2],[ 4,-2, 2, 0],[ 2, 0, 4, 2],[ 4, 2, 4, 4],[ 4, 4, 2, 6],[ 2, 6,-4, 6],[-4, 6,-4,-6],[-2,-4, 2,-4],[ 2,-4, 2,-2],[ 2,-2,-2,-2],[-2,-2,-2,-4],[-2, 2, 2, 2],[ 2, 2, 2, 4],[ 2, 4,-2, 4],[-2, 4,-2, 2]],
    // C
    [[ 4,-6,-2,-6],[-2,-6,-4,-4],[-4,-4,-4, 4],[-4, 4,-2, 6],[-2, 6, 4, 6],[ 4, 6, 4, 4],[ 4, 4, 0, 4],[ 0, 4,-2, 2],[-2, 2,-2,-2],[-2,-2, 0,-4],[ 0,-4, 4,-4],[ 4,-4, 4,-6]],
    // D
    [[-4,-6, 2,-6],[ 2,-6, 4,-4],[ 4,-4, 4, 4],[ 4, 4, 2, 6],[ 2, 6,-4, 6],[-4, 6,-4,-6],[-2,-4, 2,-4],[ 2,-4, 2, 4],[ 2, 4,-2, 4],[-2, 4,-2,-4]],
    // E
    [[ 4,-6,-4,-6],[-4,-6,-4, 6],[-4, 6, 4, 6],[ 4, 6, 4, 4],[ 4, 4,-2, 4],[-2, 4,-2, 0],[-2, 0, 2, 0],[ 2, 0, 2,-2],[ 2,-2,-2,-2],[-2,-2,-2,-4],[-2,-4, 4,-4],[ 4,-4, 4,-6]],
    // F
    [[ 4,-6,-4,-6],[-4,-6,-4, 6],[-4, 6,-2, 6],[-2, 6,-2, 0],[-2, 0, 2, 0],[ 2, 0, 2,-2],[ 2,-2,-2,-2],[-2,-2,-2,-4],[-2,-4, 4,-4],[ 4,-4, 4,-6]],
    // G
    [[ 0, 0, 4, 0],[ 4, 0, 4, 4],[ 4, 4, 2, 6],[ 2, 6,-2, 6],[-2, 6,-4, 4],[-4, 4,-4,-4],[-4,-4,-2,-6],[-2,-6, 4,-6],[ 4,-6, 4,-4],[ 4,-4, 0,-4],[ 0,-4,-2,-2],[-2,-2,-2, 2],[-2, 2, 0, 4],[ 0, 4, 2, 4],[ 2, 4, 2, 2],[ 2, 2, 0, 2],[ 0, 2, 0, 0]],
    // H
    [[-4,-6,-2,-6],[-2,-6,-2,-2],[-2,-2, 2,-2],[ 2,-2, 2,-6],[ 2,-6, 4,-6],[ 4,-6, 4, 6],[ 4, 6, 2, 6],[ 2, 6, 2, 0],[ 2, 0,-2, 0],[-2, 0,-2, 6],[-2, 6,-4, 6],[-4, 6,-4,-6]],
    // I
    [[-1,-6, 1,-6],[ 1,-6, 1, 6],[ 1, 6,-1, 6],[-1, 6,-1,-6]],
    // J
    [[ 1,-6, 3,-6],[ 3,-6, 3, 4],[ 3, 4, 1, 6],[ 1, 6,-1, 6],[-1, 6,-3, 4],[-3, 4,-3, 2],[-3, 2,-1, 2],[-1, 2,-1, 4],[-1, 4, 1, 4],[ 1, 4, 1,-6]],
    // K
    [[-4,-6,-2,-6],[-2,-6,-2,-2],[-2,-2, 2,-6],[ 2,-6, 4,-6],[ 4,-6, 0, 0],[ 0, 0, 4, 6],[ 4, 6, 2, 6],[ 2, 6,-2, 2],[-2, 2,-2, 6],[-2, 6,-4, 6],[-4, 6,-4,-6]],
    // L
    [[-3,-6,-1,-6],[-1,-6,-1, 4],[-1, 4, 3, 4],[ 3, 4, 3, 6],[ 3, 6,-3, 6],[-3, 6,-3,-6]],
    // M
    [[-4,-6, 0,-2],[ 0,-2, 4,-6],[ 4,-6, 4, 6],[ 4, 6, 2, 6],[ 2, 6, 2,-2],[ 2,-2, 0, 0],[ 0, 0,-2,-2],[-2,-2,-2, 6],[-2, 6,-4, 6],[-4, 6,-4,-6]],
    // N
    [[-3,-6,-1,-6],[-1,-6, 1, 0],[ 1, 0, 1,-6],[ 1,-6, 3,-6],[ 3,-6, 3, 6],[ 3, 6, 1, 6],[ 1, 6,-1, 0],[-1, 0,-1, 6],[-1, 6,-3, 6],[-3, 6,-3,-6]],
    // O
    [[-2,-6, 2,-6],[ 2,-6, 4,-4],[ 4,-4, 4, 4],[ 4, 4, 2, 6],[ 2, 6,-2, 6],[-2, 6,-4, 4],[-4, 4,-4,-4],[-4,-4,-2,-6],[-2,-4, 2,-4],[ 2,-4, 2, 4],[ 2, 4,-2, 4],[-2, 4,-2,-4]],
    // P
    [[-4,-6, 2,-6],[ 2,-6, 4,-4],[ 4,-4, 4, 0],[ 4, 0, 2, 2],[ 2, 2,-2, 2],[-2, 2,-2, 6],[-2, 6,-4, 6],[-4, 6,-4,-6],[-2,-4, 2,-4],[ 2,-4, 2, 0],[ 2, 0,-2, 0],[-2, 0,-2,-4]],
    // Q
    [[-1,-6, 1,-6],[ 1,-6, 3,-4],[ 3,-4, 3, 4],[ 3, 4, 5, 6],[ 5, 6,-1, 6],[-1, 6,-3, 4],[-3, 4,-3,-4],[-3,-4,-1,-6],[-1,-4, 1,-4],[ 1,-4, 1, 4],[ 1, 4,-1, 4],[-1, 4,-1,-4]],
    // R
    [[-4,-6, 2,-6],[ 2,-6, 4,-4],[ 4,-4, 4, 0],[ 4, 0, 2, 2],[ 2, 2, 4, 6],[ 4, 6, 2, 6],[ 2, 6, 0, 2],[ 0, 2,-2, 2],[-2, 2,-2, 6],[-2, 6,-4, 6],[-4, 6,-4,-6],[-2,-4, 2,-4],[ 2,-4, 2, 0],[ 2, 0,-2, 0],[-2, 0,-2,-4]],
    // S
    [[ 4,-6,-2,-6],[-2,-6,-4,-4],[-4,-4,-4,-2],[-4,-2,-2, 0],[-2, 0, 2, 0],[ 2, 0, 2, 4],[ 2, 4,-4, 4],[-4, 4,-4, 6],[-4, 6, 2, 6],[ 2, 6, 4, 4],[ 4, 4, 4, 0],[ 4, 0, 2,-2],[ 2,-2,-2,-2],[-2,-2,-2,-4],[-2,-4, 4,-4],[ 4,-4, 4,-6]],
    // T
    [[-3,-6, 3,-6],[ 3,-6, 3,-4],[ 3,-4, 1,-4],[ 1,-4, 1, 6],[ 1, 6,-1, 6],[-1, 6,-1,-4],[-1,-4,-3,-4],[-3,-4,-3,-6]],
    // U
    [[-4,-6,-2,-6],[-2,-6,-2, 4],[-2, 4, 2, 4],[ 2, 4, 2,-6],[ 2,-6, 4,-6],[ 4,-6, 4, 4],[ 4, 4, 2, 6],[ 2, 6,-2, 6],[-2, 6,-4, 4],[-4, 4,-4,-6]],
    // V
    [[-4,-6,-2,-6],[-2,-6, 0, 4],[ 0, 4, 2,-6],[ 2,-6, 4,-6],[ 4,-6, 2, 6],[ 2, 6,-2, 6],[-2, 6,-4,-6]],
    // W
    [[-6,-6,-4,-6],[-4,-6,-2, 4],[-2, 4, 0,-2],[ 0,-2, 2, 4],[ 2, 4, 4,-6],[ 4,-6, 6,-6],[ 6,-6, 4, 6],[ 4, 6, 2, 6],[ 2, 6, 0, 4],[ 0, 4,-2, 6],[-2, 6,-4, 6],[-4, 6,-6,-6]],
    // X
    [[-4,-6,-2,-6],[-2,-6, 0,-2],[ 0,-2, 2,-6],[ 2,-6, 4,-6],[ 4,-6, 2, 0],[ 2, 0, 4, 6],[ 4, 6, 2, 6],[ 2, 6, 0, 2],[ 0, 2,-2, 6],[-2, 6,-4, 6],[-4, 6,-2, 0],[-2, 0,-4,-6]],
    // Y
    [[-4,-6,-2,-6],[-2,-6, 0,-2],[ 0,-2, 2,-6],[ 2,-6, 4,-6],[ 4,-6, 1, 0],[ 1, 0, 1, 6],[ 1, 6,-1, 6],[-1, 6,-1, 0],[-1, 0,-4,-6]],
    // Z
    [[-3,-6, 3,-6],[ 3,-6, 3,-4],[ 3,-4,-1, 4],[-1, 4, 3, 4],[ 3, 4, 3, 6],[ 3, 6,-3, 6],[-3, 6,-3, 4],[-3, 4, 1,-4],[ 1,-4,-3,-4],[-3,-4,-3,-6]]
]

public struct HackDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var text: String = "HACK"

        public init(standardOptions: StandardOptions,
                    text: String = "HACK") {
            self.standardOptions = standardOptions
            self.text = text
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("hack: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) text=\(options.text, privacy: .public)")

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        let text = options.text.uppercased()
        var pixels = Array(repeating: UInt8(0), count: options.standardOptions.width * options.standardOptions.height)
        var palette = Array(repeating: Color(r: 0, g: 0, b: 0), count: 256)

        var charCodes: [Int] = []
        for char in text {
            if let scalar = char.asciiValue {
                if scalar >= 48 && scalar <= 57 {  // 0-9
                    charCodes.append(Int(scalar) - 48)
                } else if scalar >= 65 && scalar <= 90 {  // A-Z
                    charCodes.append(Int(scalar) - 65 + 10)
                }
            }
        }

        guard !charCodes.isEmpty else { return }

        setPalette(num: 1, palette: &palette)

        // Capture immutable copies for the closure
        let charCodesLocal = charCodes
        let width = options.standardOptions.width
        let height = options.standardOptions.height
        let xoff = options.standardOptions.xoff
        let yoff = options.standardOptions.yoff
        let layer = options.standardOptions.layer

        var curPaletteVar = 1

        await loop.run { frameCount in
            // Update palette every 200 frames
            if frameCount % 200 == 0 {
                curPaletteVar += 1
                if curPaletteVar > 3 { curPaletteVar = 1 }
                setPalette(num: curPaletteVar, palette: &palette)
            }

            // Draw border and blur
            drawBoxMod(x1: 0, y1: 0, x2: width - 1, y2: height - 1, color: 0, width: width, height: height, pixels: &pixels)
            blurMod(width: width, height: height, pixels: &pixels)

            // Cycle through characters: 45 frames per character
            let charIndex = (frameCount / 45) % charCodesLocal.count
            let frameInChar = frameCount % 45
            let angle = Int(frameInChar) * 8  // 8 degrees per frame

            // Draw the rotating character
            drawHackChar(charcode: charCodesLocal[charIndex], angle: angle, color: 0xFF, width: width, height: height, pixels: &pixels)

            // Copy pixels to canvas
            for y in 0..<height {
                for x in 0..<width {
                    let idx = y * width + x
                    canvas.setPixel(x: x, y: y, color: palette[Int(pixels[idx])])
                }
            }

            canvas.setOffset(x: xoff, y: yoff, z: layer)
            canvas.send()
        }
    }

    private static func drawLineInPixels(x1: Int, y1: Int, x2: Int, y2: Int, color: UInt8, width: Int, height: Int, pixels: inout [UInt8]) {
        var x = x1
        var y = y1
        let deltax = abs(x2 - x1)
        let deltay = abs(y2 - y1)
        let xinc = x2 >= x1 ? 1 : -1
        let yinc = y2 >= y1 ? 1 : -1
        var xinc1 = 0
        var xinc2 = 0
        var yinc1 = 0
        var yinc2 = 0
        var den = 0
        var num = 0
        var numadd = 0
        var numpixels = 0

        if deltax >= deltay {
            xinc1 = 0
            yinc1 = yinc
            xinc2 = xinc
            yinc2 = 0
            den = deltax
            num = deltax / 2
            numadd = deltay
            numpixels = deltax
        } else {
            xinc1 = xinc
            yinc1 = 0
            xinc2 = 0
            yinc2 = yinc
            den = deltay
            num = deltay / 2
            numadd = deltax
            numpixels = deltay
        }

        for _ in 0...numpixels {
            if x >= 0 && x < width && y >= 0 && y < height {
                pixels[y * width + x] = color
            }
            // Draw thicker line (single adjacent pixel)
            if deltax >= deltay && x >= 0 && x < width && y + 1 >= 0 && y + 1 < height {
                pixels[(y + 1) * width + x] = color
            } else if deltay > deltax && x + 1 >= 0 && x + 1 < width && y >= 0 && y < height {
                pixels[y * width + (x + 1)] = color
            }
            num += numadd
            if num >= den {
                num -= den
                x += xinc1
                y += yinc1
            }
            x += xinc2
            y += yinc2
        }
    }

    private static func blurMod(width: Int, height: Int, pixels: inout [UInt8]) {
        let blurDrop: UInt8 = 32
        let size = width * (height - 1) - 1

        for i in 0..<size {
            let avg = ((Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + width]) + Int(pixels[i + width + 1])) >> 2) & 0xFF
            let dot: UInt8 = avg <= Int(blurDrop) ? 0 : UInt8(avg - Int(blurDrop))
            pixels[i] = dot
        }
    }

    private static func drawBoxMod(x1: Int, y1: Int, x2: Int, y2: Int, color: UInt8, width: Int, height: Int, pixels: inout [UInt8]) {
        for x in x1...x2 {
            if y1 >= 0 && y1 < height && x >= 0 && x < width {
                pixels[y1 * width + x] = color
            }
            if y2 >= 0 && y2 < height && x >= 0 && x < width {
                pixels[y2 * width + x] = color
            }
        }
        for y in y1...y2 {
            if x1 >= 0 && x1 < width && y >= 0 && y < height {
                pixels[y * width + x1] = color
            }
            if x2 >= 0 && x2 < width && y >= 0 && y < height {
                pixels[y * width + x2] = color
            }
        }
    }

    private static func drawHackChar(charcode: Int, angle: Int, color: UInt8, width: Int, height: Int, pixels: inout [UInt8]) {
        let hw = width >> 1
        let hh = height >> 1
        let D = 32
        let Z = 15

        let angleRad = Double(angle) * Double.pi / 180.0
        let cs = cos(angleRad)
        let sn = sin(angleRad)

        guard charcode >= 0 && charcode < hackFont.count else { return }

        for lineSegment in hackFont[charcode] {
            guard lineSegment.count >= 4 else { continue }

            let x1 = lineSegment[0]
            let y1 = lineSegment[1]
            let x2 = lineSegment[2]
            let y2 = lineSegment[3]

            if x1 == 0 && y1 == 0 && x2 == 0 && y2 == 0 { break }

            let sx1 = Double(x1) * cs
            let sy1 = Double(y1)
            let sz1 = Double(x1) * sn + Double(Z)

            let sx2 = Double(x2) * cs
            let sy2 = Double(y2)
            let sz2 = Double(x2) * sn + Double(Z)

            let sz1_safe = sz1 == 0 ? 1.0 : sz1
            let sz2_safe = sz2 == 0 ? 1.0 : sz2

            let px1 = Int(Double(D) * sx1 / sz1_safe)
            let py1 = Int(Double(D) * sy1 / sz1_safe)
            let px2 = Int(Double(D) * sx2 / sz2_safe)
            let py2 = Int(Double(D) * sy2 / sz2_safe)

            drawLineInPixels(x1: px1 + hw, y1: py1 + hh, x2: px2 + hw, y2: py2 + hh, color: color, width: width, height: height, pixels: &pixels)
        }
    }

    private static func setPalette(num: Int, palette: inout [Color]) {
        switch num {
        case 1:  // Nebula
            colorGradient(start: 0, end: 63, r1: 0, g1: 0, b1: 0, r2: 0, g2: 0, b2: 127, palette: &palette)
            colorGradient(start: 64, end: 127, r1: 0, g1: 0, b1: 127, r2: 127, g2: 0, b2: 255, palette: &palette)
            colorGradient(start: 128, end: 191, r1: 127, g1: 0, b1: 255, r2: 255, g2: 0, b2: 0, palette: &palette)
            colorGradient(start: 192, end: 255, r1: 255, g1: 0, b1: 0, r2: 255, g2: 255, b2: 255, palette: &palette)
        case 2:  // Fire
            colorGradient(start: 0, end: 63, r1: 0, g1: 0, b1: 0, r2: 0, g2: 0, b2: 127, palette: &palette)
            colorGradient(start: 64, end: 127, r1: 0, g1: 0, b1: 127, r2: 255, g2: 0, b2: 0, palette: &palette)
            colorGradient(start: 128, end: 191, r1: 255, g1: 0, b1: 0, r2: 255, g2: 255, b2: 0, palette: &palette)
            colorGradient(start: 192, end: 255, r1: 255, g1: 255, b1: 0, r2: 255, g2: 255, b2: 255, palette: &palette)
        case 3:  // Bluegreen
            colorGradient(start: 0, end: 63, r1: 0, g1: 0, b1: 0, r2: 0, g2: 0, b2: 127, palette: &palette)
            colorGradient(start: 64, end: 127, r1: 0, g1: 0, b1: 127, r2: 0, g2: 127, b2: 255, palette: &palette)
            colorGradient(start: 128, end: 191, r1: 0, g1: 127, b1: 255, r2: 0, g2: 255, b2: 0, palette: &palette)
            colorGradient(start: 192, end: 255, r1: 0, g1: 255, b1: 0, r2: 255, g2: 255, b2: 255, palette: &palette)
        default:
            break
        }
    }

    private static func colorGradient(start: Int, end: Int, r1: Int, g1: Int, b1: Int, r2: Int, g2: Int, b2: Int, palette: inout [Color]) {
        let range = end - start
        for i in 0...range {
            let k = Double(i) / Double(range)
            let r = UInt8(Int(Double(r1) + Double(r2 - r1) * k))
            let g = UInt8(Int(Double(g1) + Double(g2 - g1) * k))
            let b = UInt8(Int(Double(b1) + Double(b2 - b1) * k))
            palette[start + i] = Color(r: r, g: g, b: b)
        }
    }
}
