// Text rendering - draws text using BDF fonts

import Foundation

/// Draw a single Unicode character at the specified position
/// Returns the advance width (how much to move x position forward)
public nonisolated func drawGlyph(
    canvas: UDPFlaschenTaschen,
    font: BDFFont,
    x: Int,
    y: Int,
    color: Color,
    backgroundColor: Color? = nil,
    codepoint: UInt32
) -> Int {
    guard let glyph = font.getGlyph(codepoint) else {
        return 0
    }

    let adjustedY = y - glyph.height - glyph.yOffset

    for row in 0..<glyph.height {
        let bitmapRow = glyph.bitmap[row]
        var mask: UInt64 = 1 << 63

        for col in 0..<glyph.deviceWidth {
            let pixelX = x + col
            let pixelY = adjustedY + row

            if bitmapRow & mask != 0 {
                canvas.setPixel(x: pixelX, y: pixelY, color: color)
            } else if let bgColor = backgroundColor {
                canvas.setPixel(x: pixelX, y: pixelY, color: bgColor)
            }

            mask >>= 1
        }
    }

    return glyph.deviceWidth
}

/// Draw horizontal text starting at position (x, y)
/// y position is the baseline of the font
/// Returns the total advance width
public nonisolated func drawText(
    canvas: UDPFlaschenTaschen,
    font: BDFFont,
    x: Int,
    y: Int,
    color: Color,
    backgroundColor: Color? = nil,
    text: String,
    letterSpacing: Int = 0
) -> Int {
    let startX = x
    var currentX = x

    for scalar in text.unicodeScalars {
        let advance = drawGlyph(
            canvas: canvas,
            font: font,
            x: currentX,
            y: y,
            color: color,
            backgroundColor: backgroundColor,
            codepoint: scalar.value
        )
        currentX += advance + letterSpacing
    }

    return currentX - startX
}

/// Draw vertical text starting at position (x, y)
/// y position is the baseline of the font
/// Text flows from top to bottom
/// Returns the total advance height
public nonisolated func drawVerticalText(
    canvas: UDPFlaschenTaschen,
    font: BDFFont,
    x: Int,
    y: Int,
    color: Color,
    backgroundColor: Color? = nil,
    text: String,
    letterSpacing: Int = 0
) -> Int {
    let startY = y
    var currentY = y

    for scalar in text.unicodeScalars {
        _ = drawGlyph(
            canvas: canvas,
            font: font,
            x: x,
            y: currentY,
            color: color,
            backgroundColor: backgroundColor,
            codepoint: scalar.value
        )
        currentY += font.fontHeight() + letterSpacing
    }

    return currentY - startY
}
