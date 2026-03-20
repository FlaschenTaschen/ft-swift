// Cross-platform video decoding using AVFoundation
// Supports MP4, MOV, AVI, and other formats on iOS and macOS

import Foundation
import AVFoundation
import CoreImage
import Accelerate
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "VideoDecoder")

/// Video frame with timing information
public nonisolated struct VideoFrame: Sendable {
    public let pixelData: [UInt8]  // BGRA pixel data (4 bytes per pixel)
    public let width: Int
    public let height: Int
    public let bytesPerPixel: Int  // 4 for BGRA, 3 for RGB
    public let timestampSeconds: Double  // Frame timestamp
    public let durationMs: Int  // Expected duration until next frame

    public nonisolated init(pixelData: [UInt8], width: Int, height: Int, bytesPerPixel: Int = 4,
                           timestampSeconds: Double, durationMs: Int) {
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.bytesPerPixel = bytesPerPixel
        self.timestampSeconds = timestampSeconds
        self.durationMs = max(1, durationMs)
    }
}

/// Decoded video with all frames and metadata (legacy, kept for compatibility)
public class VideoData: @unchecked Sendable {
    public let frames: [VideoFrame]
    public let originalWidth: Int
    public let originalHeight: Int
    public let frameRate: Double
    public let durationSeconds: Double

    public init(frames: [VideoFrame], originalWidth: Int, originalHeight: Int,
                frameRate: Double, durationSeconds: Double) {
        self.frames = frames
        self.originalWidth = originalWidth
        self.originalHeight = originalHeight
        self.frameRate = frameRate
        self.durationSeconds = durationSeconds
    }

    public var frameCount: Int {
        frames.count
    }
}

/// Streams video frames on-demand without buffering all frames
public class VideoFrameReader: @unchecked Sendable {
    public let originalWidth: Int
    public let originalHeight: Int
    public let frameRate: Double
    public let durationSeconds: Double

    private var reader: AVAssetReader
    private var output: AVAssetReaderTrackOutput
    private let asset: AVURLAsset
    private let videoTrack: AVAssetTrack

    public init?(asset: AVURLAsset, videoTrack: AVAssetTrack) {
        let dimensions = videoTrack.naturalSize
        self.originalWidth = Int(dimensions.width)
        self.originalHeight = Int(dimensions.height)

        guard originalWidth > 0 && originalHeight > 0 else {
            return nil
        }

        self.frameRate = Double(videoTrack.nominalFrameRate)
        guard frameRate > 0 else {
            return nil
        }

        self.durationSeconds = CMTimeGetSeconds(asset.duration)
        guard durationSeconds > 0 else {
            return nil
        }

        guard let reader = try? AVAssetReader(asset: asset) else {
            return nil
        }

        let output = AVAssetReaderTrackOutput(track: videoTrack,
                                              outputSettings: [
                                                  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                                              ])
        output.alwaysCopiesSampleData = true
        reader.add(output)

        guard reader.startReading() else {
            return nil
        }

        self.reader = reader
        self.output = output
        self.asset = asset
        self.videoTrack = videoTrack
    }

    /// Reset reader to beginning for looping
    public func reset() -> Bool {
        // Cancel the current reader
        reader.cancelReading()

        // Create a new reader from scratch
        guard let newReader = try? AVAssetReader(asset: asset) else {
            return false
        }

        let newOutput = AVAssetReaderTrackOutput(track: videoTrack,
                                                 outputSettings: [
                                                     kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                                                 ])
        newOutput.alwaysCopiesSampleData = true  // IMPORTANT: Copy data to avoid reuse issues
        newReader.add(newOutput)

        guard newReader.startReading() else {
            return false
        }

        self.reader = newReader
        self.output = newOutput

        return true
    }

