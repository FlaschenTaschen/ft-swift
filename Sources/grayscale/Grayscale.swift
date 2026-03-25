// Grayscale - Render a JSON-defined pixel mask as grayscale

import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "grayscale")

@main
struct Grayscale {
    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        if standardOptions.showUsage {
            printUsage()
            exit(EXIT_SUCCESS)
        }

        let args = standardOptions.nonStandardArgs
        var filePath: String? = nil
        var mode: GrayscaleMode = .bounce
        var logoColor: Color? = nil

        var i = 0
        while i < args.count && args[i].hasPrefix("-") {
            let arg = args[i]
            let option = arg.dropFirst()

            switch option {
            case "f":
                i += 1
                if i < args.count {
                    filePath = args[i]
                }
            case "m":
                i += 1
                if i < args.count {
                    switch args[i].lowercased() {
                    case "bounce":
                        mode = .bounce
                    case "center":
                        mode = .center
                    case "left":
                        mode = .left
                    case "right":
                        mode = .right
                    case "top":
                        mode = .top
                    case "bottom":
                        mode = .bottom
                    default:
                        print("Error: Unknown mode '\(args[i])'. Valid modes: bounce, center, left, right, top, bottom")
                        exit(EXIT_FAILURE)
                    }
                }
            case "c":
                i += 1
                if i < args.count, let color = parseHexColor(args[i]) {
                    logoColor = color
                }
            default:
                break
            }
            i += 1
        }

        guard let filePath = filePath else {
            print("Error: -f <filepath> is required")
            printUsage()
            exit(EXIT_FAILURE)
        }

        // Load and parse JSON file
        let mask: [[UInt8]]
        let imageWidth: Int
        let imageHeight: Int

        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let hexArray = try JSONDecoder().decode([[String]].self, from: data)

            guard !hexArray.isEmpty else {
                print("Error: JSON array is empty")
                exit(EXIT_FAILURE)
            }

            imageHeight = hexArray.count
            imageWidth = hexArray.map { $0.count }.max() ?? 0

            guard imageWidth > 0 else {
                print("Error: Invalid JSON structure")
                exit(EXIT_FAILURE)
            }

            // Convert hex strings to grayscale
            var convertedMask: [[UInt8]] = []
            for row in hexArray {
                var grayRow: [UInt8] = []
                for hexString in row {
                    guard let color = parseHexColor(hexString) else {
                        throw NSError(domain: "InvalidHexColor", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Invalid hex color: \(hexString)"])
                    }
                    // Luminance formula: 0.299*R + 0.587*G + 0.114*B
                    let gray = UInt8(0.299 * Float(color.r) + 0.587 * Float(color.g) + 0.114 * Float(color.b))
                    grayRow.append(gray)
                }
                convertedMask.append(grayRow)
            }
            mask = convertedMask
        } catch {
            print("Error: Failed to load or parse JSON file: \(error.localizedDescription)")
            exit(EXIT_FAILURE)
        }

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        let options = GrayscaleDemo.Options(
            standardOptions: standardOptions,
            logoColor: logoColor,
            mode: mode,
            mask: mask,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )
        await GrayscaleDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Grayscale - Render a JSON-defined pixel mask as grayscale")
        print("Usage: grayscale -f <filepath> [options]")
        print("Options:")
        print("  -f <filepath>   : JSON file with [[\"RRGGBB\", ...], ...] structure (required)")
        print("  -m <mode>       : Positioning mode: bounce (default), center, left, right, top, bottom")
        print("  -c <RRGGBB>     : Fixed color (default: rainbow palette)")
        StandardOptions.printStandardOptions()
    }
}
