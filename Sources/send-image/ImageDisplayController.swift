// Image display controller - handles animations, scrolling, and display modes

import Foundation
import FlaschenTaschenClientKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "SendImage")

actor ImageDisplayController {
    private let canvas: UDPFlaschenTaschen
    private let imageData: ImageData
    private let args: ImageCommandLineArgs
    private var shouldStop = false

    init(canvas: UDPFlaschenTaschen, imageData: ImageData, args: ImageCommandLineArgs) {
        self.canvas = canvas
        self.imageData = imageData
        self.args = args
    }

    func displayImage() async {
        guard !imageData.frames.isEmpty else {
            logger.error("No frames to display")
            return
        }

        let startTime = Date()

        if imageData.isAnimated {
            // Animation mode (multi-frame)
            await displayAnimation(startTime: startTime)
        } else {
            // Single frame - check for scrolling
            if args.scrollDelayMs > 0 {
                await displayScrolling(startTime: startTime)
            } else {
                // Static display
                await displayStatic()
            }
        }
    }

    private func displayAnimation(startTime: Date) async {
        var frameIndex = 0

        while !shouldStop {
            // Check timeout
            if let timeout = args.timeoutSeconds {
                let elapsed = Int(Date().timeIntervalSince(startTime))
                if elapsed >= timeout {
                    break
                }
            }

            let frame = imageData.frames[frameIndex]
            let scaledFrame = scaleAndCenter(
                frame: frame,
                targetWidth: canvas.width,
                targetHeight: canvas.height
            )

            drawFrame(frame: scaledFrame)
            canvas.send()

            // Wait for frame delay
            let delayMs = frame.delayMs
            try? await Task.sleep(for: .milliseconds(delayMs))

            frameIndex = (frameIndex + 1) % imageData.frames.count
        }
    }

    private func displayScrolling(startTime: Date) async {
        guard let firstFrame = imageData.frames.first else { return }

        let scaledFrame = scaleAndCenter(
            frame: firstFrame,
            targetWidth: canvas.width * 2,  // Wide buffer for scrolling
            targetHeight: canvas.height
        )

        let scrollRange = scaledFrame.width

        while !shouldStop {
            // Check timeout
            if let timeout = args.timeoutSeconds {
                let elapsed = Int(Date().timeIntervalSince(startTime))
                if elapsed >= timeout {
                    break
                }
            }

            for position in 0..<scrollRange {
                if shouldStop {
                    return
                }

                // Draw scrolling window
                drawScrollingWindow(
                    sourceFrame: scaledFrame,
                    scrollPosition: position
                )
                canvas.send()

                try? await Task.sleep(for: .milliseconds(args.scrollDelayMs))
            }
        }
    }

    private func displayStatic() async {
        let startTime = Date()
        guard let firstFrame = imageData.frames.first else { return }

        let scaledFrame = scaleAndCenter(
            frame: firstFrame,
            targetWidth: canvas.width,
            targetHeight: canvas.height
        )

        drawFrame(frame: scaledFrame)
        canvas.send()

        // Keep display alive for timeout duration
        while !shouldStop {
            if let timeout = args.timeoutSeconds {
                let elapsed = Int(Date().timeIntervalSince(startTime))
                if elapsed >= timeout {
                    break
                }
            }

            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    private nonisolated func drawFrame(frame: ImageFrame) {
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                let pixelIndex = (y * frame.width + x) * 3
                if pixelIndex + 2 < frame.pixelData.count {
                    let r = frame.pixelData[pixelIndex]
                    let g = frame.pixelData[pixelIndex + 1]
                    let b = frame.pixelData[pixelIndex + 2]
                    let color = Color(r: r, g: g, b: b)
                    canvas.setPixel(x: x, y: y, color: color)
                }
            }
        }
    }

    private nonisolated func drawScrollingWindow(sourceFrame: ImageFrame, scrollPosition: Int) {
        let canvasWidth = canvas.width
        let canvasHeight = canvas.height

        for y in 0..<canvasHeight {
            for x in 0..<canvasWidth {
                let sourceX = scrollPosition + x
                let sourceY = y

                if sourceX < sourceFrame.width && sourceY < sourceFrame.height {
                    let pixelIndex = (sourceY * sourceFrame.width + sourceX) * 3
                    if pixelIndex + 2 < sourceFrame.pixelData.count {
                        let r = sourceFrame.pixelData[pixelIndex]
                        let g = sourceFrame.pixelData[pixelIndex + 1]
                        let b = sourceFrame.pixelData[pixelIndex + 2]
                        let color = Color(r: r, g: g, b: b)
                        canvas.setPixel(x: x, y: y, color: color)
                    }
                }
            }
        }
    }

    private nonisolated func scaleAndCenter(frame: ImageFrame, targetWidth: Int, targetHeight: Int) -> ImageFrame {
        FlaschenTaschenClientKit.scaleFrame(
            frame: frame,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            maintainAspectRatio: true,
            center: args.centerImage,
            brightness: args.brightness
        )
    }
}
