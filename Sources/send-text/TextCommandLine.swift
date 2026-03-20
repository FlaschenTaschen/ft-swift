// Command-line argument parsing for send-text

import Foundation
import FlaschenTaschenClientKit

struct TextCommandLineArgs {
    var geometry: (width: Int, height: Int, offsetX: Int, offsetY: Int, layer: Int)
    var hostname: String?
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

nonisolated func parseTextArguments(_ args: [String]) -> (TextCommandLineArgs, [String]) {
    var result = TextCommandLineArgs(
        geometry: (width: 45, height: -1, offsetX: 0, offsetY: 0, layer: 1),
        hostname: nil,
        fontPath: nil,
        textInput: nil,
        scrollDelayMs: 50,
        letterSpacing: 0,
        textColor: Color(r: 255, g: 255, b: 255),
        backgroundColor: Color(r: 0, g: 0, b: 0),
        outlineColor: nil,
        verticalMode: false,
        runOnce: false
    )

    var i = 1  // Skip program name
    var remainingArgs: [String] = []

    while i < args.count {
        let arg = args[i]

        if arg.hasPrefix("-") && arg != "-" {
            let flag = String(arg.dropFirst())

            switch flag {
            case let f where f.hasPrefix("g"):
                let value = String(flag.dropFirst())
                if parseGeometry(value, into: &result.geometry) {
                    i += 1
                } else {
                    i += 1
                    if i < args.count {
                        _ = parseGeometry(args[i], into: &result.geometry)
                        i += 1
                    }
                }

            case let f where f.hasPrefix("h"):
                let value = String(flag.dropFirst())
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        result.hostname = args[i]
                        i += 1
                    }
                } else {
                    result.hostname = value
                    i += 1
                }

            case let f where f.hasPrefix("f"):
                let value = String(flag.dropFirst())
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        result.fontPath = args[i]
                        i += 1
                    }
                } else {
                    result.fontPath = value
                    i += 1
                }

            case let f where f.hasPrefix("i"):
                let value = String(flag.dropFirst())
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        result.textInput = args[i]
                        i += 1
                    }
                } else {
                    result.textInput = value
                    i += 1
                }

            case let f where f.hasPrefix("s"):
                let value = String(flag.dropFirst())
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        result.scrollDelayMs = Int(args[i]) ?? 50
                        i += 1
                    }
                } else {
                    var delayMs = Int(value) ?? 50
                    if delayMs < 0 {
                        delayMs = -delayMs
                    }
                    if delayMs > 0 && delayMs < 10 {
                        delayMs = 10
                    }
                    result.scrollDelayMs = delayMs
                    i += 1
                }

            case let f where f.hasPrefix("S"):
                let value = String(flag.dropFirst())
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        result.letterSpacing = Int(args[i]) ?? 0
                        i += 1
                    }
                } else {
                    result.letterSpacing = Int(value) ?? 0
                    i += 1
                }

            case let f where f.hasPrefix("c"):
                let value = String(flag.dropFirst())
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        _ = parseColor(args[i], into: &result.textColor)
                        i += 1
                    }
                } else {
                    _ = parseColor(value, into: &result.textColor)
                    i += 1
                }

            case let f where f.hasPrefix("b"):
                let value = String(flag.dropFirst())
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        _ = parseColor(args[i], into: &result.backgroundColor)
                        i += 1
                    }
                } else {
                    _ = parseColor(value, into: &result.backgroundColor)
                    i += 1
                }

            case let f where f.hasPrefix("o"):
                let value = String(flag.dropFirst())
                var outlineColor = Color()
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        if parseColor(args[i], into: &outlineColor) {
                            result.outlineColor = outlineColor
                        }
                        i += 1
                    }
                } else {
                    if parseColor(value, into: &outlineColor) {
                        result.outlineColor = outlineColor
                    }
                    i += 1
                }

            case let f where f.hasPrefix("l"):
                let value = String(flag.dropFirst())
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        if let layer = Int(args[i]), layer >= 0 && layer < 16 {
                            result.geometry.layer = layer
                        }
                        i += 1
                    }
                } else {
                    if let layer = Int(value), layer >= 0 && layer < 16 {
                        result.geometry.layer = layer
                    }
                    i += 1
                }

            case "O":
                result.runOnce = true
                i += 1

            case "v":
                result.verticalMode = true
                i += 1

            default:
                i += 1
            }
        } else {
            remainingArgs.append(arg)
            i += 1
        }
    }

    return (result, remainingArgs)
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
