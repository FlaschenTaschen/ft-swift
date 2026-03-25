// Grayscale - Render a JSON-defined pixel mask as grayscale

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "grayscale")

public enum GrayscaleOrientation: Sendable {
    case horizontal
    case vertical
}

public struct MaskData: Sendable {
    public var pixels: [[UInt8]]
    public var width: Int
    public var height: Int

    public init(pixels: [[UInt8]], width: Int, height: Int) {
        self.pixels = pixels
        self.width = width
        self.height = height
    }
}

public enum GrayscaleMode: Sendable {
    case bounce
    case center
    case left
    case right
    case top
    case bottom
}

public struct GrayscaleDemo: Sendable {
    public struct Options: Sendable {
        public var standardOptions: StandardOptions
        public var logoColor: Color?
        public var mode: GrayscaleMode
        public var masks: [MaskData]
        public var orientation: GrayscaleOrientation

        public init(
            standardOptions: StandardOptions,
            logoColor: Color? = nil,
            mode: GrayscaleMode = .bounce,
            masks: [MaskData] = [],
            orientation: GrayscaleOrientation = .horizontal
        ) {
            self.standardOptions = standardOptions
            self.logoColor = logoColor
            self.mode = mode
            self.masks = masks
            self.orientation = orientation
        }
    }

    public static func run(options: Options, canvas: UDPFlaschenTaschen) async {
        let combined = combineMasks(masks: options.masks, orientation: options.orientation)
        var imageWidth = combined.width
        var imageHeight = combined.height
        var mask = combined.pixels

        // For non-bounce modes, pad the combined mask to display geometry to prevent server tiling issues
        // This ensures the full display area is covered by our image data
        if options.mode != .bounce && !mask.isEmpty {
            let displayWidth = options.standardOptions.width
            let displayHeight = options.standardOptions.height
            if imageWidth < displayWidth || imageHeight < displayHeight {
                // Pad horizontally if needed
                if imageWidth < displayWidth {
                    let padWidth = displayWidth - imageWidth
                    let padLeft = padWidth / 2
                    let padRight = padWidth - padLeft

                    var paddedMask: [[UInt8]] = []
                    for row in mask {
                        var paddedRow = [UInt8](repeating: 255, count: padLeft) + row + [UInt8](repeating: 255, count: padRight)
                        paddedMask.append(paddedRow)
                    }
                    mask = paddedMask
                    imageWidth = displayWidth
                }

                // Pad vertically if needed
                if imageHeight < displayHeight {
                    let padHeight = displayHeight - imageHeight
                    let padTop = padHeight / 2
                    let padBottom = padHeight - padTop

                    let emptyRow = [UInt8](repeating: 255, count: displayWidth)
                    mask = [Array](repeating: emptyRow, count: padTop) + mask + [Array](repeating: emptyRow, count: padBottom)
                    imageHeight = displayHeight
                }
            }
        }

        logger.info("grayscale: geometry=\(options.standardOptions.width, privacy: .public)x\(options.standardOptions.height, privacy: .public)+\(options.standardOptions.xoff, privacy: .public)+\(options.standardOptions.yoff, privacy: .public) layer=\(options.standardOptions.layer, privacy: .public) delay=\(options.standardOptions.delay, privacy: .public)ms mode=\(String(describing: options.mode), privacy: .public) imageSize=\(imageWidth, privacy: .public)x\(imageHeight, privacy: .public)")

        // Create rainbow palette
        var palette = [Color](repeating: Color(), count: 256)
        colorGradient(start: 0, end: 31, r1: 255, g1: 0, b1: 255, r2: 0, g2: 0, b2: 255, palette: &palette)
        colorGradient(start: 32, end: 63, r1: 0, g1: 0, b1: 255, r2: 0, g2: 255, b2: 255, palette: &palette)
        colorGradient(start: 64, end: 95, r1: 0, g1: 255, b1: 255, r2: 0, g2: 255, b2: 0, palette: &palette)
        colorGradient(start: 96, end: 127, r1: 0, g1: 255, b1: 0, r2: 127, g2: 255, b2: 0, palette: &palette)
        colorGradient(start: 128, end: 159, r1: 127, g1: 255, b1: 0, r2: 255, g2: 255, b2: 0, palette: &palette)
        colorGradient(start: 160, end: 191, r1: 255, g1: 255, b1: 0, r2: 255, g2: 127, b2: 0, palette: &palette)
        colorGradient(start: 192, end: 223, r1: 255, g1: 127, b1: 0, r2: 255, g2: 0, b2: 0, palette: &palette)
        colorGradient(start: 224, end: 255, r1: 255, g1: 0, b1: 0, r2: 255, g2: 0, b2: 255, palette: &palette)

        let loop = AnimationLoop(timeout: options.standardOptions.timeout, delay: options.standardOptions.delay)

        // For bounce mode: position and velocity state
        var x = 0
        var y = 0
        var sx = 1
        var sy = 1
        var canvas = canvas  // Make mutable copy for inout passing

        await loop.run { colorIndex in
            // Get current color (fixed or from palette)
            let currentColor = options.logoColor ?? palette[colorIndex % 256]

            // Determine position based on mode
            let (offsetX, offsetY) = computeOffset(
                mode: options.mode,
                x: &x, y: &y, sx: &sx, sy: &sy,
                colorIndex: colorIndex,
                displayWidth: options.standardOptions.width,
                displayHeight: options.standardOptions.height,
                imageWidth: imageWidth,
                imageHeight: imageHeight
            )

            // Clear canvas
            canvas.clear()

            // Draw mask at computed offset
            drawMask(
                offsetX: offsetX,
                offsetY: offsetY,
                color: currentColor,
                width: options.standardOptions.width,
                height: options.standardOptions.height,
                mask: mask,
                canvas: &canvas
            )

            canvas.setOffset(x: options.standardOptions.xoff, y: options.standardOptions.yoff, z: options.standardOptions.layer)
            canvas.send()
        }
    }

