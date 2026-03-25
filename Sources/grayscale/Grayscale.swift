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
        var filePaths: [String] = []
        var mode: GrayscaleMode = .bounce
        var orientation: GrayscaleOrientation = .horizontal
        var logoColor: Color? = nil

        var i = 0
        while i < args.count && args[i].hasPrefix("-") {
            let arg = args[i]
            let option = arg.dropFirst()

            switch option {
            case "f":
                i += 1
                if i < args.count {
                    filePaths = args[i].split(separator: ",").map(String.init)
                }
            case "o":
                i += 1
                if i < args.count {
                    switch args[i].lowercased() {
                    case "horizontal":
                        orientation = .horizontal
                    case "vertical":
                        orientation = .vertical
                    default:
                        print("Error: Unknown orientation '\(args[i])'. Valid orientations: horizontal, vertical")
                        exit(EXIT_FAILURE)
                    }
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

        guard !filePaths.isEmpty else {
            print("Error: -f <filepath[,filepath...]> is required")
            printUsage()
            exit(EXIT_FAILURE)
        }

        // Load and parse JSON files
        var masks: [MaskData] = []

        do {
            for filePath in filePaths {
                let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
                let hexArray = try JSONDecoder().decode([[String]].self, from: data)

                guard !hexArray.isEmpty else {
                    print("Error: JSON array is empty in \(filePath)")
                    exit(EXIT_FAILURE)
                }

                let height = hexArray.count
                let width = hexArray.map { $0.count }.max() ?? 0

                guard width > 0 else {
                    print("Error: Invalid JSON structure in \(filePath)")
                    exit(EXIT_FAILURE)
                }

                // Convert hex strings to grayscale
                var pixels: [[UInt8]] = []
                var minGray = UInt8.max
                var maxGray = UInt8.min
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
                        minGray = min(minGray, gray)
                        maxGray = max(maxGray, gray)
                    }
                    pixels.append(grayRow)
                }
                masks.append(MaskData(pixels: pixels, width: width, height: height))
            }
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
            masks: masks,
            orientation: orientation
        )
        await GrayscaleDemo.run(options: options, canvas: canvas)
    }

    static func printUsage() {
        print("Grayscale - Render a JSON-defined pixel mask as grayscale")
        print("Usage: grayscale -f <filepath[,...]> [options]")
        print("Options:")
        print("  -f <filepath[,...]> : One or more JSON files with [[\"RRGGBB\", ...], ...] (required)")
        print("  -o <orientation>    : horizontal (default) or vertical")
        print("  -m <mode>           : Positioning mode: bounce (default), center, left, right, top, bottom")
        print("  -c <RRGGBB>         : Fixed color (default: rainbow palette)")
        StandardOptions.printStandardOptions()
    }
}
