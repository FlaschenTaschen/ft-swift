// PPMParserTests.swift
// Comprehensive tests for PPM parsing with multi-packet support

import Foundation
import Testing
@testable import FlaschenTaschen

struct PPMParserTests {

    // MARK: - Helper Functions

    /// Create a minimal PPM P6 image with custom header and pixel data
    private func createPPMImage(
        width: Int,
        height: Int,
        headerComment: String? = nil,
        pixelData: [UInt8]? = nil
    ) -> Data {
        var ppm = "P6\n".data(using: .ascii)!
        ppm.append("\(width) \(height)\n".data(using: .ascii)!)

        if let comment = headerComment {
            ppm.append("#\(comment)\n".data(using: .ascii)!)
        }

        ppm.append("255\n".data(using: .ascii)!)

        if let pixels = pixelData {
            ppm.append(Data(pixels))
        } else {
            // Default: solid red pixels
            let redPixel: [UInt8] = [255, 0, 0]
            for _ in 0..<(width * height) {
                ppm.append(Data(redPixel))
            }
        }

        return ppm
    }

    /// Create test pixels (RGB bytes)
    private func createPixels(count: Int, r: UInt8 = 255, g: UInt8 = 0, b: UInt8 = 0) -> [UInt8] {
        var pixels: [UInt8] = []
        for _ in 0..<count {
            pixels.append(contentsOf: [r, g, b])
        }
        return pixels
    }

    // MARK: - Basic PPM Parsing

    @Test
    func testParseBasicPPM() throws {
        let ppm = createPPMImage(width: 8, height: 4)
        let image = try PPMParser.parse(data: ppm)

        #expect(image.width == 8)
        #expect(image.height == 4)
        #expect(image.pixels.count == 32)
        #expect(image.offsetX == 0)
        #expect(image.offsetY == 0)
        #expect(image.layer == 0)
    }

    // MARK: - FT Metadata Parsing

    @Test
    func testParseFTMetadataInHeader() throws {
        let ppm = createPPMImage(width: 64, height: 47, headerComment: "FT: 0 0 7")
        let image = try PPMParser.parse(data: ppm)

        #expect(image.width == 64)
        #expect(image.height == 47)
        #expect(image.offsetX == 0)
        #expect(image.offsetY == 0)
        #expect(image.layer == 7)
    }

    @Test
    func testParseFTMetadataWithOffsets() throws {
        let ppm = createPPMImage(width: 64, height: 17, headerComment: "FT: 0 47 7")
        let image = try PPMParser.parse(data: ppm)

        #expect(image.offsetX == 0)
        #expect(image.offsetY == 47)
        #expect(image.layer == 7)
    }

    @Test
    func testParseFTMetadataWithXOffset() throws {
        let ppm = createPPMImage(width: 32, height: 32, headerComment: "FT: 10 5 3")
        let image = try PPMParser.parse(data: ppm)

        #expect(image.offsetX == 10)
        #expect(image.offsetY == 5)
        #expect(image.layer == 3)
    }

    // MARK: - Multi-Packet Scenarios

    @Test
    func testFirstPacketOf64x64Image() throws {
        // First packet of a 64×64 image split into 2 packets
        // Packet 1: width=64, height=47, offset_y=0, layer=7
        let ppm = createPPMImage(
            width: 64,
            height: 47,
            headerComment: "FT: 0 0 7"
        )
        let image = try PPMParser.parse(data: ppm)

        #expect(image.width == 64)
        #expect(image.height == 47)
        #expect(image.offsetX == 0)
        #expect(image.offsetY == 0)
        #expect(image.layer == 7)
        #expect(image.pixels.count == 64 * 47)
    }

    @Test
    func testSecondPacketOf64x64Image() throws {
        // Second packet of a 64×64 image
        // Packet 2: width=64, height=17, offset_y=47, layer=7
        let ppm = createPPMImage(
            width: 64,
            height: 17,
            headerComment: "FT: 0 47 7"
        )
        let image = try PPMParser.parse(data: ppm)

        #expect(image.width == 64)
        #expect(image.height == 17)
        #expect(image.offsetX == 0)
        #expect(image.offsetY == 47)
        #expect(image.layer == 7)
        #expect(image.pixels.count == 64 * 17)
    }