    private static let imagePadding = 3

    private static func combineMasks(
        masks: [MaskData],
        orientation: GrayscaleOrientation
    ) -> MaskData {
        guard !masks.isEmpty else { return MaskData(pixels: [], width: 0, height: 0) }
        guard masks.count > 1 else { return masks[0] }

        switch orientation {
        case .horizontal:
            let combinedWidth = masks.map(\.width).reduce(0, +) + (masks.count - 1) * imagePadding
            let combinedHeight = masks.map(\.height).max() ?? 0
            var combined = [[UInt8]](repeating: [UInt8](repeating: 255, count: combinedWidth), count: combinedHeight)
            var xCursor = 0
            for maskData in masks {
                let yOffset = (combinedHeight - maskData.height) / 2
                for (pixelY, row) in maskData.pixels.enumerated() {
                    for (pixelX, value) in row.enumerated() {
                        combined[yOffset + pixelY][xCursor + pixelX] = value
                    }
                }
                xCursor += maskData.width + imagePadding
            }
            return MaskData(pixels: combined, width: combinedWidth, height: combinedHeight)

        case .vertical:
            let combinedWidth = masks.map(\.width).max() ?? 0
            let combinedHeight = masks.map(\.height).reduce(0, +) + (masks.count - 1) * imagePadding
            var combined = [[UInt8]](repeating: [UInt8](repeating: 255, count: combinedWidth), count: combinedHeight)
            var yCursor = 0
            for maskData in masks {
                let xOffset = (combinedWidth - maskData.width) / 2
                for (pixelY, row) in maskData.pixels.enumerated() {
                    for (pixelX, value) in row.enumerated() {
                        combined[yCursor + pixelY][xOffset + pixelX] = value
                    }
                }
                yCursor += maskData.height + imagePadding
            }
            return MaskData(pixels: combined, width: combinedWidth, height: combinedHeight)
        }
    }