    /// Get next frame from the video stream
    /// Returns nil if no more frames available
    public func nextFrame() -> VideoFrame? {
        guard let sampleBuffer = output.copyNextSampleBuffer() else {
            return nil
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        // Get timestamp
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampSeconds = CMTimeGetSeconds(timestamp)

        // Get frame duration from sample buffer
        let frameDuration = CMSampleBufferGetDuration(sampleBuffer)
        let frameDurationSeconds = CMTimeGetSeconds(frameDuration)
        let durationMs: Int
        if frameDurationSeconds.isFinite && frameDurationSeconds > 0 {
            durationMs = max(1, Int(frameDurationSeconds * 1000))
        } else {
            // Fallback to calculated duration based on frame rate
            durationMs = max(1, Int((1.0 / frameRate) * 1000))
        }

        // Get BGRA data directly without conversion
        guard let bgraData = pixelBufferToBGRA(pixelBuffer: pixelBuffer, width: originalWidth, height: originalHeight) else {
            return nil
        }

        let frame = VideoFrame(pixelData: bgraData, width: originalWidth, height: originalHeight, bytesPerPixel: 4,
                              timestampSeconds: timestampSeconds, durationMs: durationMs)
        return frame
    }

    deinit {
        reader.cancelReading()
    }
}

/// Load video for streaming playback (on-demand frame decoding)
public nonisolated func loadVideoStream(path: String) -> VideoFrameReader? {
    logger.debug("loadVideoStream: Starting with path \(path, privacy: .public)")
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)

    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
        logger.error("No video track found in: \(path, privacy: .public)")
        return nil
    }

    let reader = VideoFrameReader(asset: asset, videoTrack: videoTrack)
    if reader != nil {
        logger.debug("loadVideoStream: Created frame reader for \(path, privacy: .public), fps: \(reader!.frameRate, privacy: .public)")
    }
    return reader
}

/// Load and decode video files
public nonisolated func loadVideo(path: String) -> VideoData? {
    logger.debug("loadVideo: Starting with path \(path, privacy: .public)")
    let url = URL(fileURLWithPath: path)
    let asset = AVURLAsset(url: url)

    // Get video track (using synchronous API for simplicity)
    guard let videoTrack = asset.tracks(withMediaType: .video).first else {
        logger.error("No video track found in: \(path, privacy: .public)")
        return nil
    }
    logger.debug("loadVideo: Found video track")

    // Get video dimensions
    let dimensions = videoTrack.naturalSize
    let videoWidth = Int(dimensions.width)
    let videoHeight = Int(dimensions.height)

    guard videoWidth > 0 && videoHeight > 0 else {
        logger.error("Invalid video dimensions: \(videoWidth, privacy: .public)x\(videoHeight, privacy: .public)")
        return nil
    }

    // Get frame rate
    let frameRate = Double(videoTrack.nominalFrameRate)
    guard frameRate > 0 else {
        logger.error("Invalid frame rate")
        return nil
    }

    // Get duration
    let duration = CMTimeGetSeconds(asset.duration)
    guard duration > 0 else {
        logger.error("Invalid video duration")
        return nil
    }

    // Extract frames
    var frames: [VideoFrame] = []
    let reader = try? AVAssetReader(asset: asset)
    guard let reader = reader else {
        logger.error("Failed to create asset reader")
        return nil
    }

    let output = AVAssetReaderTrackOutput(track: videoTrack,
                                          outputSettings: [
                                              kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                                          ])
    output.alwaysCopiesSampleData = false
    reader.add(output)

    guard reader.startReading() else {
        logger.error("Failed to start reading video")
        return nil
    }

    var frameIndex = 0
    while let sampleBuffer = output.copyNextSampleBuffer() {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            continue
        }

        // Get timestamp
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let timestampSeconds = CMTimeGetSeconds(timestamp)

        // Get duration of this frame
        let frameDuration = CMSampleBufferGetDuration(sampleBuffer)
        let frameDurationSeconds = CMTimeGetSeconds(frameDuration)
        let durationMs: Int
        if frameDurationSeconds.isFinite && frameDurationSeconds > 0 {
            durationMs = max(1, Int(frameDurationSeconds * 1000))
        } else {
            // Fallback to calculated duration based on frame rate
            durationMs = max(1, Int((1.0 / frameRate) * 1000))
        }

        // Convert pixel buffer to RGB
        if let rgbData = pixelBufferToRGB(pixelBuffer: pixelBuffer, width: videoWidth, height: videoHeight) {
            let frame = VideoFrame(pixelData: rgbData, width: videoWidth, height: videoHeight,
                                  timestampSeconds: timestampSeconds, durationMs: durationMs)
            frames.append(frame)
        }

        frameIndex += 1

        // Limit frame extraction to avoid memory issues (max 500 frames)
        if frameIndex >= 500 {
            logger.warning("Limiting video extraction to 500 frames")
            break
        }
    }

    reader.cancelReading()

    guard !frames.isEmpty else {
        logger.error("No frames extracted from video")
        return nil
    }

    logger.debug("Loaded video: \(path, privacy: .public), frames: \(frames.count, privacy: .public), size: \(videoWidth, privacy: .public)x\(videoHeight, privacy: .public), fps: \(frameRate, privacy: .public)")
    return VideoData(frames: frames, originalWidth: videoWidth, originalHeight: videoHeight,
                    frameRate: frameRate, durationSeconds: duration)
}

