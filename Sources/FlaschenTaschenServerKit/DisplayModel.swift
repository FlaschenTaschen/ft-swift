// DisplayModel.swift

import Foundation
import SwiftUI
import os.log
import Darwin

nonisolated private let logger = Logger(subsystem: Logging.subsystem, category: "DisplayModel")

// Performance measurement
private let performanceLog = OSLog(subsystem: Logging.subsystem, category: "Performance")

public struct LayerStatistics: Sendable {
    public let layerID: Int
    public let pixelsActive: Int
    public let lastUpdateTime: Date
    public let timeSinceUpdate: TimeInterval

    public init(layerID: Int, pixelsActive: Int, lastUpdateTime: Date, timeSinceUpdate: TimeInterval) {
        self.layerID = layerID
        self.pixelsActive = pixelsActive
        self.lastUpdateTime = lastUpdateTime
        self.timeSinceUpdate = timeSinceUpdate
    }
}

@Observable
public final class DisplayModel: @unchecked Sendable {
    var gridWidth: Int = 45
    var gridHeight: Int = 35
    var pixelWidth: CGFloat = 16
    var pixelHeight: CGFloat = 16
    var pixelData: [PixelColor] = []
    var isServerRunning: Bool = false
    var packetsReceived: Int = 0
    var serverError: String?
    var currentFPS: Int = 0
    var maxFrameRate: Int = 60
    var layerTimeout: Int = 15
    var activeLayers: [Int] = []
    var layerStats: [Int: LayerStatistics] = [:]
    var ipAddress: String = "..."
    var useCirclePixels: Bool = false
    var useLensDistortion: Bool = false

    private var server: UDPServer?
    private var pendingPixelUpdate: [PixelColor]?
    private var frameUpdateTask: Task<Void, Never>?
    private var layerClearTask: Task<Void, Never>?
    private var layerStatsUpdateTask: Task<Void, Never>?
    private var frameCounter: Int = 0
    private var lastFPSUpdate: Date = Date()
    private var lastFPSLog: Date = Date()
    private var layers: [Int: [PixelColor]] = [:]
    private var layerLastUpdate: [Int: Date] = [:]
    private var layerActivePixelCounts: [Int: Int] = [:]  // Phase 2: cache active pixel counts
    private var sortedLayerKeys: [Int] = []  // Phase 3: cache sorted layer keys

    public init() {
        loadSettings()
        initializePixelData()
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard
        gridWidth = defaults.integer(forKey: "displayGridWidth")
        if gridWidth == 0 { gridWidth = 45 }

        gridHeight = defaults.integer(forKey: "displayGridHeight")
        if gridHeight == 0 { gridHeight = 35 }

        pixelWidth = CGFloat(defaults.double(forKey: "displayPixelSize"))
        if pixelWidth == 0 || pixelWidth < 4 { pixelWidth = 16 }
        pixelHeight = pixelWidth

        maxFrameRate = defaults.integer(forKey: "displayMaxFrameRate")
        if maxFrameRate == 0 { maxFrameRate = 60 }

        layerTimeout = defaults.integer(forKey: "displayLayerTimeout")
        if layerTimeout == 0 { layerTimeout = 15 }

        useCirclePixels = defaults.bool(forKey: "displayUseCirclePixels")
        useLensDistortion = defaults.bool(forKey: "displayuseLensDistortion")
    }

