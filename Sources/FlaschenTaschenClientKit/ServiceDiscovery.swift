// ServiceDiscovery.swift

import Foundation

/// Represents a discovered FlaschenTaschen display service
public struct DisplayService: Sendable, Equatable {
    public let instanceName: String      // e.g., "Kitchen Display"
    public let hostname: String          // e.g., "pi.local"
    public let address: String           // IP address
    public let port: UInt16
    public let width: Int
    public let height: Int
    public let name: String              // From TXT record
    public let url: String?              // From TXT record (optional)

    public init(
        instanceName: String,
        hostname: String,
        address: String,
        port: UInt16,
        width: Int,
        height: Int,
        name: String,
        url: String? = nil
    ) {
        self.instanceName = instanceName
        self.hostname = hostname
        self.address = address
        self.port = port
        self.width = width
        self.height = height
        self.name = name
        self.url = url
    }
}

/// Handles mDNS/Bonjour service discovery for FlaschenTaschen displays
nonisolated public func discoverDisplays(timeoutSeconds: TimeInterval = 5.0) async -> [DisplayService] {
    let result = await withCheckedContinuation { continuation in
        let browser = ServiceBrowser(continuation: continuation)
        browser.startDiscovery(timeoutSeconds: timeoutSeconds)

        // For CLI tools, we need to run the RunLoop to process delegate callbacks
        RunLoop.current.run(until: Date(timeIntervalSinceNow: timeoutSeconds + 0.5))
    }
    return result
}

/// Discover a single display by name (case-insensitive partial match)
nonisolated public func discoverDisplay(query: String, timeoutSeconds: TimeInterval = 5.0) async -> DisplayService? {
    let allDisplays = await discoverDisplays(timeoutSeconds: timeoutSeconds)
    let queryLower = query.lowercased()
    return allDisplays.first { service in
        service.instanceName.lowercased().contains(queryLower) ||
        service.name.lowercased().contains(queryLower)
    }
}

// MARK: - Internal Implementation

private class ServiceBrowser: NSObject, NetServiceBrowserDelegate, NetServiceDelegate, @unchecked Sendable {
    private let continuation: CheckedContinuation<[DisplayService], Never>
    private let serviceType = "_flaschen-taschen._udp"
    private let domain = "local."

    private var browser: NetServiceBrowser?
    private var discoveredServices: [NetService] = []
    private var resolvedServices: [DisplayService] = []
    private var pendingResolutions: Int = 0
    private var timeoutTask: Task<Void, Never>?
    private var selfReference: ServiceBrowser?  // Keeps self alive until finishDiscovery
    private var isFinished = false

    init(continuation: CheckedContinuation<[DisplayService], Never>) {
        self.continuation = continuation
        super.init()
    }

    func startDiscovery(timeoutSeconds: TimeInterval) {
        selfReference = self  // Keep self alive
        browser = NetServiceBrowser()
        browser?.delegate = self
        browser?.searchForServices(ofType: serviceType, inDomain: domain)

        // Set timeout to stop discovery
        timeoutTask = Task {
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            self.finishDiscovery()
        }
    }

    private func finishDiscovery() {
        guard !isFinished else { return }
        isFinished = true

        timeoutTask?.cancel()
        timeoutTask = nil
        browser?.stop()
        browser = nil

        continuation.resume(returning: resolvedServices)
        selfReference = nil  // Release self, allowing deallocation
    }

    // MARK: - NetServiceBrowserDelegate

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didFind netService: NetService,
        moreComing: Bool
    ) {
        discoveredServices.append(netService)
        pendingResolutions += 1

        netService.delegate = self
        netService.resolve(withTimeout: 2.0)

        if !moreComing && pendingResolutions == 0 {
            finishDiscovery()
        }
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didRemove netService: NetService,
        moreComing: Bool
    ) {
        discoveredServices.removeAll { $0 === netService }
    }

    func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
    }

    func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
    }

    func netServiceBrowser(
        _ browser: NetServiceBrowser,
        didNotSearch errorDict: [String: NSNumber]
    ) {
        finishDiscovery()
    }

    // MARK: - NetServiceDelegate

    func netServiceDidResolveAddress(_ sender: NetService) {
        resolveService(sender)
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        pendingResolutions -= 1
        checkCompletion()
    }

    private func resolveService(_ service: NetService) {
        guard let data = service.addresses?.first else {
            discoveredServices.removeAll { $0 === service }
            pendingResolutions -= 1
            checkCompletion()
            return
        }

        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        let ipAddress: String

        var ipv4 = data.withUnsafeBytes { ptr in
            ptr.load(as: sockaddr_in.self)
        }

        if ipv4.sin_family == sa_family_t(AF_INET) {
            inet_ntop(AF_INET, &ipv4.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN))
            let uintBuffer = buffer.map { UInt8(bitPattern: $0) }
            let nullIndex = uintBuffer.firstIndex(of: 0) ?? uintBuffer.count
            ipAddress = String(decoding: uintBuffer[0..<nullIndex], as: UTF8.self)
        } else {
            ipAddress = "unknown"
        }

        let txtRecords = NetService.dictionary(fromTXTRecord: service.txtRecordData() ?? Data())
        let width = parseIntValue(txtRecords["width"], defaultValue: 0)
        let height = parseIntValue(txtRecords["height"], defaultValue: 0)
        let name = parseStringValue(txtRecords["name"], defaultValue: service.name)
        let url = parseStringValue(txtRecords["url"])

        let displayService = DisplayService(
            instanceName: service.name,
            hostname: service.hostName ?? "unknown",
            address: ipAddress,
            port: UInt16(service.port),
            width: width,
            height: height,
            name: name,
            url: url
        )

        discoveredServices.removeAll { $0 === service }
        resolvedServices.append(displayService)
        pendingResolutions -= 1
        checkCompletion()
    }

    private func checkCompletion() {
        if pendingResolutions == 0 && discoveredServices.isEmpty {
            finishDiscovery()
        }
    }

    private func parseStringValue(_ data: Data?, defaultValue: String = "") -> String {
        guard let data = data else { return defaultValue }
        let string = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")) ?? defaultValue
        return string.isEmpty ? defaultValue : string
    }

    private func parseIntValue(_ data: Data?, defaultValue: Int = 0) -> Int {
        guard let data = data else { return defaultValue }
        if let string = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: "\0")),
           let value = Int(string) {
            return value
        }
        return defaultValue
    }
}
