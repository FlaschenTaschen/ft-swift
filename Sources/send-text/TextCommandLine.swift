// Command-line argument parsing for send-text

import Foundation
import FlaschenTaschenClientKit

struct TextArgs {
    var standardOptions: StandardOptions
    var fontPath: String?
    var textInput: String?
    var scrollDelayMs: Int
    var letterSpacing: Int
    var textColor: Color
    var backgroundColor: Color
    var outlineColor: Color?
    var verticalMode: Bool
    var runOnce: Bool
    var text: String = ""
}

// Renamed for clarity - returns TextArgs and remaining text arguments
nonisolated func parseTextArguments(_ args: [String]) -> (TextArgs, [String]) {
    // Pre-filter boolean flags that take no value to prevent StandardOptions from consuming next arg
    var verticalMode = false
    var runOnce = false
    let filteredArgs = args.filter { arg in
        if arg == "-v" { verticalMode = true; return false }
        if arg == "-O" { runOnce = true; return false }
        return true
    }

    // Use StandardOptions for common flags: -g, -l, -h, -t, -d
    let standardOptions = StandardOptions(args: filteredArgs)

    // Parse send-text-specific flags from nonStandardArgs
    var fontPath: String? = nil
    var textInput: String? = nil
    var scrollDelayMs = 50
    var letterSpacing = 0
    var textColor = Color(r: 255, g: 255, b: 255)
    var backgroundColor = Color(r: 0, g: 0, b: 0)
    var outlineColor: Color? = nil
    var textArgs: [String] = []

    var i = 0
    while i < standardOptions.nonStandardArgs.count {
        let arg = standardOptions.nonStandardArgs[i]

        if arg == "-f" {
            i += 1
            if i < standardOptions.nonStandardArgs.count {
                fontPath = standardOptions.nonStandardArgs[i]
                i += 1
            }
        } else if arg == "-i" {
            i += 1
            if i < standardOptions.nonStandardArgs.count {
                textInput = standardOptions.nonStandardArgs[i]
                i += 1
            }
        } else if arg == "-s" {
            i += 1
            if i < standardOptions.nonStandardArgs.count, let ms = Int(standardOptions.nonStandardArgs[i]) {
                var delayMs = ms
                if delayMs < 0 {
                    delayMs = -delayMs
                }
                if delayMs > 0 && delayMs < 10 {
                    delayMs = 10
                }
                scrollDelayMs = delayMs
                i += 1
            } else {
                scrollDelayMs = 50
            }
        } else if arg == "-S" {
            i += 1
            if i < standardOptions.nonStandardArgs.count, let ls = Int(standardOptions.nonStandardArgs[i]) {
                letterSpacing = ls
                i += 1
            }
        } else if arg == "-c" {
            i += 1
            if i < standardOptions.nonStandardArgs.count {
                _ = parseColor(standardOptions.nonStandardArgs[i], into: &textColor)
                i += 1
            }
        } else if arg == "-b" {
            i += 1
            if i < standardOptions.nonStandardArgs.count {
                _ = parseColor(standardOptions.nonStandardArgs[i], into: &backgroundColor)
                i += 1
            }
        } else if arg == "-o" {
            i += 1
            if i < standardOptions.nonStandardArgs.count {
                var outlineCol = Color()
                if parseColor(standardOptions.nonStandardArgs[i], into: &outlineCol) {
                    outlineColor = outlineCol
                }
                i += 1
            }
        } else if !arg.hasPrefix("-") {
            textArgs.append(arg)
            i += 1
        } else {
            i += 1
        }
    }

    let textArgsResult = TextArgs(
        standardOptions: standardOptions,
        fontPath: fontPath,
        textInput: textInput,
        scrollDelayMs: scrollDelayMs,
        letterSpacing: letterSpacing,
        textColor: textColor,
        backgroundColor: backgroundColor,
        outlineColor: outlineColor,
        verticalMode: verticalMode,
        runOnce: runOnce
    )
    return (textArgsResult, textArgs)
}

private nonisolated func parseGeometry(_ spec: String, into geo: inout (width: Int, height: Int, offsetX: Int, offsetY: Int, layer: Int)) -> Bool {
    // Format: WxH[+X+Y[+Z]]
    let parts = spec.split(separator: "x", maxSplits: 1)
    guard parts.count >= 1, let width = Int(parts[0]) else {
        return false
    }

    var rest = String(parts.count > 1 ? parts[1] : "")
    var height = -1
    var offsetX = 0
    var offsetY = 0
    var layer = 1

    // Extract height and offsets
    if let plusIndex = rest.firstIndex(of: "+") {
        let heightStr = String(rest[..<plusIndex])
        height = Int(heightStr) ?? -1
        rest = String(rest[rest.index(after: plusIndex)...])

        // Parse offsets: +X+Y[+Z]
        let offsetParts = rest.split(separator: "+")
        if offsetParts.count > 0, let x = Int(offsetParts[0]) {
            offsetX = x
        }
        if offsetParts.count > 1, let y = Int(offsetParts[1]) {
            offsetY = y
        }
        if offsetParts.count > 2, let z = Int(offsetParts[2]), z >= 0 && z < 16 {
            layer = z
        }
    } else {
        height = Int(rest) ?? -1
    }

    geo = (width: width, height: height, offsetX: offsetX, offsetY: offsetY, layer: layer)
    return width > 0
}

private nonisolated func parseColor(_ hex: String, into color: inout Color) -> Bool {
    guard hex.count == 6 else {
        return false
    }

    if let value = UInt32(hex, radix: 16) {
        color.r = UInt8((value >> 16) & 0xFF)
        color.g = UInt8((value >> 8) & 0xFF)
        color.b = UInt8(value & 0xFF)
        return true
    }
    return false
}
