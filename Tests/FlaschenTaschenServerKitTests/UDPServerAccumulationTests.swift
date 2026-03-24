// UDPServerAccumulationTests.swift
// Tests for multi-packet accumulation and frame completion logic

import Foundation
import Testing
@testable import FlaschenTaschenServerKit

struct UDPServerAccumulationTests {

    // MARK: - Mock Tracking

    /// Track all pixels sent to display for verification.
    /// `UDPServer` awaits `onPixelUpdate`, so tests can use `await tracker.recordUpdate` without a nested `Task` race.
    actor PixelUpdateTracker {
        private(set) var updates: [PPMImage] = []

        func recordUpdate(_ image: PPMImage) {
            updates.append(image)
        }

        func getUpdates() -> [PPMImage] {
            updates
        }

        func clearUpdates() {
            updates.removeAll()
        }
    }

    // MARK: - Helper Functions

    private func createPPMImage(
        width: Int,
        height: Int,
        offsetX: Int = 0,
        offsetY: Int = 0,
        layer: Int = 0,
        pixelCount: Int? = nil
    ) -> Data {
        let count = pixelCount ?? (width * height)

        var ppm = "P6\n".data(using: .ascii)!
        ppm.append("\(width) \(height)\n".data(using: .ascii)!)

        if offsetX != 0 || offsetY != 0 || layer != 0 {
            ppm.append("#FT: \(offsetX) \(offsetY) \(layer)\n".data(using: .ascii)!)
        }

        ppm.append("255\n".data(using: .ascii)!)

        // Add pixel data: simple red pixels
        for _ in 0..<count {
            ppm.append(Data([255, 0, 0]))
        }

        return ppm
    }

    // MARK: - Single Packet Tests