    @Test
    func testLargeImageMultiplePackets() throws {
        // Simulating a 320×64 image that would be split into multiple packets
        let ppm = createPPMImage(
            width: 320,
            height: 32,
            headerComment: "FT: 0 0 7"
        )
        let image = try PPMParser.parse(data: ppm)

        #expect(image.width == 320)
        #expect(image.height == 32)
        #expect(image.offsetX == 0)
        #expect(image.offsetY == 0)
        #expect(image.layer == 7)
    }

    // MARK: - Edge Cases

    @Test
    func testParseWithoutMetadata() throws {
        let ppm = createPPMImage(width: 64, height: 64)
        let image = try PPMParser.parse(data: ppm)

        // Should use defaults
        #expect(image.offsetX == 0)
        #expect(image.offsetY == 0)
        #expect(image.layer == 0)
    }

    @Test
    func testParseMultipleComments() throws {
        var ppm = "P6\n".data(using: .ascii)!
        ppm.append("64 47\n".data(using: .ascii)!)
        ppm.append("# Author: test\n".data(using: .ascii)!)
        ppm.append("#FT: 0 0 7\n".data(using: .ascii)!)
        ppm.append("255\n".data(using: .ascii)!)
        ppm.append(Data(createPixels(count: 64 * 47)))

        let image = try PPMParser.parse(data: ppm)

        #expect(image.offsetX == 0)
        #expect(image.offsetY == 0)
        #expect(image.layer == 7)
    }

    @Test
    func testParseZeroOffsets() throws {
        let ppm = createPPMImage(width: 64, height: 64, headerComment: "FT: 0 0 0")
        let image = try PPMParser.parse(data: ppm)

        #expect(image.offsetX == 0)
        #expect(image.offsetY == 0)
        #expect(image.layer == 0)
    }

    @Test
    func testParseLargeOffsets() throws {
        let ppm = createPPMImage(width: 64, height: 64, headerComment: "FT: 100 200 15")
        let image = try PPMParser.parse(data: ppm)

        #expect(image.offsetX == 100)
        #expect(image.offsetY == 200)
        #expect(image.layer == 15)
    }

    @Test
    func testParseMetadataWithExtraSpaces() throws {
        let ppm = createPPMImage(width: 64, height: 64, headerComment: "FT:   5   10   7")
        let image = try PPMParser.parse(data: ppm)

        #expect(image.offsetX == 5)
        #expect(image.offsetY == 10)
        #expect(image.layer == 7)
    }

    // MARK: - Pixel Data Verification

    @Test
    func testPixelDataIsPreserved() throws {
        let redPixels = createPixels(count: 64, r: 255, g: 0, b: 0)
        let ppm = createPPMImage(width: 8, height: 8, pixelData: redPixels)
        let image = try PPMParser.parse(data: ppm)

        #expect(image.pixels.count == 64)
        for pixel in image.pixels {
            #expect(pixel.red == 255)
            #expect(pixel.green == 0)
            #expect(pixel.blue == 0)
        }
    }

    @Test
    func testMulticolorPixels() throws {
        var pixels: [UInt8] = []
        pixels.append(contentsOf: [255, 0, 0])   // Red
        pixels.append(contentsOf: [0, 255, 0])   // Green
        pixels.append(contentsOf: [0, 0, 255])   // Blue
        pixels.append(contentsOf: [255, 255, 0]) // Yellow

        let ppm = createPPMImage(width: 2, height: 2, pixelData: pixels)
        let image = try PPMParser.parse(data: ppm)

        #expect(image.pixels[0].red == 255 && image.pixels[0].green == 0 && image.pixels[0].blue == 0)
        #expect(image.pixels[1].red == 0 && image.pixels[1].green == 255 && image.pixels[1].blue == 0)
        #expect(image.pixels[2].red == 0 && image.pixels[2].green == 0 && image.pixels[2].blue == 255)
        #expect(image.pixels[3].red == 255 && image.pixels[3].green == 255 && image.pixels[3].blue == 0)
    }
}
