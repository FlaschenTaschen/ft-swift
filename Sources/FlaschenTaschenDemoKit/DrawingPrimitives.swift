// Drawing primitives for Flaschen Taschen demos
// Includes line, circle, rectangle drawing algorithms

import Foundation

// MARK: - Line Drawing (Bresenham)

/// Draw a line from (x0, y0) to (x1, y1) using Bresenham's algorithm
public nonisolated func drawLine(
    x0: Int,
    y0: Int,
    x1: Int,
    y1: Int,
    color: Color,
    width: Int,
    height: Int,
    canvas: inout UDPFlaschenTaschen
) {
    var x = x0
    var y = y0
    let dx = abs(x1 - x0)
    let dy = abs(y1 - y0)
    let sx = x0 < x1 ? 1 : -1
    let sy = y0 < y1 ? 1 : -1
    var err = dx - dy

    while true {
        if x >= 0 && x < width && y >= 0 && y < height {
            canvas.setPixel(x: x, y: y, color: color)
        }

        if x == x1 && y == y1 { break }

        let e2 = 2 * err
        if e2 > -dy {
            err -= dy
            x += sx
        }
        if e2 < dx {
            err += dx
            y += sy
        }
    }
}

// MARK: - Circle Drawing (Midpoint Circle Algorithm)

/// Draw a circle at (x0, y0) with given radius
public nonisolated func drawCircle(
    x0: Int,
    y0: Int,
    radius: Int,
    color: UInt8,
    width: Int,
    height: Int,
    pixels: inout [UInt8]
) {
    var x = radius
    var y = 0
    var radiusError = 1 - x

    while y <= x {
        setPixelInBuffer(x0: x + x0, y0: y + y0, color: color, width: width, height: height, pixels: &pixels)
        setPixelInBuffer(x0: y + x0, y0: x + y0, color: color, width: width, height: height, pixels: &pixels)
        setPixelInBuffer(x0: -x + x0, y0: y + y0, color: color, width: width, height: height, pixels: &pixels)
        setPixelInBuffer(x0: -y + x0, y0: x + y0, color: color, width: width, height: height, pixels: &pixels)
        setPixelInBuffer(x0: -x + x0, y0: -y + y0, color: color, width: width, height: height, pixels: &pixels)
        setPixelInBuffer(x0: -y + x0, y0: -x + y0, color: color, width: width, height: height, pixels: &pixels)
        setPixelInBuffer(x0: x + x0, y0: -y + y0, color: color, width: width, height: height, pixels: &pixels)
        setPixelInBuffer(x0: y + x0, y0: -x + y0, color: color, width: width, height: height, pixels: &pixels)

        y += 1
        if radiusError < 0 {
            radiusError += 2 * y + 1
        } else {
            x -= 1
            radiusError += 2 * (y - x + 1)
        }
    }
}

// MARK: - Rectangle Drawing

/// Draw a rectangle outline from (x1, y1) to (x2, y2)
public nonisolated func drawBox(
    x1: Int,
    y1: Int,
    x2: Int,
    y2: Int,
    color: UInt8,
    width: Int,
    height: Int,
    pixels: inout [UInt8]
) {
    // Draw horizontal lines
    for x in x1...x2 {
        if y1 < height { pixels[y1 * width + x] = color }
        if y2 < height { pixels[y2 * width + x] = color }
    }
    // Draw vertical lines
    for y in y1...y2 {
        pixels[y * width + x1] = color
        pixels[y * width + x2] = color
    }
}

/// Draw a filled rectangle from (x1, y1) to (x2, y2)
public nonisolated func fillRectangle(
    x1: Int,
    y1: Int,
    x2: Int,
    y2: Int,
    color: UInt8,
    width: Int,
    height: Int,
    pixels: inout [UInt8]
) {
    for y in y1...y2 {
        guard y >= 0 && y < height else { continue }
        for x in x1...x2 {
            guard x >= 0 && x < width else { continue }
            pixels[y * width + x] = color
        }
    }
}

// MARK: - Pixel Buffer Helpers

/// Set a pixel in a raw byte buffer (for demos that work with pixel buffers directly)
private nonisolated func setPixelInBuffer(
    x0: Int,
    y0: Int,
    color: UInt8,
    width: Int,
    height: Int,
    pixels: inout [UInt8]
) {
    if x0 >= 0 && x0 < width && y0 >= 0 && y0 < height {
        pixels[y0 * width + x0] = color
    }
}
