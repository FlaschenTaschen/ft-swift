// Shared utilities for Flaschen Taschen demos

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "StandardOptions")

/// Generate a random integer in the range [min, max] inclusive
public nonisolated func randomInt(min: Int, max: Int) -> Int {
    return Int.random(in: min...max)
}

/// Parse geometry string in format "WxH+X+Y" or "WxH"
public nonisolated func parseGeometry(_ geometry: String) -> (width: Int, height: Int, xoff: Int, yoff: Int)? {
    let parts = geometry.split(separator: "x", maxSplits: 1, omittingEmptySubsequences: true)
    guard parts.count >= 2, let width = Int(parts[0]) else { return nil }

    let heightAndOffset = String(parts[1])
    let offsetParts = heightAndOffset.split(separator: "+", omittingEmptySubsequences: true)

    guard let height = Int(offsetParts[0]) else { return nil }

    let xoff = offsetParts.count > 1 ? Int(offsetParts[1]) ?? 0 : 0
    let yoff = offsetParts.count > 2 ? Int(offsetParts[2]) ?? 0 : 0

    return (width, height, xoff, yoff)
}

/// Parse hex color string in format "RRGGBB"
public nonisolated func parseHexColor(_ hex: String) -> Color? {
    let cleanHex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
    guard cleanHex.count == 6 else { return nil }

    let scanner = Scanner(string: cleanHex)
    var value: UInt32 = 0
    guard scanner.scanHexInt32(&value) else { return nil }

    let r = UInt8((value >> 16) & 0xFF)
    let g = UInt8((value >> 8) & 0xFF)
    let b = UInt8(value & 0xFF)

    return Color(r: r, g: g, b: b)
}

/// Create a sprite from a text pattern (# = colored pixel, space = black)
public nonisolated func createSpriteFromPattern(_ fileDescriptor: Int32, pattern: [String], color: Color) -> UDPFlaschenTaschen {
    let width = pattern.map { $0.count }.max() ?? 0
    let height = pattern.count

    let canvas = UDPFlaschenTaschen(fileDescriptor: fileDescriptor, width: width + 2, height: height + 2)
    canvas.clear()

    for (row, line) in pattern.enumerated() {
        for (col, char) in line.enumerated() {
            if char != " " {
                canvas.setPixel(x: col + 1, y: row + 1, color: color)
            }
        }
    }

    return canvas
}

/// Log command-line arguments for easy copy/paste to original demos
public nonisolated func logArguments(_ logger: Logger, category: String) {
    let args = ArgumentPreprocessor.preprocess(args: CommandLine.arguments)
    let argString = args.count > 1 ? args.dropFirst().joined(separator: " ") : "(none)"
    logger.info("Arguments: \(argString, privacy: .public)")
}

// MARK: - Random Utilities

/// Generate a random color with full RGB range
public nonisolated func randomColor() -> Color {
    return Color(
        r: UInt8.random(in: 0...255),
        g: UInt8.random(in: 0...255),
        b: UInt8.random(in: 0...255)
    )
}

/// Generate a random float in the given range
public nonisolated func randomFloat(min: Float, max: Float) -> Float {
    return Float.random(in: min...max)
}