/// Scale video frame to target dimensions
public nonisolated func scaleVideoFrame(
    frame: VideoFrame,
    targetWidth: Int,
    targetHeight: Int,
    maintainAspectRatio: Bool = true,
    center: Bool = false,
    brightness: UInt8 = 100
) -> VideoFrame {
    guard targetWidth > 0 && targetHeight > 0 else {
        return frame
    }

    // If frame already matches, just adjust brightness
    if frame.width == targetWidth && frame.height == targetHeight {
        if brightness != 100 {
            return adjustVideoBrightness(frame: frame, brightness: brightness)
        }
        return frame
    }

    // Calculate scale factor
    let (scaledWidth, scaledHeight, offsetX, offsetY) = calculateVideoDimensions(
        sourceWidth: frame.width,
        sourceHeight: frame.height,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
        maintainAspectRatio: maintainAspectRatio,
        center: center
    )

    // Create scaled pixel data (RGB output)
    var scaledData = [UInt8](repeating: 0, count: targetWidth * targetHeight * 3)

    for y in 0..<scaledHeight {
        for x in 0..<scaledWidth {
            // Bilinear sampling from source
            let srcX = Float(x) * Float(frame.width) / Float(scaledWidth)
            let srcY = Float(y) * Float(frame.height) / Float(scaledHeight)

            let pixel = bilinearSampleVideo(frame: frame, x: srcX, y: srcY)

            let outX = offsetX + x
            let outY = offsetY + y

            if outX >= 0 && outX < targetWidth && outY >= 0 && outY < targetHeight {
                let destIdx = (outY * targetWidth + outX) * 3
                var r = pixel.r
                var g = pixel.g
                var b = pixel.b

                if brightness != 100 {
                    let factor = Float(brightness) / 100.0
                    r = UInt8(min(255, Int(Float(r) * factor)))
                    g = UInt8(min(255, Int(Float(g) * factor)))
                    b = UInt8(min(255, Int(Float(b) * factor)))
                }

                if destIdx + 2 < scaledData.count {
                    scaledData[destIdx] = r
                    scaledData[destIdx + 1] = g
                    scaledData[destIdx + 2] = b
                }
            }
        }
    }

    return VideoFrame(pixelData: scaledData, width: targetWidth, height: targetHeight, bytesPerPixel: 3,
                     timestampSeconds: frame.timestampSeconds, durationMs: frame.durationMs)
}

// MARK: - Private Helpers

private nonisolated func pixelBufferToBGRA(pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> [UInt8]? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        return nil
    }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

    guard pixelFormat == kCVPixelFormatType_32BGRA else {
        logger.warning("Unsupported pixel format: \(pixelFormat, privacy: .public)")
        return nil
    }

    // Just copy the BGRA data directly - no conversion needed
    let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
    var bgraData = [UInt8](repeating: 0, count: width * height * 4)

    for y in 0..<height {
        let srcOffset = y * bytesPerRow
        let dstOffset = y * width * 4
        bgraData.withUnsafeMutableBytes { dest in
            memcpy(dest.baseAddress! + dstOffset, buffer + srcOffset, width * 4)
        }
    }

    return bgraData
}

private nonisolated func pixelBufferToRGB(pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> [UInt8]? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        return nil
    }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

    var rgbData = [UInt8](repeating: 0, count: width * height * 3)

    if pixelFormat == kCVPixelFormatType_32BGRA {
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)

        for y in 0..<height {
            for x in 0..<width {
                let pixelOffset = y * bytesPerRow + x * 4
                // BGRA format
                let b = buffer[pixelOffset]
                let g = buffer[pixelOffset + 1]
                let r = buffer[pixelOffset + 2]
                let a = buffer[pixelOffset + 3]

                let rgbIndex = (y * width + x) * 3
                // Alpha blending (premultiply)
                let alpha = Float(a) / 255.0
                rgbData[rgbIndex] = UInt8(Float(r) * alpha)
                rgbData[rgbIndex + 1] = UInt8(Float(g) * alpha)
                rgbData[rgbIndex + 2] = UInt8(Float(b) * alpha)
            }
        }
    } else {
        logger.warning("Unsupported pixel format: \(pixelFormat, privacy: .public)")
        return nil
    }

    return rgbData
}

