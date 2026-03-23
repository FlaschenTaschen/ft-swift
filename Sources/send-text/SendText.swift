// Reference: /Users/brennan/Developer/FT/flaschen-taschen/client/send-text.cc

import Foundation
import FlaschenTaschenClientKit
import os.log
import Darwin

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "SendText")

@main
struct SendText {
    static func main() async {
        // Ignore SIGPIPE to handle broken UDP connections gracefully
        signal(SIGPIPE, SIG_IGN)

        let (args, remainingArgs) = parseTextArguments(CommandLine.arguments)

        // Log raw command-line arguments
        logger.debug("Command-line arguments: \(CommandLine.arguments, privacy: .public)")

        // Validate font path
        guard var fontPath = args.fontPath else {
            printUsage(programName: CommandLine.arguments.first ?? "send-text")
            exit(1)
        }

        // Expand tilde in path
        fontPath = NSString(string: fontPath).expandingTildeInPath

        // Load font
        let font = BDFFont()
        if !font.loadFont(path: fontPath) {
            logger.error("Failed to load font: \(fontPath, privacy: .public)")
            exit(1)
        }

        // Determine actual height if not specified
        var actualHeight = args.standardOptions.height
        if actualHeight < 0 {
            actualHeight = args.verticalMode ? 35 : font.fontHeight()
        }

        // Determine actual width if not specified
        var actualWidth = args.standardOptions.width
        if actualWidth < 0 {
            // 87 is ASCII code for 'W'
            actualWidth = args.verticalMode ? max(1, font.characterWidth(87)) : 45
        }

        // Set up text input
        var text = ""
        if let textFile = args.textInput {
            let fileName = textFile == "-" ? "/dev/stdin" : textFile
            do {
                text = try String(contentsOfFile: fileName, encoding: .utf8)
                text = text.trimmingCharacters(in: .whitespaces)
            } catch {
                logger.error("Failed to read text file: \(fileName, privacy: .public)")
                exit(1)
            }
        }

        // Add remaining command-line arguments as text
        for arg in remainingArgs {
            if !text.isEmpty {
                text += " "
            }
            text += arg
        }

        // Trim leading/trailing whitespace
        text = text.trimmingCharacters(in: .whitespaces)

        if text.isEmpty {
            logger.error("No text provided")
            printUsage(programName: CommandLine.arguments.first ?? "send-text")
            exit(1)
        }

        // Connect to display
        let fd = openFlaschenTaschenSocket(hostname: args.standardOptions.hostname)
        guard fd >= 0 else {
            logger.error("Failed to connect to display")
            exit(1)
        }

        // Create display canvas
        let canvas = UDPFlaschenTaschen(fileDescriptor: fd, width: actualWidth, height: actualHeight)
        canvas.setOffset(x: args.standardOptions.xoff, y: args.standardOptions.yoff, z: args.standardOptions.layer)

        // Update args with actual text
        var finalArgs = args
        finalArgs.text = text

        // Set up signal handling
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT)
        signalSource.setEventHandler {
            logger.info("Received SIGINT, clearing display and exiting")
            canvas.clear()
            canvas.send()
            Darwin.close(fd)
            exit(0)
        }
        signalSource.resume()

        // Display text
        let controller = TextDisplayController(canvas: canvas, font: font, args: finalArgs)
        await controller.displayText()

        // Cleanup
        Darwin.close(fd)
    }
}

nonisolated private func printUsage(programName: String) {
    let usage = """
    usage: \(programName) [options] [<TEXT>|-i <textfile>]
    Options:
        -g <width>x<height>[+<off_x>+<off_y>[+<layer>]] : Output geometry. Default 45x<font-height>+0+0+1
        -l <layer>      : Layer 0..15. Default 1 (note if also given in -g, then last counts)
        -h <host>       : Flaschen-Taschen display hostname.
        -f <fontfile>   : Path to *.bdf font file (required)
        -i <textfile>   : Optional: read text from file. '-' for stdin.
        -s<ms>          : Scroll milliseconds per pixel (default 50). 0 for no-scroll. Negative for opposite direction.
        -O              : Only run once, don't scroll forever.
        -S<px>          : Letter spacing in pixels (default: 0)
        -c<RRGGBB>      : Text color as hex (default: FFFFFF)
        -b<RRGGBB>      : Background color as hex (default: 000000)
        -o<RRGGBB>      : Outline color as hex (default: no outline)
        -v              : Scroll text vertically
    """
    logger.info("\(usage, privacy: .public)")
}