    private static func computeOffset(
        mode: GrayscaleMode,
        x: inout Int,
        y: inout Int,
        sx: inout Int,
        sy: inout Int,
        colorIndex: Int,
        displayWidth: Int,
        displayHeight: Int,
        imageWidth: Int,
        imageHeight: Int
    ) -> (Int, Int) {
        switch mode {
        case .bounce:
            // Animate position, bouncing off edges every 8 frames
            if (colorIndex % 8) == 0 {
                let nextX = x + sx
                let nextY = y + sy

                // Bounce off left/right edges
                if nextX < 0 {
                    x = 0
                    sx = 1
                } else if nextX + imageWidth > displayWidth {
                    x = displayWidth - imageWidth
                    sx = -1
                } else {
                    x = nextX
                }

                // Bounce off top/bottom edges
                if nextY < 0 {
                    y = 0
                    sy = 1
                } else if nextY + imageHeight > displayHeight {
                    y = displayHeight - imageHeight
                    sy = -1
                } else {
                    y = nextY
                }
            }
            return (x, y)

        case .center:
            let offsetX = max(0, (displayWidth - imageWidth) / 2)
            let offsetY = max(0, (displayHeight - imageHeight) / 2)
            return (offsetX, offsetY)

        case .left:
            let offsetX = 0
            let offsetY = max(0, (displayHeight - imageHeight) / 2)
            return (offsetX, offsetY)

        case .right:
            let offsetX = max(0, displayWidth - imageWidth)
            let offsetY = max(0, (displayHeight - imageHeight) / 2)
            return (offsetX, offsetY)

        case .top:
            let offsetX = max(0, (displayWidth - imageWidth) / 2)
            let offsetY = 0
            return (offsetX, offsetY)

        case .bottom:
            let offsetX = max(0, (displayWidth - imageWidth) / 2)
            let offsetY = max(0, displayHeight - imageHeight)
            return (offsetX, offsetY)
        }
    }

    private static func drawMask(
        offsetX: Int,
        offsetY: Int,
        color: Color,
        width: Int,
        height: Int,
        mask: [[UInt8]],
        canvas: inout UDPFlaschenTaschen
    ) {
        for (pixelY, row) in mask.enumerated() {
            for (pixelX, grayValue) in row.enumerated() {
                // Skip white pixels (background/transparency)
                guard grayValue < 240 else { continue }

                // Apply color based on grayscale intensity
                // Dark pixels (low grayscale) get full color, light pixels get darker version
                let intensity = Float(255 - grayValue) / 255.0
                let pixelColor = Color(
                    r: UInt8(Float(color.r) * intensity),
                    g: UInt8(Float(color.g) * intensity),
                    b: UInt8(Float(color.b) * intensity)
                )

                // Place pixel on canvas with offset
                let screenX = offsetX + pixelX
                let screenY = offsetY + pixelY

                if screenX >= 0 && screenX < width && screenY >= 0 && screenY < height {
                    canvas.setPixel(x: screenX, y: screenY, color: pixelColor)
                }
            }
        }
    }

    // Color gradient helper (from SfLogoDemo)
    private static func colorGradient(
        start: Int,
        end: Int,
        r1: UInt8,
        g1: UInt8,
        b1: UInt8,
        r2: UInt8,
        g2: UInt8,
        b2: UInt8,
        palette: inout [Color]
    ) {
        let range = end - start
        for i in 0...range {
            let k = Float(i) / Float(range)
            let r = UInt8(Float(r1) + (Float(r2) - Float(r1)) * k)
            let g = UInt8(Float(g1) + (Float(g2) - Float(g1)) * k)
            let b = UInt8(Float(b1) + (Float(b2) - Float(b1)) * k)
            palette[start + i] = Color(r: r, g: g, b: b)
        }
    }
}
