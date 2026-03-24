// Reference: /Users/brennan/Developer/FT/flaschen-taschen/client/send-video.cc

import Foundation
import FlaschenTaschenClientKit
import os.log
import Darwin

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "SendVideo")

@main
struct SendVideo {
    static func main() async {
        // Ignore SIGPIPE to handle broken UDP connections gracefully
        signal(SIGPIPE, SIG_IGN)

        let (args, remainingArgs) = parseVideoArguments(CommandLine.arguments)

        // Log raw command-line arguments
        logger.debug("Command-line arguments: \(CommandLine.arguments, privacy: .public)")
        logger.debug("Parsed geometry: width=\(args.standardOptions.width), height=\(args.standardOptions.height), offsetX=\(args.standardOptions.xoff), offsetY=\(args.standardOptions.yoff), layer=\(args.standardOptions.layer)")

        // Get video file from arguments
        let videoFile = args.videoFile ?? (remainingArgs.first ?? "")
        guard !videoFile.isEmpty else {
            printUsage(programName: CommandLine.arguments.first ?? "send-video")
            exit(1)
        }

        logger.info("Attempting to load video from: \(videoFile, privacy: .public)")
        let expandedPath = NSString(string: videoFile).expandingTildeInPath
        logger.info("Expanded path: \(expandedPath, privacy: .public)")
        let fileExists = FileManager.default.fileExists(atPath: expandedPath)
        logger.info("File exists at path: \(fileExists, privacy: .public)")

        // Load video (streaming)
        guard let videoReader = loadVideoStream(path: videoFile) else {
            logger.error("Failed to load video: \(videoFile, privacy: .public)")
            exit(1)
        }

        logger.info("Loaded video: \(videoFile, privacy: .public), \(videoReader.originalWidth, privacy: .public)x\(videoReader.originalHeight, privacy: .public), fps: \(videoReader.frameRate, privacy: .public), duration: \(videoReader.durationSeconds, privacy: .public)s")

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
            canvas.clear()
            canvas.send()
            Darwin.close(fd)
            exit(0)
        }
        signalSource.resume()

        let signalSourceTerm = DispatchSource.makeSignalSource(signal: SIGTERM)
        signalSourceTerm.setEventHandler {
            logger.info("Received SIGTERM, clearing display and exiting")
            canvas.clear()
            canvas.send()
            Darwin.close(fd)
            exit(0)
        }
        signalSourceTerm.resume()

        // Play video
        let controller = VideoDisplayController(canvas: canvas, frameReader: videoReader, args: args)
        await controller.playVideo()

        // Cleanup
        Darwin.close(fd)
    }
}

nonisolated private func printUsage(programName: String) {
    let usage = """
    usage: \(programName) [options] <video-file>
    Options:
        -g <width>x<height>[+<off_x>+<off_y>[+<layer>]] : Output geometry. Default 45x35+0+0+0
        -l <layer>      : Layer 0..15. Default 0 (note if also given in -g, then last counts)
        -h <host>       : Flaschen-Taschen display hostname.
        -c              : Center image in available space
        -b<brightness>  : Brightness percent (default: 100, range: 0-100)
        -t<timeout>     : Playback duration in seconds
    """
    print(usage)
}
