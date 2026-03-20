// UDPServer.swift

import Foundation
import Network
import os.log
import Darwin

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "UDPServer")

actor UDPServer {
    private let gridWidth: Int
    private let gridHeight: Int
    private let onPixelUpdate: (PPMImage) -> Void
    private let onError: (String) -> Void
    private let onReady: () -> Void
    private var listener: NWListener?
    private var startupError: Error?
    private var stopContinuation: CheckedContinuation<Void, Error>?

    init(gridWidth: Int, gridHeight: Int,
         onPixelUpdate: @escaping (PPMImage) -> Void,
         onError: @escaping (String) -> Void,
         onReady: @escaping () -> Void) {
        self.gridWidth = gridWidth
        self.gridHeight = gridHeight
        self.onPixelUpdate = onPixelUpdate
        self.onError = onError
        self.onReady = onReady
    }

    func start() async throws {
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

    func stop() {
        logger.info("UDP server stopping")
        listener?.cancel()
        listener = nil
        if let continuation = stopContinuation {
            stopContinuation = nil
            continuation.resume()
        }
    }

    func isListening() -> Bool {
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

    private func processPacket(_ data: Data) {
        do {
            var image = try PPMParser.parse(data: data)
            logger.debug("Packet received: size=\(image.width, privacy: .public)x\(image.height, privacy: .public) offset=(\(image.offsetX, privacy: .public),\(image.offsetY, privacy: .public)) layer=\(image.layer, privacy: .public)")

            var pixelGrid = Array(repeating: PixelColor(id: 0, red: 0, green: 0, blue: 0),
                                 count: gridWidth * gridHeight)

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

            image = PPMImage(width: gridWidth, height: gridHeight, pixels: pixelGrid,
                           offsetX: image.offsetX, offsetY: image.offsetY, layer: image.layer)
            self.onPixelUpdate(image)
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
