// FlaschenTaschenClientKit - Swift library for Flaschen Taschen UDP communication
// Ported from udp-flaschen-taschen.cc

import Foundation
import Darwin
import os.log

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "FlaschenTaschenClientKit")

/// RGB color representation - immutable value type, safe for concurrent use
public nonisolated struct Color: Equatable, Sendable {
    public var r: UInt8
    public var g: UInt8
    public var b: UInt8

    public nonisolated init(r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0) {
        self.r = r
        self.g = g
        self.b = b
    }

    public nonisolated var isBlack: Bool {
        r == 0 && g == 0 && b == 0
    }
}

/// Canvas for drawing pixels and sending to Flaschen Taschen display
/// Uses @unchecked Sendable because clients use this synchronously in a single-threaded context
public class UDPFlaschenTaschen: @unchecked Sendable {
    private let fileDescriptor: Int32
    private let width_: Int
    private let height_: Int
    private var buffer: Data
    private var pixelBufferStart: Int
    private var offsetX: Int = 0
    private var offsetY: Int = 0
    private var offsetZ: Int = 0
    private let maxUDPSize: Int
    private static let headerReserve = 64

    /// Query SO_SNDBUF from socket, with FT_UDP_SIZE env var override
    private nonisolated static func getMaxUDPSize(fd: Int32) -> Int {
        // Env var override (highest priority)
        if let envStr = ProcessInfo.processInfo.environment["FT_UDP_SIZE"],
           let envSize = Int(envStr), envSize > 0 {
            return envSize
        }
        // Query SO_SNDBUF from the connected socket
        if fd >= 0 {
            var sndBuf: Int32 = 0
            var len = socklen_t(MemoryLayout<Int32>.size)
            if getsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sndBuf, &len) == 0, sndBuf > 0 {
                return min(Int(sndBuf), 65507)
            }
        }
        return 65507
    }

    /// Create PPM buffer with pixel space
    private nonisolated static func makeBuffer(width: Int, height: Int) -> (buffer: Data, pixelStart: Int) {
        let header = "P6\n\(width) \(height)\n255\n"
        var buf = header.data(using: .ascii)!
        buf.append(Data(count: width * height * 3))
        return (buf, header.count)
    }

    /// Designated initializer that accepts explicit maxUDPSize (for testing and advanced use)
    public init(fileDescriptor: Int32, width: Int, height: Int, maxUDPSize: Int) {
        self.fileDescriptor = fileDescriptor
        self.width_ = width
        self.height_ = height
        self.maxUDPSize = maxUDPSize

        // Validate that at least 1 row fits in a packet
        let rowSize = 3 * width
        let maxRowsPerPacket = (maxUDPSize - UDPFlaschenTaschen.headerReserve) / rowSize
        precondition(maxRowsPerPacket > 0,
                     "UDP packet size \(maxUDPSize) too small for canvas width \(width) (minimum needed: \(rowSize + UDPFlaschenTaschen.headerReserve) bytes)")

        let (bufferData, pixelStart) = Self.makeBuffer(width: width, height: height)
        self.buffer = bufferData
        self.pixelBufferStart = pixelStart

        logger.debug("Canvas created \(width, privacy: .public)x\(height, privacy: .public), buffer size: \(bufferData.count, privacy: .public) bytes, fd: \(fileDescriptor, privacy: .public), max UDP size: \(maxUDPSize, privacy: .public) bytes")
        setOffset(x: 0, y: 0, z: 0)
    }

    /// Public convenience initializer that queries SO_SNDBUF from socket
    public convenience init(fileDescriptor: Int32, width: Int, height: Int) {
        self.init(fileDescriptor: fileDescriptor, width: width, height: height, maxUDPSize: Self.getMaxUDPSize(fd: fileDescriptor))
    }

    public var width: Int {
        return width_
    }

    public var height: Int {
        return height_
    }

    public var maxPacketSize: Int {
        return maxUDPSize
    }

    public func setPixel(x: Int, y: Int, color: Color) {
        guard x >= 0 && x < width_ && y >= 0 && y < height_ else {
            return
        }

        let pixelOffset = pixelBufferStart + (y * width_ + x) * 3
        buffer[pixelOffset] = color.r
        buffer[pixelOffset + 1] = color.g
        buffer[pixelOffset + 2] = color.b
    }

    public func getPixel(x: Int, y: Int) -> Color {
        let wrappedX = x % width_
        let wrappedY = y % height_
        let pixelOffset = pixelBufferStart + (wrappedY * width_ + wrappedX) * 3

        return Color(
            r: buffer[pixelOffset],
            g: buffer[pixelOffset + 1],
            b: buffer[pixelOffset + 2]
        )
    }

    public func clear() {
        let pixelCount = width_ * height_
        for i in 0..<pixelCount {
            let offset = pixelBufferStart + i * 3
            buffer[offset] = 0
            buffer[offset + 1] = 0
            buffer[offset + 2] = 0
        }
    }

    public func fill(color: Color) {
        if color.isBlack {
            clear()
        } else {
            let pixelCount = width_ * height_
            for i in 0..<pixelCount {
                let offset = pixelBufferStart + i * 3
                buffer[offset] = color.r
                buffer[offset + 1] = color.g
                buffer[offset + 2] = color.b
            }
        }
    }

    public func setOffset(x: Int, y: Int, z: Int) {
        offsetX = x
        offsetY = y
        offsetZ = z
    }

    public func send() {
        guard fileDescriptor >= 0 else {
            logger.error("send() called with invalid file descriptor: \(self.fileDescriptor, privacy: .public)")
            return
        }

        let rowSize = 3 * width_
        let maxRowsPerPacket = (maxUDPSize - UDPFlaschenTaschen.headerReserve) / rowSize

        // Calculate total number of packets
        let totalPackets = (height_ + maxRowsPerPacket - 1) / maxRowsPerPacket

        var chunkRowOffset = 0
        var packetNumber = 1

        while chunkRowOffset < height_ {
            let rowsThisChunk = min(maxRowsPerPacket, height_ - chunkRowOffset)

            // Build PPM header with #FT: offset comment for this chunk
            let header = String(format: "P6\n%d %d\n#FT: %d %d %d\n255\n",
                               width_, rowsThisChunk,
                               offsetX, offsetY + chunkRowOffset, offsetZ)
            guard let headerData = header.data(using: .ascii) else {
                logger.error("Failed to encode PPM header")
                return
            }

            // Extract pixel data for this chunk
            let pixelStart = pixelBufferStart + chunkRowOffset * rowSize
            let pixelEnd = pixelStart + rowsThisChunk * rowSize

            // Construct packet: header + pixel data
            var packet = Data(capacity: headerData.count + rowsThisChunk * rowSize)
            packet.append(headerData)
            packet.append(buffer[pixelStart..<pixelEnd])

            // Send the packet
            let sent = packet.withUnsafeBytes { bufferPtr in
                Darwin.write(fileDescriptor, bufferPtr.baseAddress!, packet.count)
            }

            if sent < 0 {
                let errStr = String(cString: strerror(errno))
                if errno == 61 { // ECONNREFUSED
                    logger.error("write() failed: Connection refused (errno \(errno)). Is the FT server running and listening? Check the host/port configuration. fd=\(self.fileDescriptor, privacy: .public)")
                    
                    exit(EXIT_FAILURE)
                } else {
                    logger.error("write() failed at packet \(packetNumber, privacy: .public) of \(totalPackets, privacy: .public), errno: \(errno, privacy: .public) (\(errStr, privacy: .public)), fd=\(self.fileDescriptor, privacy: .public)")
                    exit(EXIT_FAILURE)
                }
                return
            }

            if totalPackets > 1 {
                logger.debug("Sent packet \(packetNumber, privacy: .public) of \(totalPackets, privacy: .public): rows \(chunkRowOffset, privacy: .public)-\(chunkRowOffset + rowsThisChunk - 1, privacy: .public)")
            }

            chunkRowOffset += rowsThisChunk
            packetNumber += 1
        }
    }

    /// Return packet boundaries for testing (pure math, no I/O)
    public func packetRanges() -> [(rowStart: Int, rowCount: Int)] {
        let rowSize = 3 * width_
        let maxRows = (maxUDPSize - UDPFlaschenTaschen.headerReserve) / rowSize
        var result: [(Int, Int)] = []
        var offset = 0
        while offset < height_ {
            let rows = min(maxRows, height_ - offset)
            result.append((offset, rows))
            offset += rows
        }
        return result
    }

    public func clone() -> UDPFlaschenTaschen {
        let clone = UDPFlaschenTaschen(fileDescriptor: fileDescriptor, width: width_, height: height_)
        clone.buffer = self.buffer
        clone.offsetX = self.offsetX
        clone.offsetY = self.offsetY
        clone.offsetZ = self.offsetZ
        return clone
    }
}

