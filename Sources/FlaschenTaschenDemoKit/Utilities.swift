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

// MARK: - Standard Options and Argument Parsing

/// Standard options common to most demos - immutable value type, safe for concurrent use
public nonisolated struct StandardOptions: Sendable {
    public var hostname: String?
    public var layer: Int = 1
    public var timeout: Double = 60 * 60 * 24.0  // 24 hours
    public var width: Int = 45
    public var height: Int = 35
    public var xoff: Int = 0
    public var yoff: Int = 0
    public var delay: Int = 50
    public var showUsage: Bool = false

    public var nonStandardArgs: [String] = []

    @available(*, deprecated, message: "use init(args:) instead")
    public nonisolated init() {}

    public nonisolated init(args: [String]) {
        let args = ArgumentPreprocessor.preprocess(args: args)

        logger.info("Arguments: \(args, privacy: .public)")

        // skip the first value (process name)
        var i = 1
        while i < args.count && args[i].hasPrefix("-") {
            let arg = args[i]

            if "-?" == arg {
                showUsage = true
                i += 1
                continue
            }

            guard arg.hasPrefix("-") else {
                i += 1
                continue
            }

            let option = arg.dropFirst()

            switch option {
            case "g":
                i += 1
                if i < args.count, let geom = parseGeometry(args[i]) {
                    width = geom.width
                    height = geom.height
                    xoff = geom.xoff
                    yoff = geom.yoff
                }
            case "l":
                i += 1
                if i < args.count, let layerArg = Int(args[i]), layer >= 0 && layer < 16 {
                    layer = layerArg
                }
            case "t":
                i += 1
                if i < args.count, let timeoutArg = Double(args[i]) {
                    timeout = timeoutArg
                }
            case "h":
                i += 1
                if i < args.count {
                    hostname = args[i]
                }
            case "d":
                i += 1
                if i < args.count, let delayArg = Int(args[i]) {
                    delay = max(1, delayArg)
                }
            default:
                nonStandardArgs.append(arg)
                i += 1
                if i < args.count {
                    nonStandardArgs.append(args[i])
                }
            }
            i += 1
        }

        // remaining args
        while i < args.count {
            nonStandardArgs.append(args[i])
            i += 1
        }

        // Use FT_DISPLAY if not yet defined
        if hostname == nil {
            hostname = ProcessInfo.processInfo.environment["FT_DISPLAY"] ?? "localhost"
        }
    }

    public static func printStandardOptions() {
        print("  -g <W>x<H>[+<X>+<Y>] : Output geometry. (default 45x35+0+0)")
        print("  -l <layer>     : Layer 0-15. (default 1)")
        print("  -t <timeout>   : Timeout in seconds. (default 86400)")
        print("  -h <host>      : Flaschen-Taschen display hostname. (FT_DISPLAY)")
        print("  -d <delay>     : Frame delay in milliseconds. (default 50)")
    }
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
