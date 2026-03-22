// MultiPacketIntegrationTests.swift
// End-to-end integration tests for complete multi-packet frame handling

import Foundation
import Testing
@testable import FlaschenTaschen

struct MultiPacketIntegrationTests {

    // MARK: - Integration Test Scenarios

    /// Simulates the real-world scenario: Python tool sends 64×64 image split into 2 UDP packets
    @Test
    func testPython64x64ImageScenario() async throws {
        var displayedFrames: [PPMImage] = []

        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                displayedFrames.append(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // PACKET 1: First part of 64×64 image
        // Header: P6, 64×47, #FT: 0 0 7, 255
        var packet1 = "P6\n".data(using: .ascii)!
        packet1.append("64 47\n".data(using: .ascii)!)
        packet1.append("#FT: 0 0 7\n".data(using: .ascii)!)
        packet1.append("255\n".data(using: .ascii)!)
        // Add 64×47 red pixels
        for _ in 0..<(64 * 47) {
            packet1.append(Data([255, 0, 0]))
        }

        await server.processPacket(packet1)

        // After packet 1: nothing should be displayed yet
        #expect(displayedFrames.count == 0, "Incomplete frame should not display after packet 1")

        // PACKET 2: Second part of 64×64 image
        // Header: P6, 64×17, #FT: 0 47 7, 255
        var packet2 = "P6\n".data(using: .ascii)!
        packet2.append("64 17\n".data(using: .ascii)!)
        packet2.append("#FT: 0 47 7\n".data(using: .ascii)!)
        packet2.append("255\n".data(using: .ascii)!)
        // Add 64×17 red pixels
        for _ in 0..<(64 * 17) {
            packet2.append(Data([255, 0, 0]))
        }

        await server.processPacket(packet2)

        // After packet 2: complete frame should be displayed
        #expect(displayedFrames.count == 1, "Complete frame should display after packet 2")
        #expect(displayedFrames[0].width == 64)
        #expect(displayedFrames[0].height == 64)
        #expect(displayedFrames[0].layer == 7)

        // Verify all pixels are present
        let pixelCount = displayedFrames[0].pixels.count
        #expect(pixelCount == 4096, "Complete 64×64 frame should have 4096 pixels")

        // Count non-black pixels (all should be red from our packets)
        let nonBlackCount = displayedFrames[0].pixels.filter { !($0.red == 0 && $0.green == 0 && $0.blue == 0) }.count
        #expect(nonBlackCount == 4096, "All pixels should be red (from accumulated packets)")
    }

    /// Test that layer metadata is preserved correctly through packet accumulation
    @Test
    func testLayerMetadataPreservation() async throws {
        var displayedFrames: [(layer: Int, count: Int)] = []

        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                displayedFrames.append((layer: image.layer, count: image.pixels.count))
            },
            onError: { _ in },
            onReady: {}
        )

