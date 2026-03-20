// Image processing algorithms for pixel buffers
// Includes blur effects and pixel decay

import Foundation

// MARK: - Blur Algorithms

/// Apply 3x3 blur filter with pixel decay to byte buffer
/// Used for general blur effects
public nonisolated func blur3(width: Int, height: Int, pixels: inout [UInt8]) {
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
        // Blur right border pixel
        let dot1 = Int(pixels[i])
        let dot2 = Int(pixels[i + width])
        var dot = UInt8((dot1 + dot2) >> 2)
        dot = dot <= 8 ? 0 : dot - 8
        pixels[i] = dot
        i += 1
    }

    // Blur bottom border pixels
    for _ in 0..<(width - 1) {
        let dot1 = Int(pixels[i])
        let dot2 = Int(pixels[i + 1])
        var dot = UInt8((dot1 + dot2) >> 2)
        dot = dot <= 8 ? 0 : dot - 8
        pixels[i] = dot
        i += 1
    }
    // Last lower-right corner pixel
    pixels[i] = 0
}

/// Apply fire-style blur with directional flow
/// - Parameters:
///   - orient: 0 = upwards flow, 1 = leftwards flow
public nonisolated func blurFire(width: Int, height: Int, orient: Int, pixels: inout [UInt8]) {
    let step: UInt8 = 4

    if orient == 0 {
        // Flame upwards
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
        // Flame leftwards
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

// MARK: - Pixel Decay

/// Decay all pixels by a fixed amount (for motion blur effects)
public nonisolated func decayPixels(pixels: inout [UInt8], decayAmount: UInt8) {
    for i in 0..<pixels.count {
        let current = Int(pixels[i])
        let decayed = max(0, current - Int(decayAmount))
        pixels[i] = UInt8(decayed)
    }
}

/// Decay pixels with a threshold (pixels below threshold become 0)
public nonisolated func decayPixelsWithThreshold(pixels: inout [UInt8], decayAmount: UInt8, threshold: UInt8) {
    for i in 0..<pixels.count {
        let current = pixels[i]
        if current > threshold {
            let decayed = current - decayAmount
            pixels[i] = decayed
        } else {
            pixels[i] = 0
        }
    }
}