private nonisolated func pixelBufferToRGBOptimized(pixelBuffer: CVPixelBuffer, width: Int, height: Int) -> [UInt8]? {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
        return nil
    }

    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)

    var rgbData = [UInt8](repeating: 0, count: width * height * 3)

    if pixelFormat == kCVPixelFormatType_32BGRA {
        let buffer = baseAddress.assumingMemoryBound(to: UInt32.self)
        var rgbIndex = 0

        for y in 0..<height {
            let rowStartIndex = y * (bytesPerRow / 4)
            for x in 0..<width {
                let pixelValue = buffer[rowStartIndex + x]
                // BGRA to RGB (as UInt32 operations)
                let b = UInt8(pixelValue & 0xFF)
                let g = UInt8((pixelValue >> 8) & 0xFF)
                let r = UInt8((pixelValue >> 16) & 0xFF)
                // Skip alpha (pixelValue >> 24) & 0xFF

                rgbData[rgbIndex] = r
                rgbData[rgbIndex + 1] = g
                rgbData[rgbIndex + 2] = b
                rgbIndex += 3
            }
        }
    } else {
        logger.warning("Unsupported pixel format: \(pixelFormat, privacy: .public)")
        return nil
    }

    return rgbData
}

private nonisolated func bilinearSampleVideo(frame: VideoFrame, x: Float, y: Float) -> (r: UInt8, g: UInt8, b: UInt8) {
    let ix = Int(x)
    let iy = Int(y)
    let fx = x - Float(ix)
    let fy = y - Float(iy)

    let x0 = max(0, min(frame.width - 1, ix))
    let x1 = max(0, min(frame.width - 1, ix + 1))
    let y0 = max(0, min(frame.height - 1, iy))
    let y1 = max(0, min(frame.height - 1, iy + 1))

    func getPixel(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
        if frame.bytesPerPixel == 4 {
            // BGRA format
            let idx = (y * frame.width + x) * 4
            if idx + 3 < frame.pixelData.count {
                let b = frame.pixelData[idx]
                let g = frame.pixelData[idx + 1]
                let r = frame.pixelData[idx + 2]
                return (r, g, b)
            }
        } else {
            // RGB format
            let idx = (y * frame.width + x) * 3
            if idx + 2 < frame.pixelData.count {
                return (frame.pixelData[idx], frame.pixelData[idx + 1], frame.pixelData[idx + 2])
            }
        }
        return (0, 0, 0)
    }

    let p00 = getPixel(x: x0, y: y0)
    let p10 = getPixel(x: x1, y: y0)
    let p01 = getPixel(x: x0, y: y1)
    let p11 = getPixel(x: x1, y: y1)

    let r = bilinearInterpolateVideo(p00.r, p10.r, p01.r, p11.r, fx, fy)
    let g = bilinearInterpolateVideo(p00.g, p10.g, p01.g, p11.g, fx, fy)
    let b = bilinearInterpolateVideo(p00.b, p10.b, p01.b, p11.b, fx, fy)

    return (r, g, b)
}

private nonisolated func bilinearInterpolateVideo(_ p00: UInt8, _ p10: UInt8, _ p01: UInt8, _ p11: UInt8, _ fx: Float, _ fy: Float) -> UInt8 {
    let f00 = Float(p00) * (1 - fx) * (1 - fy)
    let f10 = Float(p10) * fx * (1 - fy)
    let f01 = Float(p01) * (1 - fx) * fy
    let f11 = Float(p11) * fx * fy
    return UInt8(f00 + f10 + f01 + f11)
}

private nonisolated func calculateVideoDimensions(
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

private nonisolated func adjustVideoBrightness(frame: VideoFrame, brightness: UInt8) -> VideoFrame {
    guard brightness != 100 else { return frame }

    let factor = Float(brightness) / 100.0
    var adjusted = frame.pixelData

    for i in stride(from: 0, to: adjusted.count, by: 1) {
        adjusted[i] = UInt8(min(255, Int(Float(adjusted[i]) * factor)))
    }

    return VideoFrame(pixelData: adjusted, width: frame.width, height: frame.height,
                     timestampSeconds: frame.timestampSeconds, durationMs: frame.durationMs)
}
