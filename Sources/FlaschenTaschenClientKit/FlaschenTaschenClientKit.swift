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
    private var footerStart: Int

    public init(fileDescriptor: Int32, width: Int, height: Int) {
        self.fileDescriptor = fileDescriptor
        self.width_ = width
        self.height_ = height

        // Build PPM header: "P6\n<width> <height>\n255\n"
        let header = "P6\n\(width) \(height)\n255\n"
        var bufferData = header.data(using: .ascii)!

        // Add pixel buffer space (RGB = 3 bytes per pixel)
        let pixelBufferSize = width * height * 3
        bufferData.append(Data(count: pixelBufferSize))

        // Add footer space for offsets (fixed width for offset numbers + null terminator)
        let footer = "\n0000 0000 0000\n"
        bufferData.append(footer.data(using: .ascii)!)
        bufferData.append(0)  // Null terminator to match C++ kFooterLen

        self.buffer = bufferData
        self.pixelBufferStart = header.count
        self.footerStart = bufferData.count - footer.count

        logger.debug("Canvas created \(width, privacy: .public)x\(height, privacy: .public), buffer size: \(bufferData.count, privacy: .public) bytes, fd: \(fileDescriptor, privacy: .public)")
        setOffset(x: 0, y: 0, z: 0)
    }

    public var width: Int {
        return width_
    }

    public var height: Int {
        return height_
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
        let offsetString = String(format: "\n%d %d %d\n", x, y, z)
        let offsetData = offsetString.data(using: .ascii)!
        buffer.replaceSubrange(footerStart..<buffer.count, with: offsetData)
    }

    public func send() {
        guard fileDescriptor >= 0 else {
            logger.error("send() called with invalid file descriptor: \(self.fileDescriptor, privacy: .public)")
            return
        }

        let bytesWritten = buffer.withUnsafeBytes { bufferPtr in
            Darwin.write(fileDescriptor, bufferPtr.baseAddress!, buffer.count)
        }
        if bytesWritten < 0 {
            logger.error("write() failed, errno: \(errno, privacy: .public)")
        }
    }

    public func clone() -> UDPFlaschenTaschen {
        let clone = UDPFlaschenTaschen(fileDescriptor: fileDescriptor, width: width_, height: height_)
        clone.buffer = self.buffer
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

    let fd = socket(info.pointee.ai_family, info.pointee.ai_socktype, info.pointee.ai_protocol)

    guard fd >= 0 else {
        logger.error("socket() failed")
        return -1
    }

    if connect(fd, info.pointee.ai_addr, info.pointee.ai_addrlen) < 0 {
        logger.error("connect() failed - is the FT display running at \(host, privacy: .public):1337?")
        close(fd)
        return -1
    }

    logger.debug("Successfully connected to FT display (fd=\(fd, privacy: .public))")
    return fd
}