    public func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(gridWidth, forKey: "displayGridWidth")
        defaults.set(gridHeight, forKey: "displayGridHeight")
        defaults.set(Double(pixelWidth), forKey: "displayPixelSize")
        defaults.set(maxFrameRate, forKey: "displayMaxFrameRate")
        defaults.set(layerTimeout, forKey: "displayLayerTimeout")
        defaults.set(useCirclePixels, forKey: "displayUseCirclePixels")
        defaults.set(useLensDistortion, forKey: "displayuseLensDistortion")
    }

    private func initializePixelData() {
        pixelData = (0..<(gridWidth * gridHeight)).map { index in
            PixelColor(id: index, red: 0, green: 0, blue: 0)
        }
    }

    public func startServer() async {
        guard !isServerRunning, !(await server?.isListening() ?? false) else { return }

        logger.info("Starting UDP server")
        ipAddress = getLocalIPAddress()
        startFrameUpdateTask()
        startLayerCleanupTask()
        startLayerStatsUpdateTask()

        let pixelUpdateCallback: @Sendable (PPMImage) async -> Void = { [weak self] image in
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.applyLayerUpdate(image: image)
                self.packetsReceived += 1
            }
        }

        let errorCallback: @Sendable (String) -> Void = { [weak self] error in
            logger.error("Error callback invoked: \(error)")
            Task { @MainActor [weak self] in
                logger.info("Setting serverError on main thread: \(error)")
                self?.serverError = error
                self?.isServerRunning = false
            }
        }

        let readyCallback: @Sendable () -> Void = { [weak self] in
            logger.info("Server ready callback invoked")
            Task { @MainActor [weak self] in
                logger.info("Setting isServerRunning = true on main thread")
                self?.isServerRunning = true
                self?.serverError = nil
            }
        }

        server = UDPServer(
            gridWidth: gridWidth,
            gridHeight: gridHeight,
            onPixelUpdate: pixelUpdateCallback,
            onError: errorCallback,
            onReady: readyCallback
        )

        Task {
            do {
                try await server?.start()
            } catch {
                await MainActor.run {
                    logger.error("Server startup failed: \(error.localizedDescription)")
                    self.serverError = error.localizedDescription
                    self.isServerRunning = false
                }
            }
        }
    }

    public func stopServer() {
        logger.info("Stopping server, packets received: \(self.packetsReceived, privacy: .public)")
        isServerRunning = false
        serverError = nil
        stopFrameUpdateTask()
        stopLayerCleanupTask()
        stopLayerStatsUpdateTask()
        Task {
            await server?.stop()
        }
    }

    private func startFrameUpdateTask() {
        let frameInterval = 1.0 / Double(maxFrameRate)

        frameUpdateTask?.cancel()
        frameUpdateTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(frameInterval * 1000)))
                if !Task.isCancelled {
                    await MainActor.run {
                        self.processFrameUpdate()
                    }
                }
            }
        }
    }

    private func stopFrameUpdateTask() {
        frameUpdateTask?.cancel()
        frameUpdateTask = nil
        currentFPS = 0
    }

    private func processFrameUpdate() {
        if let pendingPixelUpdate {
            // Mutate existing pixelData in-place instead of creating new array
            for i in 0..<min(pixelData.count, pendingPixelUpdate.count) {
                let newPixel = pendingPixelUpdate[i]
                // Only mutate if color actually changed
                if pixelData[i].red != newPixel.red ||
                   pixelData[i].green != newPixel.green ||
                   pixelData[i].blue != newPixel.blue {
                    pixelData[i].red = newPixel.red
                    pixelData[i].green = newPixel.green
                    pixelData[i].blue = newPixel.blue
                }
            }
            self.pendingPixelUpdate = nil
            frameCounter += 1

            let now = Date()
            let timeSinceLastUpdate = now.timeIntervalSince(lastFPSUpdate)
            if timeSinceLastUpdate >= 1.0 {
                currentFPS = frameCounter
                frameCounter = 0
                lastFPSUpdate = now

                // Log FPS when there are active layers
                if !activeLayers.isEmpty {
                    let timeSinceFPSLog = now.timeIntervalSince(lastFPSLog)
                    if timeSinceFPSLog >= 1.0 {
                        logger.info("Performance: FPS=\(self.currentFPS, privacy: .public) Layers=\(self.activeLayers.count, privacy: .public) Packets=\(self.packetsReceived, privacy: .public)")
                        os_signpost(.event, log: performanceLog, name: "fpsMeasurement", "fps=%d layers=%d packets=%d", currentFPS, activeLayers.count, packetsReceived)
                        lastFPSLog = now
                    }
                }
            }
        }
    }

    public func resetDisplay() {
        logger.debug("Display reset")
        pixelData = (0..<(gridWidth * gridHeight)).map { index in
            PixelColor(id: index, red: 0, green: 0, blue: 0)
        }
    }

    public func updateGridDimensions(width: Int, height: Int) {
        logger.info("Grid dimensions changed: \(self.gridWidth, privacy: .public)x\(self.gridHeight, privacy: .public) → \(width, privacy: .public)x\(height, privacy: .public)")
        gridWidth = width
        gridHeight = height
        initializePixelData()

        // Restart server if running with new dimensions
        if isServerRunning {
            stopServer()
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                await startServer()
            }
        }
    }

    var canSupportPixelGrid: Bool {
        gridWidth * gridHeight <= 4096
    }

    public func calculateOptimalTVOSGridDimensions(for sceneSize: CGSize) -> (width: Int, height: Int) {
        let pixelSize: CGFloat = 16
        var maxWidth = Int(floor(sceneSize.width / pixelSize))
        var maxHeight = Int(floor(sceneSize.height / pixelSize))

        // UDP packet limit: keep pixel data under ~7KB to avoid "Message too long" errors
        // Each pixel = 3 bytes (RGB), plus ~400 bytes for PPM header and FT metadata
        let maxPixels = 2333  // 7000 / 3

        let currentPixels = maxWidth * maxHeight
        if currentPixels > maxPixels {
            // Scale down proportionally, maintaining aspect ratio
            let scale = sqrt(Double(maxPixels) / Double(currentPixels))
            maxWidth = Int(Double(maxWidth) * scale)
            maxHeight = Int(Double(maxHeight) * scale)
        }

        return (max(1, maxWidth), max(1, maxHeight))
    }

    private func getLocalIPAddress() -> String {
        let address = "..."
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return address }
        defer { freeifaddrs(ifaddr) }

        var ptr = ifaddr
        while let current = ptr {
            defer { ptr = current.pointee.ifa_next }

            guard let family = current.pointee.ifa_addr?.pointee.sa_family else { continue }

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

    private func startLayerCleanupTask() {
        layerClearTask?.cancel()
        layerClearTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if !Task.isCancelled {
                    await MainActor.run {
                        self.cleanupExpiredLayers()
                    }
                }
            }
        }
    }

    private func stopLayerCleanupTask() {
        layerClearTask?.cancel()
        layerClearTask = nil
    }

    private func startLayerStatsUpdateTask() {
        layerStatsUpdateTask?.cancel()
        layerStatsUpdateTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100)) // 100ms
                if !layerStats.isEmpty {
                    await MainActor.run {
                        self.updateLayerStats()
                    }
                }
            }
        }
    }

    private func stopLayerStatsUpdateTask() {
        layerStatsUpdateTask?.cancel()
        layerStatsUpdateTask = nil
    }

    private func applyLayerUpdate(image: PPMImage) {
        let startTime = Date()
        let signpostID = OSSignpostID(log: performanceLog, object: self)
        os_signpost(.begin, log: performanceLog, name: "applyLayerUpdate", signpostID: signpostID, "layer=%d", image.layer)

        let layer = image.layer
        let isNewLayer = !layers.keys.contains(layer)

        layers[layer] = image.pixels
        layerLastUpdate[layer] = Date()

        // Phase 2: Cache active pixel count when layer is updated
        let activePixels = image.pixels.filter { !($0.red == 0 && $0.green == 0 && $0.blue == 0) }.count
        layerActivePixelCounts[layer] = activePixels

        // Phase 3: Update sorted layer keys cache only when layer set changes
        if isNewLayer {
            sortedLayerKeys = layers.keys.sorted()
        }

        os_signpost(.begin, log: performanceLog, name: "updateLayerStats", signpostID: signpostID)
        updateLayerStats()
        os_signpost(.end, log: performanceLog, name: "updateLayerStats", signpostID: signpostID)

        os_signpost(.begin, log: performanceLog, name: "composePixelData", signpostID: signpostID)
        pendingPixelUpdate = composePixelData()
        os_signpost(.end, log: performanceLog, name: "composePixelData", signpostID: signpostID)

        os_signpost(.end, log: performanceLog, name: "applyLayerUpdate", signpostID: signpostID)
        let elapsed = Date().timeIntervalSince(startTime)
        logger.debug("Layer update processed in \(String(format: "%.2f", elapsed * 1000))ms")
    }

    private func cleanupExpiredLayers() {
        let now = Date()
        var expiredLayers: [Int] = []

        for (layer, lastUpdate) in layerLastUpdate {
            if now.timeIntervalSince(lastUpdate) > TimeInterval(layerTimeout) {
                // Layer 0 can only be removed if it's the only layer
                if layer == 0 && layers.count > 1 {
                    continue
                }
                expiredLayers.append(layer)
            }
        }

        for layer in expiredLayers {
            logger.debug("Cleaning up expired layer \(layer, privacy: .public)")
            layers.removeValue(forKey: layer)
            layerLastUpdate.removeValue(forKey: layer)
            layerActivePixelCounts.removeValue(forKey: layer)  // Phase 2: invalidate cache
        }

        if !expiredLayers.isEmpty {
            // Phase 3: Update sorted layer keys cache when layers are removed
            sortedLayerKeys = layers.keys.sorted()
            updateLayerStats()
            pendingPixelUpdate = composePixelData()
        }
    }

    private func composePixelData() -> [PixelColor] {
        var composed = Array(repeating: PixelColor(id: 0, red: 0, green: 0, blue: 0),
                            count: gridWidth * gridHeight)

        // Phase 3: Use cached sorted layer keys instead of sorting every time
        for layerID in sortedLayerKeys {
            guard let layerPixels = layers[layerID] else { continue }

            if layerID == 0 {
                // Copy layer 0 colors to composed array (preserving placeholder IDs for now)
                for i in 0..<min(composed.count, layerPixels.count) {
                    composed[i].red = layerPixels[i].red
                    composed[i].green = layerPixels[i].green
                    composed[i].blue = layerPixels[i].blue
                }
            } else {
                composeOverlay(base: &composed, overlay: layerPixels)
            }
        }

        return composed
    }

    private func composeOverlay(base: inout [PixelColor], overlay: [PixelColor]) {
        for i in 0..<min(base.count, overlay.count) {
            let overlayPixel = overlay[i]
            let isTransparent = overlayPixel.red == 0 && overlayPixel.green == 0 && overlayPixel.blue == 0
            if !isTransparent {
                base[i] = overlayPixel
            }
        }
    }

    private func updateLayerStats() {
        let now = Date()
        var stats: [Int: LayerStatistics] = [:]

        for (layer, _) in layers {
            let lastUpdate = layerLastUpdate[layer] ?? now
            let timeSinceUpdate = now.timeIntervalSince(lastUpdate)
            // Phase 2: Use cached active pixel count instead of filtering
            let activePixels = layerActivePixelCounts[layer] ?? 0

            stats[layer] = LayerStatistics(
                layerID: layer,
                pixelsActive: activePixels,
                lastUpdateTime: lastUpdate,
                timeSinceUpdate: timeSinceUpdate
            )
        }

        layerStats = stats
        // Phase 3: Use cached sorted layer keys instead of sorting again
        activeLayers = sortedLayerKeys
    }
}

