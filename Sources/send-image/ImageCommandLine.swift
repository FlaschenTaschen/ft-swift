// Command-line argument parsing for send-image

import Foundation
import FlaschenTaschenClientKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "ImageCommandLine")

struct ImageCommandLineArgs {
    var geometry: (width: Int, height: Int, offsetX: Int, offsetY: Int, layer: Int)
    var hostname: String?
    var imageFile: String?
    var scrollDelayMs: Int
    var brightness: UInt8
    var centerImage: Bool
    var timeoutSeconds: Int?
    var clearOnly: Bool
}

nonisolated func parseImageArguments(_ args: [String]) -> (ImageCommandLineArgs, [String]) {
    var result = ImageCommandLineArgs(
        geometry: (width: 45, height: 35, offsetX: 0, offsetY: 0, layer: 0),
        hostname: nil,
        imageFile: nil,
        scrollDelayMs: 0,
        brightness: 100,
        centerImage: false,
        timeoutSeconds: nil,
        clearOnly: false
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

            case let f where f.hasPrefix("b"):
                let value = String(flag.dropFirst())
                let brightnessStr: String
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        brightnessStr = args[i]
                        i += 1
                    } else {
                        i += 1
                        continue
                    }
                } else {
                    brightnessStr = value
                    i += 1
                }

                if let brightness = UInt8(brightnessStr) {
                    result.brightness = min(100, brightness)
                }

            case let f where f.hasPrefix("t"):
                let value = String(flag.dropFirst())
                let timeoutStr: String
                if value.isEmpty {
                    i += 1
                    if i < args.count {
                        timeoutStr = args[i]
                        i += 1
                    } else {
                        i += 1
                        continue
                    }
                } else {
                    timeoutStr = value
                    i += 1
                }

                if let timeout = Int(timeoutStr) {
                    result.timeoutSeconds = timeout
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

            case "c":
                result.centerImage = true
                i += 1

            case "C":
                result.clearOnly = true
                i += 1

            default:
                i += 1
            }
        } else {
            remainingArgs.append(arg)
            i += 1
        }
    }

    logger.debug("Parsed geometry: width=\(result.geometry.width), height=\(result.geometry.height), offsetX=\(result.geometry.offsetX), offsetY=\(result.geometry.offsetY), layer=\(result.geometry.layer)")

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
    var layer = 0

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