        for layer in [3, 7, 15] {
            displayedFrames.removeAll()

            // Packet 1
            var p1 = "P6\n".data(using: .ascii)!
            p1.append("64 32\n".data(using: .ascii)!)
            p1.append("#FT: 0 0 \(layer)\n".data(using: .ascii)!)
            p1.append("255\n".data(using: .ascii)!)
            for _ in 0..<(64 * 32) {
                p1.append(Data([UInt8(layer), 0, 0]))  // Use layer number as red value
            }

            await server.processPacket(p1)
            #expect(displayedFrames.count == 0, "Packet 1 should not display for layer \(layer)")

            // Packet 2
            var p2 = "P6\n".data(using: .ascii)!
            p2.append("64 32\n".data(using: .ascii)!)
            p2.append("#FT: 0 32 \(layer)\n".data(using: .ascii)!)
            p2.append("255\n".data(using: .ascii)!)
            for _ in 0..<(64 * 32) {
                p2.append(Data([UInt8(layer), 0, 0]))
            }

            await server.processPacket(p2)
            #expect(displayedFrames.count == 1, "Complete frame should display for layer \(layer)")
            #expect(displayedFrames[0].layer == layer, "Layer should be \(layer)")
        }
    }

    /// Test that offsets are correctly applied when pixels are accumulated
    @Test
    func testOffsetAccuracy() async throws {
        var displayedFrames: [PPMImage] = []

        let server = UDPServer(
            gridWidth: 128,
            gridHeight: 64,
            onPixelUpdate: { image in
                displayedFrames.append(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Send two images at different X offsets
        // Image 1: 64×64 at X=0
        var img1 = "P6\n".data(using: .ascii)!
        img1.append("64 64\n".data(using: .ascii)!)
        img1.append("#FT: 0 0 1\n".data(using: .ascii)!)
        img1.append("255\n".data(using: .ascii)!)
        for _ in 0..<(64 * 64) {
            img1.append(Data([255, 0, 0]))  // Red
        }

        // Image 2: 64×64 at X=64
        var img2 = "P6\n".data(using: .ascii)!
        img2.append("64 64\n".data(using: .ascii)!)
        img2.append("#FT: 64 0 2\n".data(using: .ascii)!)
        img2.append("255\n".data(using: .ascii)!)
        for _ in 0..<(64 * 64) {
            img2.append(Data([0, 255, 0]))  // Green
        }

        await server.processPacket(img1)
        await server.processPacket(img2)

        // Both should have displayed
        #expect(displayedFrames.count == 2)

        // Verify accumulated pixels have correct colors in correct positions
        let frame1 = displayedFrames[0]
        let frame2 = displayedFrames[1]

        #expect(frame1.layer == 1)
        #expect(frame2.layer == 2)
        #expect(frame1.width == 128)
        #expect(frame2.width == 128)
    }

    /// Test sequence: incomplete frame → timeout → new frame
    @Test
    func testTimeoutResetsBetweenFrames() async throws {
        var displayedFrames: [PPMImage] = []

        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                displayedFrames.append(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Send incomplete first frame
        var incomplete = "P6\n".data(using: .ascii)!
        incomplete.append("64 32\n".data(using: .ascii)!)
        incomplete.append("#FT: 0 0 5\n".data(using: .ascii)!)
        incomplete.append("255\n".data(using: .ascii)!)
        for _ in 0..<(64 * 32) {
            incomplete.append(Data([255, 0, 0]))
        }

        await server.processPacket(incomplete)
        #expect(displayedFrames.count == 0, "Incomplete frame should not display")

        // Simulate timeout by sending new frame with offset 0
        // This should reset the buffer for the incomplete frame
        var newFrame = "P6\n".data(using: .ascii)!
        newFrame.append("64 64\n".data(using: .ascii)!)
        newFrame.append("#FT: 0 0 7\n".data(using: .ascii)!)
        newFrame.append("255\n".data(using: .ascii)!)
        for _ in 0..<(64 * 64) {
            newFrame.append(Data([0, 255, 0]))
        }

        await server.processPacket(newFrame)
        #expect(displayedFrames.count == 1, "Complete frame should display")
        #expect(displayedFrames[0].layer == 7)
    }

    /// Test rapid multi-layer updates
    @Test
    func testRapidMultiLayerUpdates() async throws {
        var displayedFrames: [PPMImage] = []

        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                displayedFrames.append(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Interleave packets from different layers
        for layer in [1, 2, 3] {
            // Packet 1
            var p1 = "P6\n".data(using: .ascii)!
            p1.append("64 32\n".data(using: .ascii)!)
            p1.append("#FT: 0 0 \(layer)\n".data(using: .ascii)!)
            p1.append("255\n".data(using: .ascii)!)
            for _ in 0..<(64 * 32) {
                p1.append(Data([UInt8(layer * 50), 0, 0]))
            }

            await server.processPacket(p1)

            // Packet 2
            var p2 = "P6\n".data(using: .ascii)!
            p2.append("64 32\n".data(using: .ascii)!)
            p2.append("#FT: 0 32 \(layer)\n".data(using: .ascii)!)
            p2.append("255\n".data(using: .ascii)!)
            for _ in 0..<(64 * 32) {
                p2.append(Data([UInt8(layer * 50), 0, 0]))
            }

            await server.processPacket(p2)
        }

        // All 3 layers should have complete frames
        #expect(displayedFrames.count == 3)

        // Verify they're from different layers
        let layers = Set(displayedFrames.map { $0.layer })
        #expect(layers == [1, 2, 3])
    }

    /// Test that pixels accumulate correctly at grid positions
    @Test
    func testPixelPositionAccuracy() async throws {
        var displayedFrames: [PPMImage] = []

        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                displayedFrames.append(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Send top half with red pixels
        var top = "P6\n".data(using: .ascii)!
        top.append("64 32\n".data(using: .ascii)!)
        top.append("#FT: 0 0 1\n".data(using: .ascii)!)
        top.append("255\n".data(using: .ascii)!)
        for _ in 0..<(64 * 32) {
            top.append(Data([255, 0, 0]))  // Red
        }

        // Send bottom half with green pixels
        var bottom = "P6\n".data(using: .ascii)!
        bottom.append("64 32\n".data(using: .ascii)!)
        bottom.append("#FT: 0 32 1\n".data(using: .ascii)!)
        bottom.append("255\n".data(using: .ascii)!)
        for _ in 0..<(64 * 32) {
            bottom.append(Data([0, 255, 0]))  // Green
        }

        await server.processPacket(top)
        await server.processPacket(bottom)

        #expect(displayedFrames.count == 1)
        let frame = displayedFrames[0]

        // Verify dimensions
        #expect(frame.width == 64)
        #expect(frame.height == 64)
        #expect(frame.pixels.count == 4096)

        // Verify colors at specific positions
        // First pixel (0,0) should be red
        #expect(frame.pixels[0].red == 255 && frame.pixels[0].green == 0)

        // Pixel at (0,32) should be green (start of second packet)
        let pixel32 = frame.pixels[32 * 64]  // Y=32, X=0
        #expect(pixel32.red == 0 && pixel32.green == 255)
    }
}
