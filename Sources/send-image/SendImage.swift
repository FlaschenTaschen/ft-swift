// Reference: /Users/brennan/Developer/FT/flaschen-taschen/client/send-image.cc

import Foundation
import FlaschenTaschenClientKit
import os.log
import Darwin

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "SendImage")

@main
struct SendImage {
    static func main() async {
        // Ignore SIGPIPE to handle broken UDP connections gracefully
        signal(SIGPIPE, SIG_IGN)

        let args = parseImageArguments(CommandLine.arguments)

        // Log raw command-line arguments
        logger.debug("Command-line arguments: \(CommandLine.arguments, privacy: .public)")

        // Handle clear-only mode
        if args.clearOnly {
            let fd = openFlaschenTaschenSocket(hostname: args.standardOptions.hostname)
            guard fd >= 0 else {
                logger.error("Failed to connect to display")
                exit(1)
            }

            let canvas = UDPFlaschenTaschen(
                fileDescriptor: fd,
                width: args.standardOptions.width,
                height: args.standardOptions.height
            )
            canvas.clear()
            canvas.send()
            Darwin.close(fd)
            exit(0)
        }

        // Get image file from arguments
        let imageFile = args.imageFile ?? ""
        guard !imageFile.isEmpty else {
            printUsage(programName: CommandLine.arguments.first ?? "send-image")
            exit(1)
        }

        // Load image
        guard let imageData = loadImage(path: imageFile) else {
            logger.error("Failed to load image: \(imageFile, privacy: .public)")
            exit(1)
        }

        // Connect to display
        let fd = openFlaschenTaschenSocket(hostname: args.standardOptions.hostname)
        guard fd >= 0 else {
            logger.error("Failed to connect to display")
            exit(1)
        }

        // Create display canvas
        let canvas = UDPFlaschenTaschen(
            fileDescriptor: fd,
            width: args.standardOptions.width,
            height: args.standardOptions.height
        )
        logger.info("Setting canvas offset: x=\(args.standardOptions.xoff, privacy: .public), y=\(args.standardOptions.yoff, privacy: .public), layer=\(args.standardOptions.layer, privacy: .public)")
        canvas.setOffset(
            x: args.standardOptions.xoff,
            y: args.standardOptions.yoff,
            z: args.standardOptions.layer
        )

        // Set up signal handling
        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT)
        signalSource.setEventHandler {
            logger.info("Received SIGINT, clearing display and exiting")
            // Don't let leftovers cover up content (only clear if not on layer 0)
            if args.standardOptions.layer > 0 {
                canvas.clear()
                canvas.send()
            }
            Darwin.close(fd)
            exit(0)
        }
        signalSource.resume()

        let signalSourceTerm = DispatchSource.makeSignalSource(signal: SIGTERM)
        signalSourceTerm.setEventHandler {
            logger.info("Received SIGTERM, clearing display and exiting")
            // Don't let leftovers cover up content (only clear if not on layer 0)
            if args.standardOptions.layer > 0 {
                canvas.clear()
                canvas.send()
            }
            Darwin.close(fd)
            exit(0)
        }
        signalSourceTerm.resume()

        // Display image (timeout is now handled via AnimationLoop inside displayImage)
        let controller = ImageDisplayController(canvas: canvas, imageData: imageData, args: args)
        await controller.displayImage()

        // Don't let leftovers cover up content (match C++ behavior)
        if args.standardOptions.layer > 0 {
            canvas.clear()
            canvas.send()
        }

        // Cleanup
        Darwin.close(fd)
    }
}

nonisolated private func printUsage(programName: String) {
    let usage = """
    usage: \(programName) [options] <image-file>
    Options:
        -g <width>x<height>[+<off_x>+<off_y>[+<layer>]] : Output geometry. Default 45x35+0+0+0
        -l <layer>      : Layer 0..15. Default 0 (note if also given in -g, then last counts)
        -h <host>       : Flaschen-Taschen display hostname.
        -c              : Center image in available space
        -s[ms]          : Scroll horizontally (optional delay ms; default 50). 0 for no-scroll.
        -b<brightness>  : Brightness percent (default: 100, range: 0-100)
        -t<timeout>     : Display duration in seconds
        -C              : Clear given area and exit
    """
    print(usage)
}