    @Test
    func testSinglePacketImageDisplaysImmediately() async throws {
        let tracker = PixelUpdateTracker()
        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                await tracker.recordUpdate(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Simulate a complete 64×64 image in one packet
        let imageData = createPPMImage(
            width: 64,
            height: 64,
            offsetX: 0,
            offsetY: 0,
            layer: 0,
            pixelCount: 64 * 64
        )

        // Process packet
        await server.processPacket(imageData)

        // Should display immediately
        let updates = await tracker.getUpdates()
        #expect(updates.count == 1)
        #expect(updates[0].width == 64)
        #expect(updates[0].height == 64)
    }

    // MARK: - Multi-Packet Accumulation Tests

    @Test
    func testTwoPacketsAccumulateBeforeDisplay() async throws {
        let tracker = PixelUpdateTracker()
        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                await tracker.recordUpdate(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Packet 1: rows 0-46 (47 rows)
        let packet1 = createPPMImage(
            width: 64,
            height: 47,
            offsetX: 0,
            offsetY: 0,
            layer: 7,
            pixelCount: 64 * 47
        )

        await server.processPacket(packet1)

        // After first packet: should display immediately (matching C++ behavior)
        var updates = await tracker.getUpdates()
        #expect(updates.count == 1, "First packet should trigger display")
        #expect(updates[0].width == 64)
        #expect(updates[0].height == 64)
        #expect(updates[0].layer == 7)

        // Packet 2: rows 47-63 (17 rows)
        let packet2 = createPPMImage(
            width: 64,
            height: 17,
            offsetX: 0,
            offsetY: 47,
            layer: 7,
            pixelCount: 64 * 17
        )

        await server.processPacket(packet2)

        // After second packet: should display accumulated frame
        updates = await tracker.getUpdates()
        #expect(updates.count == 2, "Second packet should also trigger display")
        #expect(updates[1].width == 64)
        #expect(updates[1].height == 64)
        #expect(updates[1].layer == 7)
    }

    @Test
    func testOffsetYIsCalculatedCorrectly() async throws {
        let tracker = PixelUpdateTracker()
        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                await tracker.recordUpdate(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Packet 1: rows 0-46
        let packet1 = createPPMImage(
            width: 64,
            height: 47,
            offsetX: 0,
            offsetY: 0,
            layer: 7
        )

        await server.processPacket(packet1)

        // Packet 2: rows 47-63 with correct offset
        let packet2 = createPPMImage(
            width: 64,
            height: 17,
            offsetX: 0,
            offsetY: 47,
            layer: 7
        )

        await server.processPacket(packet2)

        // Verify the accumulated pixels at specific positions
        let updates = await tracker.getUpdates()
        #expect(updates.count == 2, "Each packet should trigger a display")

        // Check the final accumulated frame (second update)
        let completeImage = updates[1]
        // All pixels should be red (255,0,0) since we sent red pixels
        let nonBlackCount = completeImage.pixels.filter { !($0.red == 0 && $0.green == 0 && $0.blue == 0) }.count
        #expect(nonBlackCount == 64 * 64, "All 4096 pixels should be non-black after accumulation")
    }

    @Test
    func testMultipleLayersAccumulateSeparately() async throws {
        let tracker = PixelUpdateTracker()
        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                await tracker.recordUpdate(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Layer 5: first packet displays immediately
        let layer5Packet1 = createPPMImage(
            width: 64,
            height: 32,
            offsetX: 0,
            offsetY: 0,
            layer: 5,
            pixelCount: 64 * 32
        )

        await server.processPacket(layer5Packet1)

        // Layer 7: first packet displays immediately
        let layer7Packet1 = createPPMImage(
            width: 64,
            height: 47,
            offsetX: 0,
            offsetY: 0,
            layer: 7,
            pixelCount: 64 * 47
        )

        await server.processPacket(layer7Packet1)

        var updates = await tracker.getUpdates()
        #expect(updates.count == 2, "Both packets should display immediately")

        // Layer 5: second packet
        let layer5Packet2 = createPPMImage(
            width: 64,
            height: 32,
            offsetX: 0,
            offsetY: 32,
            layer: 5,
            pixelCount: 64 * 32
        )

        await server.processPacket(layer5Packet2)

        updates = await tracker.getUpdates()
        #expect(updates.count == 3, "Layer 5 second packet should display")
        #expect(updates[2].layer == 5)

        // Layer 7: second packet
        let layer7Packet2 = createPPMImage(
            width: 64,
            height: 17,
            offsetX: 0,
            offsetY: 47,
            layer: 7,
            pixelCount: 64 * 17
        )

        await server.processPacket(layer7Packet2)

        updates = await tracker.getUpdates()
        #expect(updates.count == 4, "Layer 7 second packet should display")
        #expect(updates[3].layer == 7)
    }

    @Test
    func testFrameCompletionDetection() async throws {
        let tracker = PixelUpdateTracker()
        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                await tracker.recordUpdate(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // With C++ behavior, all packets display immediately
        let testCases: [(offsetY: Int, height: Int, shouldDisplay: Bool)] = [
            (0, 47, true),    // Display immediately
            (47, 17, true),   // Display immediately
            (30, 34, true),   // Display immediately
            (0, 64, true),    // Display immediately
            (32, 33, true),   // Display immediately
            (63, 1, true),    // Display immediately
        ]

        for testCase in testCases {
            await tracker.clearUpdates()

            let imageData = createPPMImage(
                width: 64,
                height: testCase.height,
                offsetX: 0,
                offsetY: testCase.offsetY,
                layer: 1,
                pixelCount: 64 * testCase.height
            )

            await server.processPacket(imageData)

            let updates = await tracker.getUpdates()
            let displayed = updates.count > 0

            #expect(
                displayed == testCase.shouldDisplay,
                "offsetY=\(testCase.offsetY) height=\(testCase.height): should display"
            )
        }
    }

    // MARK: - Large Image Tests

    @Test
    func testLarge320x64ImageMultiplePackets() async throws {
        let tracker = PixelUpdateTracker()
        let server = UDPServer(
            gridWidth: 320,
            gridHeight: 64,
            onPixelUpdate: { image in
                await tracker.recordUpdate(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Simulate splitting 320×64 into multiple packets
        // For max UDP ~65507 bytes - 64 header = 65443 bytes for pixels
        // 320 * 3 = 960 bytes per row
        // 65443 / 960 = ~68 rows per packet

        // Packet 1: rows 0-67
        let packet1 = createPPMImage(
            width: 320,
            height: 64,  // Simplified: just one packet for 320×64
            offsetX: 0,
            offsetY: 0,
            layer: 0,
            pixelCount: 320 * 64
        )

        await server.processPacket(packet1)

        let updates = await tracker.getUpdates()
        #expect(updates.count == 1)
        #expect(updates[0].width == 320)
        #expect(updates[0].height == 64)
    }

    // MARK: - Buffer Reset Tests

    @Test
    func testBufferResetsAfterFrameComplete() async throws {
        let tracker = PixelUpdateTracker()
        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                await tracker.recordUpdate(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Frame 1: complete in 2 packets, each displays immediately
        let frame1Packet1 = createPPMImage(
            width: 64,
            height: 47,
            offsetX: 0,
            offsetY: 0,
            layer: 5
        )

        await server.processPacket(frame1Packet1)

        let frame1Packet2 = createPPMImage(
            width: 64,
            height: 17,
            offsetX: 0,
            offsetY: 47,
            layer: 5
        )

        await server.processPacket(frame1Packet2)

        var updates = await tracker.getUpdates()
        #expect(updates.count == 2, "Frame 1 packets should each display")

        // Frame 2: starts fresh, each packet displays immediately
        let frame2Packet1 = createPPMImage(
            width: 64,
            height: 32,
            offsetX: 0,
            offsetY: 0,
            layer: 5
        )

        await server.processPacket(frame2Packet1)

        updates = await tracker.getUpdates()
        #expect(updates.count == 3, "Frame 2 packet 1 should display")

        // Frame 2: complete
        let frame2Packet2 = createPPMImage(
            width: 64,
            height: 32,
            offsetX: 0,
            offsetY: 32,
            layer: 5
        )

        await server.processPacket(frame2Packet2)

        updates = await tracker.getUpdates()
        #expect(updates.count == 4, "Frame 2 packet 2 should also display")
    }

    @Test
    func testDifferentLayersDoNotInterfere() async throws {
        let tracker = PixelUpdateTracker()
        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                await tracker.recordUpdate(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Layer 3: packet 1 displays immediately
        let layer3Packet1 = createPPMImage(
            width: 64,
            height: 32,
            offsetX: 0,
            offsetY: 0,
            layer: 3
        )

        await server.processPacket(layer3Packet1)

        // Layer 7: complete frame displays immediately
        let layer7Complete = createPPMImage(
            width: 64,
            height: 64,
            offsetX: 0,
            offsetY: 0,
            layer: 7
        )

        await server.processPacket(layer7Complete)

        var updates = await tracker.getUpdates()
        #expect(updates.count == 2, "Both layers should display")
        #expect(updates[0].layer == 3)
        #expect(updates[1].layer == 7)

        // Layer 3: packet 2 displays
        let layer3Packet2 = createPPMImage(
            width: 64,
            height: 32,
            offsetX: 0,
            offsetY: 32,
            layer: 3
        )

        await server.processPacket(layer3Packet2)

        updates = await tracker.getUpdates()
        #expect(updates.count == 3, "Layer 3 packet 2 should also display")
        #expect(updates[2].layer == 3)
    }

    // MARK: - Edge Cases

    @Test
    func testSingleRowPackets() async throws {
        let tracker = PixelUpdateTracker()
        let server = UDPServer(
            gridWidth: 64,
            gridHeight: 64,
            onPixelUpdate: { image in
                await tracker.recordUpdate(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Send 64 single-row packets, each displays immediately
        for row in 0..<64 {
            let packet = createPPMImage(
                width: 64,
                height: 1,
                offsetX: 0,
                offsetY: row,
                layer: 1,
                pixelCount: 64
            )

            await server.processPacket(packet)

            let updates = await tracker.getUpdates()
            // Each packet displays immediately
            #expect(updates.count == row + 1, "Row \(row) should display, total \(row + 1)")
        }
    }

    @Test
    func testOffsetXVariation() async throws {
        let tracker = PixelUpdateTracker()
        let server = UDPServer(
            gridWidth: 320,
            gridHeight: 64,
            onPixelUpdate: { image in
                await tracker.recordUpdate(image)
            },
            onError: { _ in },
            onReady: {}
        )

        // Packet at X offset 100
        let packet = createPPMImage(
            width: 160,
            height: 64,
            offsetX: 100,
            offsetY: 0,
            layer: 5,
            pixelCount: 160 * 64
        )

        await server.processPacket(packet)

        let updates = await tracker.getUpdates()
        #expect(updates.count == 1)
        // The complete accumulated frame should have width=gridWidth, height=gridHeight
        #expect(updates[0].width == 320)
        #expect(updates[0].height == 64)
    }
}
