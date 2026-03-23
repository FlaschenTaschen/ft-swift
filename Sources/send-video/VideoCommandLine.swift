// Command-line argument parsing for send-video

import Foundation
import FlaschenTaschenClientKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "VideoCommandLine")

struct VideoArgs {
    var standardOptions: StandardOptions
    var videoFile: String?
    var brightness: UInt8
    var centerImage: Bool
    var timeoutSeconds: Int?
}

nonisolated func parseVideoArguments(_ args: [String]) -> (VideoArgs, [String]) {
    // Pre-filter boolean flags that take no value to prevent StandardOptions from consuming next arg
    var centerImage = false
    let filteredArgs = args.filter { arg in
        if arg == "-c" { centerImage = true; return false }
        return true
    }

    // Use StandardOptions for common flags: -g, -l, -h, -t, -d
    var standardOptions = StandardOptions(args: filteredArgs)

    // Override defaults from StandardOptions to match send-video behavior
    // (SendVideo traditionally defaults layer to 0, not 1)
    if standardOptions.layer == 1 && !filteredArgs.contains("-l") {
        standardOptions.layer = 0
    }

    // Check if -t was explicitly provided to preserve timeout behavior
    let hasExplicitTimeout = args.contains { $0 == "-t" || $0.hasPrefix("-t") }

    // Parse send-video-specific flags from nonStandardArgs
    var brightness: UInt8 = 100
    var videoFile: String? = nil
    var timeoutSeconds: Int? = nil
    var remainingArgs: [String] = []

    var i = 0
    while i < standardOptions.nonStandardArgs.count {
        let arg = standardOptions.nonStandardArgs[i]

        if arg == "-b" {
            i += 1
            if i < standardOptions.nonStandardArgs.count, let b = UInt8(standardOptions.nonStandardArgs[i]) {
                brightness = min(100, b)
                i += 1
            }
        } else if arg == "-t" {
            i += 1
            if i < standardOptions.nonStandardArgs.count, let t = Int(standardOptions.nonStandardArgs[i]) {
                timeoutSeconds = t
                i += 1
            }
        } else if !arg.hasPrefix("-") {
            remainingArgs.append(arg)
            if videoFile == nil {
                videoFile = arg
            }
            i += 1
        } else {
            i += 1
        }
    }

    // Preserve timeout behavior: nil means no timeout (run forever)
    if !hasExplicitTimeout {
        timeoutSeconds = nil
    } else if timeoutSeconds == nil {
        // -t was provided but without valid value, use StandardOptions timeout
        timeoutSeconds = Int(standardOptions.timeout)
    }

    logger.debug("Parsed video args: hostname=\(standardOptions.hostname ?? "nil"), brightness=\(brightness), center=\(centerImage), timeout=\(timeoutSeconds.map(String.init) ?? "nil")")

    return (VideoArgs(standardOptions: standardOptions, videoFile: videoFile, brightness: brightness, centerImage: centerImage, timeoutSeconds: timeoutSeconds), remainingArgs)
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
