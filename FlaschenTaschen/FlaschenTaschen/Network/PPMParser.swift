// PPMParser.swift

import Foundation
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "PPMParser")

nonisolated struct PPMImage: Sendable {
    let width: Int
    let height: Int
    let pixels: [PixelColor]
    let offsetX: Int
    let offsetY: Int
    let layer: Int
}

enum PPMParseError: Error {
    case invalidMagicNumber
    case invalidFormat
    case invalidDimensions
    case insufficientData
    case invalidMetadata
}

nonisolated final class PPMParser {
    nonisolated static func parse(data: Data) throws -> PPMImage {
        let buffer = [UInt8](data)
        var offset = 0

        guard offset + 2 < buffer.count else { throw PPMParseError.invalidFormat }

        let magic = String(bytes: buffer[offset..<offset + 2], encoding: .ascii) ?? ""
        guard magic == "P6" else {
            logger.error("Invalid PPM magic number: \(magic)")
            throw PPMParseError.invalidMagicNumber
        }
        offset += 2

        skipWhitespaceAndComments(buffer: buffer, offset: &offset)

        let (width, newOffset1) = try parseNumber(buffer: buffer, offset: offset)
        offset = newOffset1
        skipWhitespaceAndComments(buffer: buffer, offset: &offset)

        let (height, newOffset2) = try parseNumber(buffer: buffer, offset: offset)
        offset = newOffset2
        skipWhitespaceAndComments(buffer: buffer, offset: &offset)

        var offsetX = 0
        var offsetY = 0
        var layer = 0

        // Parse metadata from header comments
        parseHeaderMetadata(buffer: buffer, offset: &offset, offsetX: &offsetX, offsetY: &offsetY, layer: &layer)

        let (maxValue, newOffset3) = try parseNumber(buffer: buffer, offset: offset)
        offset = newOffset3
        guard maxValue == 255 else {
            logger.error("Invalid color depth: \(maxValue), expected 255")
            throw PPMParseError.invalidFormat
        }

        skipWhitespace(buffer: buffer, offset: &offset)

        let expectedDataSize = width * height * 3
        guard offset + expectedDataSize <= buffer.count else {
            throw PPMParseError.insufficientData
        }

        var pixels: [PixelColor] = []
        for _ in 0..<(width * height) {
            guard offset + 3 <= buffer.count else { throw PPMParseError.insufficientData }
            let r = buffer[offset]
            let g = buffer[offset + 1]
            let b = buffer[offset + 2]
            pixels.append(PixelColor(id: 0, red: r, green: g, blue: b))
            offset += 3
        }

        // Check for metadata after RGB data (C++ extension)
        if offset < buffer.count {
            parseOffsetsFromData(buffer: buffer, offset: offset, offsetX: &offsetX, offsetY: &offsetY, layer: &layer)
        }

        logger.debug("PPM parsed: \(width, privacy: .public)x\(height, privacy: .public) offset=(\(offsetX, privacy: .public),\(offsetY, privacy: .public)) layer=\(layer, privacy: .public)")
        return PPMImage(width: width, height: height, pixels: pixels,
                       offsetX: offsetX, offsetY: offsetY, layer: layer)
    }

    private static func parseNumber(buffer: [UInt8], offset: Int) throws -> (Int, Int) {
        var current = offset
        while current < buffer.count && isWhitespace(buffer[current]) {
            current += 1
        }

        var numberStr = ""
        while current < buffer.count && isDigit(buffer[current]) {
            numberStr.append(Character(UnicodeScalar(buffer[current])))
            current += 1
        }

        guard let number = Int(numberStr), number > 0 else {
            throw PPMParseError.invalidFormat
        }

        return (number, current)
    }

    private static func skipWhitespaceAndComments(buffer: [UInt8], offset: inout Int) {
        while offset < buffer.count {
            skipWhitespace(buffer: buffer, offset: &offset)
            if offset >= buffer.count { break }

            if buffer[offset] == UInt8(ascii: "#") {
                // Skip entire comment line
                while offset < buffer.count && buffer[offset] != UInt8(ascii: "\n") {
                    offset += 1
                }
                if offset < buffer.count { offset += 1 }  // Skip newline
                // Continue to next iteration to handle multiple comments
            } else {
                break
            }
        }
    }

    private static func parseHeaderMetadata(buffer: [UInt8], offset: inout Int, offsetX: inout Int, offsetY: inout Int, layer: inout Int) {
        // Loop through all comments in header looking for #FT: metadata
        while offset < buffer.count && buffer[offset] == UInt8(ascii: "#") {
            offset += 1

            var line = ""
            while offset < buffer.count && buffer[offset] != UInt8(ascii: "\n") {
                line.append(Character(UnicodeScalar(buffer[offset])))
                offset += 1
            }
            if offset < buffer.count { offset += 1 }

            // Check if this is an FT comment
            if line.hasPrefix("FT:") {
                parseOffsets(line: String(line.dropFirst(3)), offsetX: &offsetX, offsetY: &offsetY, layer: &layer)
            }

            skipWhitespace(buffer: buffer, offset: &offset)
        }
    }

    private static func parseOffsets(line: String, offsetX: inout Int, offsetY: inout Int, layer: inout Int) {
        let components = line.split(separator: " ").compactMap { Int($0) }
        if components.count >= 1 {
            offsetX = components[0]
        }
        if components.count >= 2 {
            offsetY = components[1]
        }
        if components.count >= 3 {
            layer = components[2]
        }
    }

    private static func parseOffsetsFromData(buffer: [UInt8], offset: Int, offsetX: inout Int, offsetY: inout Int, layer: inout Int) {
        var current = offset

        // Try to read x offset
        if let x = readNextNumber(buffer: buffer, offset: &current) {
            offsetX = x
        } else {
            return
        }

        // Try to read y offset
        if let y = readNextNumber(buffer: buffer, offset: &current) {
            offsetY = y
        } else {
            return
        }

        // Try to read z offset (layer)
        if let z = readNextNumber(buffer: buffer, offset: &current) {
            layer = z
        }
    }

    private static func readNextNumber(buffer: [UInt8], offset: inout Int) -> Int? {
        // Skip whitespace and comments
        while offset < buffer.count {
            skipWhitespace(buffer: buffer, offset: &offset)
            if offset >= buffer.count { break }

            if buffer[offset] == UInt8(ascii: "#") {
                // Skip to end of comment line
                while offset < buffer.count && buffer[offset] != UInt8(ascii: "\n") {
                    offset += 1
                }
                if offset < buffer.count { offset += 1 }
            } else {
                break
            }
        }

        if offset >= buffer.count { return nil }

        var numberStr = ""
        // Handle optional minus sign for negative numbers
        if buffer[offset] == UInt8(ascii: "-") {
            numberStr.append("-")
            offset += 1
        }

        while offset < buffer.count && isDigit(buffer[offset]) {
            numberStr.append(Character(UnicodeScalar(buffer[offset])))
            offset += 1
        }

        // Ensure we have at least one digit (not just a minus sign)
        guard !numberStr.isEmpty && numberStr != "-" else { return nil }
        return Int(numberStr)
    }

    private static func skipWhitespace(buffer: [UInt8], offset: inout Int) {
        while offset < buffer.count && isWhitespace(buffer[offset]) {
            offset += 1
        }
    }

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") ||
        byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r")
    }

    private static func isDigit(_ byte: UInt8) -> Bool {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9")
    }
}
