// UDPServer.swift

import Foundation
import Network
import os.log
import Darwin

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "UDPServer")

// Throttler ensures an action runs at most once per interval
private actor Throttler {
    private var lastRun: ContinuousClock.Instant?
    private let clock = ContinuousClock()

    func run(interval: Duration, action: @Sendable () async -> Void) async {
        let now = clock.now

        if let lastRun, now - lastRun < interval {
            return
        }

        lastRun = now
        await action()
    }
}

public actor UDPServer {
    private let gridWidth: Int
    private let gridHeight: Int
    private let onPixelUpdate: @Sendable (PPMImage) async -> Void
    private let onError: (String) -> Void
    private let onReady: () -> Void
    private var listener: NWListener?
    private var startupError: Error?
    private var stopContinuation: CheckedContinuation<Void, Error>?

    // Layer persistence for multi-packet accumulation
    private var layerBuffers: [Int: [PixelColor]] = [:]
    private var layerThrottlers: [Int: Throttler] = [:]
    private var lastPacketTime: Date?
    private let packetTimeoutSeconds: TimeInterval = 1.0
    private let flushInterval: Duration = .milliseconds(50)  // 50ms throttle for flushing

    public init(gridWidth: Int, gridHeight: Int,
         onPixelUpdate: @escaping @Sendable (PPMImage) async -> Void,
         onError: @escaping (String) -> Void,
         onReady: @escaping () -> Void) {
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
        self.onPixelUpdate = onPixelUpdate
        self.onError = onError
        self.onReady = onReady
    }

    public func start() async throws {
        startupError = nil
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true

        let port = NWEndpoint.Port(rawValue: 1337)!
        listener = try NWListener(using: parameters, on: port)

        guard let listener else {
            logger.error("Failed to create UDP listener")
            throw NSError(domain: "UDPServer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create listener"])
        }

        logger.info("UDP server starting on port 1337, grid=\(self.gridWidth, privacy: .public)x\(self.gridHeight, privacy: .public)")

        listener.newConnectionHandler = { [weak self] connection in
            Task { [weak self] in
                await self?.handleConnection(connection)
            }
        }

        listener.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleStateChange(state)
            }
        }

        listener.start(queue: DispatchQueue(label: "ft.server"))

        // wait until stopped
        try await withCheckedThrowingContinuation { continuation in
            self.stopContinuation = continuation
        }
    }

    public func stop() {
        logger.info("UDP server stopping")
        listener?.cancel()
        listener = nil
        if let continuation = stopContinuation {
            stopContinuation = nil
            continuation.resume()
        }
    }

    public func isListening() -> Bool {
        listener != nil
    }

    private func handleStateChange(_ state: NWListener.State) {
        switch state {
        case .ready:
            let ip = getLocalIPAddress()
            logger.info("UDP server ready, listening on \(ip, privacy: .public):1337")
            onReady()
        case .failed(let error):
            logger.error("UDP server failed: \(error.localizedDescription, privacy: .public)")
            startupError = error
            if let continuation = stopContinuation {
                stopContinuation = nil
                continuation.resume(throwing: error)
            }
            onError("Server error: \(error.localizedDescription)")
        case .cancelled:
            logger.info("UDP server stopped")
            if stopContinuation != nil {
                onError("Server stopped unexpectedly")
            }
        default:
            break
        }
    }

    private func handleConnection(_ connection: NWConnection) async {
        logger.info("New connection from \(String(describing: connection.endpoint))")

        connection.stateUpdateHandler = { [weak self] state in
            Task { [weak self] in
                await self?.handleConnectionStateChange(state, connection: connection)
            }
        }

        connection.viabilityUpdateHandler = { [weak self] isViable in
            Task { [weak self] in
                if !isViable {
                    await self?.handleConnectionViabilityChange()
                }
            }
        }

        connection.start(queue: DispatchQueue(label: "ft.connection"))
    }

    private func handleConnectionStateChange(_ state: NWConnection.State, connection: NWConnection) {
        switch state {
        case .ready:
            receiveData(on: connection)
        case .failed(let error):
            logger.error("Connection failed: \(error.localizedDescription, privacy: .public)")
            onError("Connection error: \(error.localizedDescription)")
        default:
            break
        }
    }

    private func handleConnectionViabilityChange() {
        onError("Connection became unviable")
    }

    private func receiveData(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, error in
            Task { [weak self] in
                if let error {
                    await self?.handleReceiveError(error)
                    return
                }

                if let data {
                    await self?.processPacket(data)
                }

                await self?.receiveData(on: connection)
            }
        }
    }

    private func handleReceiveError(_ error: Error) {
        logger.error("Receive error: \(error.localizedDescription, privacy: .public)")
        onError("Receive error: \(error.localizedDescription)")
    }

    private func flushLayer(_ layer: Int) async {
        guard let pixelGrid = layerBuffers[layer] else {
            return
        }

        // Send the complete accumulated buffer for this layer
        let completeImage = PPMImage(width: self.gridWidth, height: self.gridHeight, pixels: pixelGrid,
                                    offsetX: 0, offsetY: 0, layer: layer)
        let nonBlackCount = pixelGrid.filter { !($0.red == 0 && $0.green == 0 && $0.blue == 0) }.count
        logger.info("🖼️ SEND layer \(layer, privacy: .public): \(self.gridWidth, privacy: .public)x\(self.gridHeight, privacy: .public) (\(nonBlackCount, privacy: .public) non-black pixels)")
        await onPixelUpdate(completeImage)
    }

    public func processPacket(_ data: Data) async {
        do {
            let image = try PPMParser.parse(data: data)
            logger.info("🔵 PACKET: size=\(image.width, privacy: .public)x\(image.height, privacy: .public) offset=(\(image.offsetX, privacy: .public),\(image.offsetY, privacy: .public)) LAYER=\(image.layer, privacy: .public) pixels=\(image.pixels.count, privacy: .public)")

            let now = Date()
            let layer = image.layer

            // Check if we need to reset (new frame or timeout)
            if lastPacketTime == nil ||
               (now.timeIntervalSince(lastPacketTime!) > packetTimeoutSeconds) {
                layerBuffers.removeAll()
                logger.debug("Resetting layer buffers (timeout or first packet)")
            }

            // Initialize layer buffer if needed
            if layerBuffers[layer] == nil {
                layerBuffers[layer] = Array(repeating: PixelColor(id: 0, red: 0, green: 0, blue: 0),
                                           count: gridWidth * gridHeight)
                logger.info("📦 INIT layer \(layer, privacy: .public)")
            }

            // Accumulate this packet's pixels into the layer buffer
            if var pixelGrid = layerBuffers[layer] {
                logger.info("📥 ACCUMULATING to layer \(layer, privacy: .public): rows \(image.offsetY, privacy: .public)-\(image.offsetY + image.height - 1, privacy: .public)")
                for y in 0..<image.height {
                    let gridY = image.offsetY + y
                    if gridY < 0 || gridY >= gridHeight { continue }

                    for x in 0..<image.width {
                        let gridX = image.offsetX + x
                        if gridX < 0 || gridX >= gridWidth { continue }

                        let sourceIndex = y * image.width + x
                        let targetIndex = gridY * gridWidth + gridX
                        let sourcePixel = image.pixels[sourceIndex]
                        pixelGrid[targetIndex] = PixelColor(id: 0, red: sourcePixel.red, green: sourcePixel.green, blue: sourcePixel.blue)
                    }
                }

                // Store updated buffer
                layerBuffers[layer] = pixelGrid
                lastPacketTime = now

                // Use throttler to ensure flush runs at regular intervals (not debounced)
                let throttler = layerThrottlers[layer] ?? Throttler()
                layerThrottlers[layer] = throttler

                await throttler.run(interval: flushInterval) { [weak self] in
                    await self?.flushLayer(layer)
                }
            }
        } catch {
            logger.warning("Discarding malformed packet: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func getLocalIPAddress() -> String {
        let address = "127.0.0.1"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else {
            return address
        }

        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }

            guard let family = current.pointee.ifa_addr?.pointee.sa_family else {
                continue
            }

            if family == sa_family_t(AF_INET) {
                if let addrPtr = current.pointee.ifa_addr {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addrPtr, socklen_t(addrPtr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        let ipString = String(cString: hostname)
                        if !ipString.starts(with: "127.") && !ipString.starts(with: "169.254") {
                            return ipString
                        }
                    }
                }
            }
        }

        return address
    }
}
