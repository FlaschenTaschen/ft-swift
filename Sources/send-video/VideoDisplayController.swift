// Video display controller - handles playback and frame timing

import Foundation
import FlaschenTaschenClientKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "SendVideo")

actor VideoDisplayController {
    private let canvas: UDPFlaschenTaschen
    private let frameReader: VideoFrameReader
    private let args: VideoCommandLineArgs
    private var shouldStop = false

    init(canvas: UDPFlaschenTaschen, frameReader: VideoFrameReader, args: VideoCommandLineArgs) {
        self.canvas = canvas
        self.frameReader = frameReader
        self.args = args
    }

    func playVideo() async {
        logger.info("Starting video playback (streaming)")
        let startTime = Date()
        var framesSent = 0
        var firstFrameLogged = false
        var loopCount = 0
        var frameCount = 0

        while !shouldStop {
            // Check timeout
            if let timeout = args.timeoutSeconds {
                let elapsed = Int(Date().timeIntervalSince(startTime))
                if elapsed >= timeout {
                    logger.info("Timeout reached at \(elapsed, privacy: .public)s")
                    let msg = "Timeout reached at \(elapsed)s\n"
                    FileHandle.standardError.write(msg.data(using: .utf8) ?? Data())
                    fflush(stderr)
                    break
                }
            }

            // Get next frame from stream
            guard let frame = frameReader.nextFrame() else {
                // End of stream reached
                loopCount += 1
                logger.debug("End of stream reached at loop \(loopCount, privacy: .public) after \(frameCount, privacy: .public) frames")
                let endMsg = "End of stream reached at loop \(loopCount) after \(frameCount) frames\n"
                FileHandle.standardError.write(endMsg.data(using: .utf8) ?? Data())
                fflush(stderr)

                if let timeout = args.timeoutSeconds {
                    let elapsed = Int(Date().timeIntervalSince(startTime))
                    if elapsed >= timeout {
                        logger.info("Timeout reached (\(elapsed, privacy: .public)s >= \(timeout, privacy: .public)s), stopping playback")
                        break
                    }
                }

                // Reset for looping
                if frameReader.reset() {
                    let loopNumber = loopCount + 1
                    logger.info("Completed loop \(loopCount, privacy: .public) with \(frameCount, privacy: .public) frames, starting loop \(loopNumber, privacy: .public)")
                    let msg = "Completed loop \(loopCount) with \(frameCount) frames, starting loop \(loopNumber)\n"
                    FileHandle.standardError.write(msg.data(using: .utf8) ?? Data())
                    fflush(stderr)
                    frameCount = 0
                    continue
                } else {
                    logger.error("Failed to reset video stream for looping")
                    let errMsg = "ERROR: Failed to reset video stream for looping\n"
                    FileHandle.standardError.write(errMsg.data(using: .utf8) ?? Data())
                    fflush(stderr)
                    break
                }
            }

            if !firstFrameLogged {
                logger.info("First frame decoded and ready to display")
                firstFrameLogged = true
            }

            let scaledFrame = scaleAndCenter(
                frame: frame,
                targetWidth: canvas.width,
                targetHeight: canvas.height
            )

            drawFrame(frame: scaledFrame)
            canvas.send()
            framesSent += 1
            frameCount += 1

            // Log progress every 30 frames
            if framesSent % 30 == 0 {
                let elapsed = Int(Date().timeIntervalSince(startTime))
                let progressMsg = "Progress: \(framesSent) frames sent, elapsed \(elapsed)s\n"
                FileHandle.standardError.write(progressMsg.data(using: .utf8) ?? Data())
                fflush(stderr)
            }

            // Wait for frame duration
            let delayMs = frame.durationMs
            try? await Task.sleep(for: .milliseconds(delayMs))
        }

        logger.info("Video playback complete: \(framesSent, privacy: .public) frames sent, \(loopCount, privacy: .public) loops")
        let completeMsg = "Video playback complete: \(framesSent) frames sent, \(loopCount) loops\n"
        FileHandle.standardError.write(completeMsg.data(using: .utf8) ?? Data())
        fflush(stderr)

        // Clear display on exit
        canvas.clear()
        canvas.send()
    }

    private nonisolated func scaleAndCenter(frame: VideoFrame, targetWidth: Int, targetHeight: Int) -> VideoFrame {
        FlaschenTaschenClientKit.scaleVideoFrame(
            frame: frame,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            maintainAspectRatio: true,
            center: args.centerImage,
            brightness: args.brightness
        )
    }

    private nonisolated func drawFrame(frame: VideoFrame) {
        // Only draw the portion that fits on the canvas
        let displayWidth = min(frame.width, canvas.width)
        let displayHeight = min(frame.height, canvas.height)
        let pixelData = frame.pixelData
        let bytesPerPixel = frame.bytesPerPixel
        let stride = frame.width * bytesPerPixel

        for y in 0..<displayHeight {
            let rowOffset = y * stride
            for x in 0..<displayWidth {
                let pixelIndex = rowOffset + (x * bytesPerPixel)
                if bytesPerPixel == 4 && pixelIndex + 3 < pixelData.count {
                    // BGRA format
                    let r = pixelData[pixelIndex + 2]
                    let g = pixelData[pixelIndex + 1]
                    let b = pixelData[pixelIndex]
                    let color = Color(r: r, g: g, b: b)
                    canvas.setPixel(x: x, y: y, color: color)
                } else if bytesPerPixel == 3 && pixelIndex + 2 < pixelData.count {
                    // RGB format
                    let color = Color(r: pixelData[pixelIndex], g: pixelData[pixelIndex + 1], b: pixelData[pixelIndex + 2])
                    canvas.setPixel(x: x, y: y, color: color)
                }
            }
        }
    }
}