public func openFlaschenTaschenSocket(hostname: String?) -> Int32 {
    let host = hostname ?? ProcessInfo.processInfo.environment["FT_DISPLAY"] ?? "localhost"
    logger.debug("Connecting to FT display at \(host, privacy: .public):1337")

    var addrInfo: UnsafeMutablePointer<addrinfo>?
    defer {
        if addrInfo != nil {
            freeaddrinfo(addrInfo)
        }
    }

    var hints = addrinfo()
    hints.ai_family = AF_INET
    hints.ai_socktype = SOCK_DGRAM

    let portString = "1337"
    let rc = getaddrinfo(host, portString, &hints, &addrInfo)

    guard rc == 0, let info = addrInfo else {
        let errorMsg = String(cString: gai_strerror(rc))
        logger.error("Resolving '\(host, privacy: .public)': \(errorMsg, privacy: .public)")
        return -1
    }

    // Get the resolved IP address for diagnostics
    var resolvedIP = "unknown"
    if let addr = info.pointee.ai_addr {
        var resolvedHost = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                      &resolvedHost, socklen_t(resolvedHost.count),
                      nil, 0, NI_NUMERICHOST) == 0 {
            resolvedIP = String(cString: resolvedHost)
        }
    }

    let fd = socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)

    guard fd >= 0 else {
        logger.error("socket() failed")
        return -1
    }

    if connect(fd, info.pointee.ai_addr, info.pointee.ai_addrlen) < 0 {
        logger.error("connect() failed to \(host, privacy: .public) (resolved: \(resolvedIP, privacy: .public):1337) - is the FT display running there?")
        close(fd)
        return -1
    }

    logger.info("Successfully connected to FT display at \(host, privacy: .public) (resolved: \(resolvedIP, privacy: .public):1337) (fd=\(fd, privacy: .public))")
    return fd
}
