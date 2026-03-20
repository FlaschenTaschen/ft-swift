// Fractal - Fractal patterns
// Ported from fractal.cc by Carl Gorringe

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "fractal")

private let POINT_OR = -0.577816
private let POINT_OI = -0.631121

private class FractalState {
    var fractal1: [UInt8]  // Current computation buffer
    var fractal2: [UInt8]  // Display buffer
    var dr: Double = 0
    var di: Double = 0
    var pr: Double = 0
    var pi: Double = 0
    var sr: Double = 0
    var si: Double = 0
    var offset: Int = 0
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        let bufferSize = width * height * 4
        self.fractal1 = Array(repeating: 0, count: bufferSize)
        self.fractal2 = Array(repeating: 0, count: bufferSize)
    }

    func startComputation(sr: Double, si: Double, er: Double, ei: Double) {
        dr = (er - sr) / Double(width * 2)
        di = (ei - si) / Double(height * 2)
        pr = sr
        pi = si
        self.sr = sr
        self.si = si
        offset = 0
    }

    func computeLines(lineCount: Int) {
        for _ in 0..<lineCount {
            if offset >= width * height * 4 { return }

            pr = sr
            for _ in 0..<(width * 2) {
                var c: UInt8 = 0
                var vr = pr
                var vi = pi

                while (vr*vr + vi*vi < 4.0) && c < 255 {
                    let nvr = vr*vr - vi*vi + pr
                    let nvi = 2.0 * vi * vr + pi
                    vi = nvi
                    vr = nvr
                    c += 1
                }

                fractal1[offset] = c
                offset += 1
                if offset >= width * height * 4 { return }
                pr += dr
            }
            pi += di
        }
    }

    func swapBuffers() {
        let tmp = fractal1
        fractal1 = fractal2
        fractal2 = tmp
    }

    func zoomFractal(z: Double, into pixels: inout [UInt8]) {
        let width16 = width << 17
        let height16 = height << 17
        let z256 = 256.0 * (1.0 + z)

        let width_fix = Int((Double(width16) / z256)) << 8
        let height_fix = Int((Double(height16) / z256)) << 8
        let startx = (width16 - width_fix) >> 1
        let starty = (height16 - height_fix) >> 1
        let deltax = width_fix / width
        let deltay = height_fix / height

        var offset = 0
        var py = starty

        for _ in 0..<height {
            var px = startx
            for _ in 0..<width {
                let py_idx = (py >> 16) * (width * 2)
                let py_frac = (py >> 8) & 0xff
                let px_idx = px >> 16
                let px_frac = (px >> 8) & 0xff

                let w1 = (0x100 - py_frac) * (0x100 - px_frac)
                let w2 = (0x100 - py_frac) * px_frac
                let w3 = py_frac * (0x100 - px_frac)
                let w4 = py_frac * px_frac

                let v1 = Int(fractal2[py_idx + px_idx]) * w1
                let v2 = Int(fractal2[py_idx + px_idx + 1]) * w2
                let v3 = Int(fractal2[py_idx + (width * 2) + px_idx]) * w3
                let v4 = Int(fractal2[py_idx + (width * 2) + px_idx + 1]) * w4

                pixels[offset] = UInt8((v1 + v2 + v3 + v4) >> 16)

                px += deltax
                offset += 1
            }
            py += deltay
        }
    }
}

public struct FractalDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions

        public init(standardOptions: StandardOptions) {
            self.standardOptions = standardOptions
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("fractal: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public)")

        let state = FractalState(width: options.standardOptions.width, height: options.standardOptions.height)
        var palette = Array(repeating: Color(r: 0, g: 0, b: 0), count: 256)
        var pixels = Array(repeating: UInt8(0), count: options.standardOptions.width * options.standardOptions.height)

        var zx = 4.0
        var zy = 4.0
        var zoomIn = true
        var frameCount = 0
        var k = 0
        var computeStep = 0
        let computeStepsPerZoom = max(1, options.standardOptions.height)
        var needsNewZoom = true

        // Initial fractal computation
        state.startComputation(sr: POINT_OR - zx, si: POINT_OI - zy, er: POINT_OR + zx, ei: POINT_OI + zy)
        for _ in 0..<100 {
            state.computeLines(lineCount: 2)
        }
        state.swapBuffers()

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        await loop.run { _ in
            if needsNewZoom {
                if zoomIn {
                    zx *= 0.5
                    zy *= 0.5
                } else {
                    zx *= 2.0
                    zy *= 2.0
                }
                state.startComputation(sr: POINT_OR - zx, si: POINT_OI - zy, er: POINT_OR + zx, ei: POINT_OI + zy)
                computeStep = 0
                needsNewZoom = false
            }

            state.computeLines(lineCount: 2)
            computeStep += 1

            let z = Double(computeStep) / Double(computeStepsPerZoom)
            let zoomFactor = zoomIn ? z : (1.0 - z)
            state.zoomFractal(z: zoomFactor, into: &pixels)

            updatePalette(frame: frameCount, palette: &palette)
            for y in 0..<options.standardOptions.height {
                for x in 0..<options.standardOptions.width {
                    let idx = y * options.standardOptions.width + x
                    canvas.setPixel(x: x, y: y, color: palette[Int(pixels[idx])])
                }
            }

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()
            frameCount += 1

            if computeStep >= computeStepsPerZoom {
                state.swapBuffers()
                k += 1
                needsNewZoom = true

                if k % 38 == 0 {
                    zoomIn = !zoomIn
                }
            }
        }
    }

    private static func updatePalette(frame: Int, palette: inout [Color]) {
        let t = Double(frame)
        for i in 0..<256 {
            let fi = Double(i)
            let angle1 = fi * .pi / 128.0 + t * 0.0212
            let angle2 = fi * .pi / 64.0 + t * 0.0136
            let c1 = 128.0 - 127.0 * cos(angle1)
            let c2 = 128.0 - 127.0 * cos(angle2)
            let colr1 = UInt8(Int(c1) & 0xFF)
            let colr2 = UInt8(Int(c2) & 0xFF)
            palette[i] = Color(r: colr2, g: 0, b: colr1)
        }
    }
}
