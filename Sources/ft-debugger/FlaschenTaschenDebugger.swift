import Foundation
import FlaschenTaschenClientKit
import FlaschenTaschenDemoKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "FlaschenTaschenDebugger")

@main
struct FlaschenTaschenDebugger {
    enum Mode: Sendable {
        case edges
        case fill

        init(modeString: String? = nil) {
            switch modeString {
            case "edges":
                self = .edges
            case "fill":
                self = .fill
            default:
                self = .edges
            }
        }
    }

    struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var mode: Mode
        public var patternName: String?

        public init(standardOptions: StandardOptions, mode: Mode, patternName: String? = nil) {
            self.standardOptions = standardOptions
            self.mode = mode
            self.patternName = patternName
        }
    }

    static func main() async {
        let standardOptions = StandardOptions(args: CommandLine.arguments)

        let args = standardOptions.nonStandardArgs

        let socket = openFlaschenTaschenSocket(hostname: standardOptions.hostname)
        let canvas = UDPFlaschenTaschen(fileDescriptor: socket, width: standardOptions.width, height: standardOptions.height)

        var patternName: String? = nil
        var modeString: String? = nil

        var i = 0
        while i < args.count {
            let arg = args[i]
            guard arg.hasPrefix("-") else { i += 1; continue }

            let optChar = String(arg.dropFirst())
            switch optChar {
            case "p":
                i += 1
                if i < args.count {
                    patternName = args[i]
                }
            case "m":
                i += 1
                if i < args.count {
                    modeString = args[i]
                }
            default:
                break
            }
            i += 1
        }

        let mode = Mode(modeString: modeString)
        let options = Options(standardOptions: standardOptions, mode: mode, patternName: patternName)

        await run(options: options, canvas: canvas)
    }

    private static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        logger.info("ft-debugger: width=\(options.standardOptions.width, privacy: .public), height=\(options.standardOptions.height, privacy: .public), xoff=\(options.standardOptions.xoff, privacy: .public), yoff=\(options.standardOptions.yoff, privacy: .public), timeout=\(options.standardOptions.timeout, privacy: .public), patterName=\(options.patternName ?? "random")")

        canvas.clear()

        switch options.mode {
        case .edges:
            await drawEdges(options: options, canvas: canvas)
        case .fill:
            await drawFill(options: options, canvas: canvas)
        }
    }

    private static func drawEdges(options: Options, canvas: UDPFlaschenTaschen) async {
        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        var colorIndex = 0

        var palette = [Color](repeating: Color(), count: 256)
        let paletteType = PaletteType.paletteType(for: options.patternName)
        logger.log("Apply palette: \(String(describing: paletteType))")
        paletteType.apply(to: &palette)

        await loop.run { _ in
            colorIndex += 1
            if colorIndex == palette.count {
                colorIndex = 0
            }

            if colorIndex % 30 == 0 {
                logger.log("colorIndex = \(colorIndex)")
            }

            // draw a line around the edge of the canvas
            let color = palette[colorIndex]

            let minX = 0
            let minY = 0
            let maxX = minX + options.standardOptions.width - 1
            let maxY = minY + options.standardOptions.height - 1

            // draw top and bottom edges
            for i in minX...maxX {
                // top
                canvas.setPixel(x: i, y: 0, color: color)
                // bottom
                canvas.setPixel(x: i, y: maxY, color: color)
            }

            // draw left and right edges
            for i in (minY - 1)...(maxY - 1) {
                // left
                canvas.setPixel(x: 0, y: i, color: color)
                // right
                canvas.setPixel(x: maxX, y: i, color: color)
            }

            // Set offset and layer
            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)

            // Send the framebuffer
            canvas.send()
        }}

    private static func drawFill(options: Options, canvas: UDPFlaschenTaschen) async {
        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)
        var colorIndex = 0

        var palette = [Color](repeating: Color(), count: 256)
        let paletteType = PaletteType.paletteType(for: options.patternName)
        logger.log("Apply palette: \(String(describing: paletteType))")
        paletteType.apply(to: &palette)

        await loop.run { _ in
            colorIndex += 1
            if colorIndex == palette.count {
                colorIndex = 0
            }

            if colorIndex % 30 == 0 {
                logger.log("colorIndex = \(colorIndex)")
            }

            // draw a line around the edge of the canvas
            let color = palette[colorIndex]

            let minX = 0
            let minY = 0
            let maxX = minX + options.standardOptions.width - 1
            let maxY = minY + options.standardOptions.height - 1

            for x in minX...maxX {
                for y in minY...maxY {
                    canvas.setPixel(x: x, y: y, color: color)
                }
            }

            // Set offset and layer
            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)

            // Send the framebuffer
            canvas.send()
        }
    }
}
