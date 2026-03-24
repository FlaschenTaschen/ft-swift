// Image display controller - handles animations, scrolling, and display modes

import Foundation
import FlaschenTaschenClientKit
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "SendImage")

actor ImageDisplayController {
    private let canvas: UDPFlaschenTaschen
    private let imageData: ImageData
    private let args: ImageArgs

    init(canvas: UDPFlaschenTaschen, imageData: ImageData, args: ImageArgs) {
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
        let loop = AnimationLoop(timeout: Double(args.timeoutSeconds ?? Int(StandardOptions.defaultTimeout)), delay: 1)
        var frameIndex = 0
        var frameAccumulatedMs = 0

        while loop.shouldContinue() {
            let frame = imageData.frames[frameIndex]
            let scaledFrame = scaleAndCenter(
                frame: frame,
                targetWidth: canvas.width,
                targetHeight: canvas.height
            )

            drawFrame(frame: scaledFrame)
            canvas.send()

            frameAccumulatedMs += frame.delayMs
            frameIndex = (frameIndex + 1) % imageData.frames.count

            // Sleep for accumulated delay
            if frameAccumulatedMs > 0 {
                do {
                    try await Task.sleep(for: .milliseconds(frameAccumulatedMs))
                } catch {
                    break
                }
            }
            frameAccumulatedMs = 0
            loop.nextFrame()
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
        let loop = AnimationLoop(timeout: Double(args.timeoutSeconds ?? Int(StandardOptions.defaultTimeout)), delay: args.scrollDelayMs)

        while loop.shouldContinue() {
            for position in 0..<scrollRange {
                if !loop.shouldContinue() {
                    return
                }

                // Draw scrolling window
                drawScrollingWindow(
                    sourceFrame: scaledFrame,
                    scrollPosition: position
                )
                canvas.send()
                loop.nextFrame()

                do {
                    try await loop.sleep()
                } catch {
                    return
                }
            }
        }
    }

    private func displayStatic() async {
        guard let firstFrame = imageData.frames.first else { return }

        let scaledFrame = scaleAndCenter(
            frame: firstFrame,
            targetWidth: canvas.width,
            targetHeight: canvas.height
        )

        let loop = AnimationLoop(timeout: Double(args.timeoutSeconds ?? Int(StandardOptions.defaultTimeout)), delay: 100)

        while loop.shouldContinue() {
            drawFrame(frame: scaledFrame)
            canvas.send()
            loop.nextFrame()

            do {
                try await loop.sleep()
            } catch {
                break
            }
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
