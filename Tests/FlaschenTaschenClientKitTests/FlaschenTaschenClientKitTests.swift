import Testing
import FlaschenTaschenClientKit

@Suite
struct FlaschenTaschenClientKitTests {
    @Test
    func testColorCreation() {
        let color = Color(r: 255, g: 128, b: 64)
        #expect(color.r == 255)
        #expect(color.g == 128)
        #expect(color.b == 64)
    }

    @Test
    func argumentPreprocessor() {
        let args = ["-hlocalhost", "-g45x35", "-l10", "-O"]
        let expected = ["-h", "localhost", "-g", "45x35", "-l", "10", "-O"]

        let processed = ArgumentPreprocessor.preprocess(args: args)

        #expect(expected == processed)

    }

    // MARK: - Packet Chunking Tests

    @Test
    func testChunking64x64AtMacOSTypicalSOSNDBUF() {
        // 64x64 at macOS typical SO_SNDBUF (9216) → 2 packets: 47 + 17 rows
        let canvas = UDPFlaschenTaschen(fileDescriptor: -1, width: 64, height: 64, maxUDPSize: 9216)
        let ranges = canvas.packetRanges()
        #expect(ranges.count == 2)
        #expect(ranges[0].rowStart == 0 && ranges[0].rowCount == 47)
        #expect(ranges[1].rowStart == 47 && ranges[1].rowCount == 17)
    }

    @Test
    func testSinglePacket45x35() {
        // 45x35 at full size → 1 packet
        let canvas = UDPFlaschenTaschen(fileDescriptor: -1, width: 45, height: 35, maxUDPSize: 65507)
        let ranges = canvas.packetRanges()
        #expect(ranges.count == 1)
        #expect(ranges[0].rowStart == 0 && ranges[0].rowCount == 35)
    }

    @Test
    func testSinglePacket64x64() {
        // 64x64 at full size → 1 packet
        let canvas = UDPFlaschenTaschen(fileDescriptor: -1, width: 64, height: 64, maxUDPSize: 65507)
        let ranges = canvas.packetRanges()
        #expect(ranges.count == 1)
        #expect(ranges[0].rowStart == 0 && ranges[0].rowCount == 64)
    }

    @Test
    func testSinglePacket320x64() {
        // 320x64 at 65507 → 1 packet (61440 < 65507)
        let canvas = UDPFlaschenTaschen(fileDescriptor: -1, width: 320, height: 64, maxUDPSize: 65507)
        let ranges = canvas.packetRanges()
        #expect(ranges.count == 1)
    }

    @Test
    func testMaxPacketSizeProperty() {
        // maxPacketSize property reflects internal value
        let canvas = UDPFlaschenTaschen(fileDescriptor: -1, width: 64, height: 64, maxUDPSize: 9216)
        #expect(canvas.maxPacketSize == 9216)
    }
}
