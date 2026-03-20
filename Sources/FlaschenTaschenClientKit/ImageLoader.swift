// Cross-platform image loading and processing
// Uses ImageIO for format support on both iOS and macOS

import Foundation
import ImageIO
import CoreGraphics
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "ImageLoader")

/// Single frame from an image or animation
public nonisolated struct ImageFrame: Sendable {
    public let pixelData: [UInt8]  // RGB pixel data
    public let width: Int
    public let height: Int
    public let delayMs: Int  // Animation frame delay in milliseconds

    public nonisolated init(pixelData: [UInt8], width: Int, height: Int, delayMs: Int = 0) {
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.delayMs = max(10, delayMs)  // Minimum 10ms delay
    }
}

/// Loaded image with frame(s) and metadata
public class ImageData: @unchecked Sendable {
    public let frames: [ImageFrame]
    public let originalWidth: Int
    public let originalHeight: Int

    public init(frames: [ImageFrame], originalWidth: Int, originalHeight: Int) {
        self.frames = frames
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
    }

    public var isAnimated: Bool {
        frames.count > 1
    }

    public var frameCount: Int {
        frames.count
    }
}

/// Load and decode image files
public nonisolated func loadImage(path: String) -> ImageData? {
    guard let url = URL(fileURLWithPath: path) as CFURL? else {
        logger.error("Invalid file path: \(path, privacy: .public)")
        return nil
    }

    guard let imageSource = CGImageSourceCreateWithURL(url, nil) else {
        logger.error("Failed to create image source: \(path, privacy: .public)")
        return nil
    }

    let frameCount = CGImageSourceGetCount(imageSource)
    guard frameCount > 0 else {
        logger.error("Image has no frames: \(path, privacy: .public)")
        return nil
    }

    var frames: [ImageFrame] = []
    var originalWidth = 0
    var originalHeight = 0

    for frameIndex in 0..<frameCount {
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, frameIndex, nil) else {
            logger.warning("Failed to load frame \(frameIndex, privacy: .public)")
            continue
        }

        let width = cgImage.width
        let height = cgImage.height

        if frameIndex == 0 {
            originalWidth = width
            originalHeight = height
        }

        // Extract pixel data
        if let pixelData = extractPixelData(cgImage: cgImage) {
            // Get frame delay for animations
            let delayMs = getFrameDelay(imageSource: imageSource, frameIndex: frameIndex)

            let frame = ImageFrame(pixelData: pixelData, width: width, height: height, delayMs: delayMs)
            frames.append(frame)
        }
    }

    guard !frames.isEmpty else {
        logger.error("No valid frames loaded from: \(path, privacy: .public)")
        return nil
    }

    logger.debug("Loaded image: \(path, privacy: .public), frames: \(frames.count, privacy: .public), size: \(originalWidth, privacy: .public)x\(originalHeight, privacy: .public)")
    return ImageData(frames: frames, originalWidth: originalWidth, originalHeight: originalHeight)
}

/// Scale and optionally center an image frame
public nonisolated func scaleFrame(
    frame: ImageFrame,
    targetWidth: Int,
    targetHeight: Int,
    maintainAspectRatio: Bool = true,
    center: Bool = false,
    brightness: UInt8 = 100
) -> ImageFrame {
    guard targetWidth > 0 && targetHeight > 0 else {
        return frame
    }

    // If frame already fits or matches, just adjust brightness
    if frame.width == targetWidth && frame.height == targetHeight {
        if brightness != 100 {
            return adjustBrightness(frame: frame, brightness: brightness)
        }
        return frame
    }

    // Calculate scale factor
    let (scaledWidth, scaledHeight, offsetX, offsetY) = calculateDimensions(
        sourceWidth: frame.width,
        sourceHeight: frame.height,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        maintainAspectRatio: maintainAspectRatio,
        center: center
    )

    // Create scaled pixel data
    var scaledData = [UInt8](repeating: 0, count: targetWidth * targetHeight * 3)

    for y in 0..<scaledHeight {
        for x in 0..<scaledWidth {
            // Bilinear sampling from source
            let srcX = Float(x) * Float(frame.width) / Float(scaledWidth)
            let srcY = Float(y) * Float(frame.height) / Float(scaledHeight)

            let pixel = bilinearSample(
                frame: frame,
                x: srcX,
                y: srcY
            )

            let outX = offsetX + x
            let outY = offsetY + y

            if outX >= 0 && outX < targetWidth && outY >= 0 && outY < targetHeight {
                let destIdx = (outY * targetWidth + outX) * 3
                if destIdx + 2 < scaledData.count {
                    scaledData[destIdx] = pixel.r
                    scaledData[destIdx + 1] = pixel.g
                    scaledData[destIdx + 2] = pixel.b
                }
            }
        }
    }

    // Apply light blur to soften sharp edges from bilinear interpolation
    var blurredData = scaledData
    applyLightBlur(to: &blurredData, width: targetWidth, height: targetHeight)

    // Apply brightness adjustment
    if brightness != 100 {
        let factor = Float(brightness) / 100.0
        for i in 0..<blurredData.count {
            blurredData[i] = UInt8(min(255, Int(Float(blurredData[i]) * factor)))
        }
    }

    return ImageFrame(pixelData: blurredData, width: targetWidth, height: targetHeight, delayMs: frame.delayMs)
}

