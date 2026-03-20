// BDF font file parser - Ported from bdf-font.cc
// Loads bitmap distribution format fonts for text rendering

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "BDFFont")

/// Single glyph (character) from a BDF font
public nonisolated struct Glyph: Sendable {
    public let deviceWidth: Int
    public let deviceHeight: Int
    public let width: Int
    public let height: Int
    public let xOffset: Int
    public let yOffset: Int
    public let bitmap: [UInt64]  // bitmap data, one row per element

    nonisolated init(deviceWidth: Int, deviceHeight: Int, width: Int, height: Int,
                     xOffset: Int, yOffset: Int, bitmap: [UInt64]) {
        self.deviceWidth = deviceWidth
        self.deviceHeight = deviceHeight
        self.width = width
        self.height = height
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.bitmap = bitmap
    }
}

/// BDF font - contains glyphs indexed by Unicode codepoint
public class BDFFont: @unchecked Sendable {
    private var height: Int = -1
    private var baseline: Int = 0
    private var glyphs: [UInt32: Glyph] = [:]

    private static let kUnicodeReplacementCodepoint: UInt32 = 0xFFFD

    public init() {}

    public func loadFont(path: String) -> Bool {
        guard let file = try? String(contentsOfFile: path, encoding: .utf8) else {
            logger.error("Failed to open font file: \(path, privacy: .public)")
            return false
        }

        let lines = file.split(separator: "\n", omittingEmptySubsequences: false)
        var currentCodepoint: UInt32 = 0
        var glyph = GlyphBuilder()
        var row: Int = -1

        for line in lines {
            let lineStr = String(line)

            // Parse FONTBOUNDINGBOX
            if lineStr.hasPrefix("FONTBOUNDINGBOX ") {
                let parts = Array(lineStr.split(separator: " ").dropFirst())
                if parts.count >= 4,
                   let h = Int(parts[1]),
                   let baseline = Int(parts[3]) {
                    height = h
                    self.baseline = baseline + h
                }
            }

            // Parse ENCODING
            if lineStr.hasPrefix("ENCODING ") {
                let parts = Array(lineStr.split(separator: " ").dropFirst())
                if let cp = UInt32(parts.first ?? "") {
                    currentCodepoint = cp
                }
            }

            // Parse DWIDTH
            if lineStr.hasPrefix("DWIDTH ") {
                let parts = Array(lineStr.split(separator: " ").dropFirst())
                if parts.count >= 2,
                   let dw = Int(parts[0]),
                   let dh = Int(parts[1]) {
                    glyph.deviceWidth = dw
                    glyph.deviceHeight = dh
                }
            }

            // Parse BBX (bounding box)
            if lineStr.hasPrefix("BBX ") {
                let parts = Array(lineStr.split(separator: " ").dropFirst())
                if parts.count >= 4,
                   let w = Int(parts[0]),
                   let h = Int(parts[1]),
                   let xOff = Int(parts[2]),
                   let yOff = Int(parts[3]) {
                    glyph.width = w
                    glyph.height = h
                    glyph.xOffset = xOff
                    glyph.yOffset = yOff
                    glyph.bitmapShift = 64 - ((w + 7) / 8) * 8 - xOff
                    row = -1
                }
            }

            // Start of bitmap data
            if lineStr.hasPrefix("BITMAP") {
                row = 0
            }

            // Parse bitmap rows
            if row >= 0 && row < glyph.height && !lineStr.hasPrefix("ENDCHAR") {
                if let val = UInt64(lineStr.trimmingCharacters(in: .whitespaces), radix: 16) {
                    let shifted = val << glyph.bitmapShift
                    glyph.bitmap.append(shifted)
                    row += 1
                }
            }

            // End of glyph
            if lineStr.hasPrefix("ENDCHAR") {
                if row == glyph.height && glyph.height > 0 {
                    let g = Glyph(deviceWidth: glyph.deviceWidth,
                                 deviceHeight: glyph.deviceHeight,
                                 width: glyph.width,
                                 height: glyph.height,
                                 xOffset: glyph.xOffset,
                                 yOffset: glyph.yOffset,
                                 bitmap: glyph.bitmap)
                    glyphs[currentCodepoint] = g
                }
                glyph = GlyphBuilder()
                row = -1
            }
        }

        let success = height >= 0
        logger.debug("Loaded font: \(path, privacy: .public), height=\(self.height, privacy: .public), glyphs=\(self.glyphs.count, privacy: .public)")
        return success
    }

    public func fontHeight() -> Int {
        height
    }

    public func fontBaseline() -> Int {
        baseline
    }

    public func characterWidth(_ codepoint: UInt32) -> Int {
        glyphs[codepoint]?.width ?? -1
    }

    public func createOutlineFont() -> BDFFont {
        let outline = BDFFont()
        outline.height = height + 2
        outline.baseline = baseline + 1

        for (codepoint, glyph) in glyphs {
            let outlineGlyph = createOutlineGlyph(glyph)
            outline.glyphs[codepoint] = outlineGlyph
        }

        return outline
    }

    public func getGlyph(_ codepoint: UInt32) -> Glyph? {
        glyphs[codepoint] ?? glyphs[BDFFont.kUnicodeReplacementCodepoint]
    }

    private func createOutlineGlyph(_ glyph: Glyph) -> Glyph {
        let kBorder = 1
        let newHeight = glyph.height + 2 * kBorder
        var bitmap = Array(repeating: UInt64(0), count: newHeight)

        let fillPattern: UInt64 = 0b111
        let startMask: UInt64 = 0b010

        // Fill border
        for h in 0..<glyph.height {
            var fill = fillPattern
            let origBitmap = glyph.bitmap[h] >> UInt64(kBorder)
            var m = startMask
            while m != 0 {
                if origBitmap & m != 0 {
                    if h + kBorder - 1 < bitmap.count {
                        bitmap[h + kBorder - 1] |= fill
                    }
                    if h + kBorder < bitmap.count {
                        bitmap[h + kBorder] |= fill
                    }
                    if h + kBorder + 1 < bitmap.count {
                        bitmap[h + kBorder + 1] |= fill
                    }
                }
                fill <<= 1
                m <<= 1
            }
        }

        // Remove original
        for h in 0..<glyph.height {
            let origBitmap = glyph.bitmap[h] >> UInt64(kBorder)
            if h + kBorder < bitmap.count {
                bitmap[h + kBorder] &= ~origBitmap
            }
        }

        return Glyph(deviceWidth: glyph.deviceWidth + 2,
                    deviceHeight: newHeight,
                    width: glyph.width + 2,
                    height: newHeight,
                    xOffset: glyph.xOffset - kBorder,
                    yOffset: glyph.yOffset - kBorder,
                    bitmap: bitmap)
    }

    // Helper struct for building glyphs during parsing
    private nonisolated struct GlyphBuilder {
        var deviceWidth: Int = 0
        var deviceHeight: Int = 0
        var width: Int = 0
        var height: Int = 0
        var xOffset: Int = 0
        var yOffset: Int = 0
        var bitmap: [UInt64] = []
        var bitmapShift: Int = 0
    }
}