// MARK: - Private Helpers

private nonisolated func extractPixelData(cgImage: CGImage) -> [UInt8]? {
    let width = cgImage.width
    let height = cgImage.height

    guard let data = cgImage.dataProvider?.data as Data? else {
        // Fallback: create context and render
        return renderImageToRGB(cgImage: cgImage)
    }

    var rgbData = [UInt8](repeating: 0, count: width * height * 3)

    for y in 0..<height {
        for x in 0..<width {
            let pixelOffset = (y * width + x) * 4  // RGBA is 4 bytes
            if pixelOffset + 3 < data.count {
                let r = data[pixelOffset]
                let g = data[pixelOffset + 1]
                let b = data[pixelOffset + 2]
                let a = data[pixelOffset + 3]

                // Skip fully transparent pixels (treat as background)
                if a == 0 {
                    continue
                }

                // Apply alpha blending (assume black background)
                let alpha = Float(a) / 255.0
                let rgbIdx = (y * width + x) * 3
                rgbData[rgbIdx] = UInt8(Float(r) * alpha)
                rgbData[rgbIdx + 1] = UInt8(Float(g) * alpha)
                rgbData[rgbIdx + 2] = UInt8(Float(b) * alpha)
            }
        }
    }

    return rgbData
}

private nonisolated func renderImageToRGB(cgImage: CGImage) -> [UInt8]? {
    let width = cgImage.width
    let height = cgImage.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bytesPerRow = width * 4
    var pixelBuffer = [UInt8](repeating: 0, count: height * bytesPerRow)

    guard let context = CGContext(
        data: &pixelBuffer,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: bytesPerRow,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var rgbData = [UInt8](repeating: 0, count: width * height * 3)
    for y in 0..<height {
        for x in 0..<width {
            let pixelOffset = (y * width + x) * 4
            let rgbIdx = (y * width + x) * 3
            rgbData[rgbIdx] = pixelBuffer[pixelOffset]
            rgbData[rgbIdx + 1] = pixelBuffer[pixelOffset + 1]
            rgbData[rgbIdx + 2] = pixelBuffer[pixelOffset + 2]
        }
    }

    return rgbData
}

private nonisolated func bilinearSample(frame: ImageFrame, x: Float, y: Float) -> (r: UInt8, g: UInt8, b: UInt8) {
    let ix = Int(x)
    let iy = Int(y)
    let fx = x - Float(ix)
    let fy = y - Float(iy)

    let x0 = max(0, min(frame.width - 1, ix))
    let x1 = max(0, min(frame.width - 1, ix + 1))
    let y0 = max(0, min(frame.height - 1, iy))
    let y1 = max(0, min(frame.height - 1, iy + 1))

    func getPixel(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        let idx = (y * frame.width + x) * 3
        if idx + 2 < frame.pixelData.count {
            return (frame.pixelData[idx], frame.pixelData[idx + 1], frame.pixelData[idx + 2])
        }
        return (0, 0, 0)
    }

    let p00 = getPixel(x: x0, y: y0)
    let p10 = getPixel(x: x1, y: y0)
    let p01 = getPixel(x: x0, y: y1)
    let p11 = getPixel(x: x1, y: y1)

    let r = bilinearInterpolate(p00.r, p10.r, p01.r, p11.r, fx, fy)
    let g = bilinearInterpolate(p00.g, p10.g, p01.g, p11.g, fx, fy)
    let b = bilinearInterpolate(p00.b, p10.b, p01.b, p11.b, fx, fy)

    return (r, g, b)
}

private nonisolated func bilinearInterpolate(_ p00: UInt8, _ p10: UInt8, _ p01: UInt8, _ p11: UInt8, _ fx: Float, _ fy: Float) -> UInt8 {
    let f00 = Float(p00) * (1 - fx) * (1 - fy)
    let f10 = Float(p10) * fx * (1 - fy)
    let f01 = Float(p01) * (1 - fx) * fy
    let f11 = Float(p11) * fx * fy
    return UInt8(f00 + f10 + f01 + f11)
}

private nonisolated func calculateDimensions(
    sourceWidth: Int,
    sourceHeight: Int,
    targetWidth: Int,
    targetHeight: Int,
    maintainAspectRatio: Bool,
    center: Bool
) -> (width: Int, height: Int, offsetX: Int, offsetY: Int) {
    var scaledWidth = targetWidth
    var scaledHeight = targetHeight
    var offsetX = 0
    var offsetY = 0

    if maintainAspectRatio {
        let aspectRatio = Float(sourceWidth) / Float(sourceHeight)
        let targetAspect = Float(targetWidth) / Float(targetHeight)

        if aspectRatio > targetAspect {
            // Source is wider
            scaledWidth = targetWidth
            scaledHeight = Int(Float(targetWidth) / aspectRatio)
        } else {
            // Source is taller
            scaledHeight = targetHeight
            scaledWidth = Int(Float(targetHeight) * aspectRatio)
        }
    }

    if center {
        offsetX = (targetWidth - scaledWidth) / 2
        offsetY = (targetHeight - scaledHeight) / 2
    }

    return (scaledWidth, scaledHeight, offsetX, offsetY)
}

private nonisolated func adjustBrightness(frame: ImageFrame, brightness: UInt8) -> ImageFrame {
    guard brightness != 100 else { return frame }

    let factor = Float(brightness) / 100.0
    var adjusted = frame.pixelData

    for i in stride(from: 0, to: adjusted.count, by: 1) {
        adjusted[i] = UInt8(min(255, Int(Float(adjusted[i]) * factor)))
    }

    return ImageFrame(pixelData: adjusted, width: frame.width, height: frame.height, delayMs: frame.delayMs)
}

private nonisolated func applyLightBlur(to pixelData: inout [UInt8], width: Int, height: Int) {
    // Apply a light 3x3 box blur to soften sharp edges from bilinear interpolation
    // This matches the smoothing behavior of Magick++'s scale function
    var temp = pixelData

    for y in 1..<(height - 1) {
        for x in 1..<(width - 1) {
            for c in 0..<3 {  // RGB channels
                var sum: Int = 0
                var count = 0

                // Sample 3x3 neighborhood
                for dy in -1...1 {
                    for dx in -1...1 {
                        let nx = x + dx
                        let ny = y + dy
                        let idx = (ny * width + nx) * 3 + c
                        if idx >= 0 && idx < pixelData.count {
                            sum += Int(pixelData[idx])
                            count += 1
                        }
                    }
                }

                if count > 0 {
                    let idx = (y * width + x) * 3 + c
                    // Weighted average: 2/3 original, 1/3 blur
                    let blurred = UInt8(sum / count)
                    temp[idx] = UInt8((Int(pixelData[idx]) * 2 + Int(blurred)) / 3)
                }
            }
        }
    }

    pixelData = temp
}

private nonisolated func getFrameDelay(imageSource: CGImageSource, frameIndex: Int) -> Int {
    let frameDictionary = CGImageSourceCopyPropertiesAtIndex(imageSource, frameIndex, nil) as? [String: Any]

    if let gifDictionary = frameDictionary?[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
        if let delayTime = gifDictionary[kCGImagePropertyGIFDelayTime as String] as? NSNumber {
            // GIF delay is in 1/100th of a second, convert to milliseconds
            return Int(delayTime.doubleValue * 10)
        }
    }

    // Default to 100ms for still images
    return 100
}
