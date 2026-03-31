# Service Discovery with mDNS using Swift

The practical way to do this in Swift is with **Bonjour over mDNS**. On Apple platforms, the modern API is **Network.framework**: use `NWListener` to advertise a service, `NWBrowser` to discover it, and `NWConnection` to connect to a discovered endpoint. Apple explicitly recommends Bonjour for discovering devices on the local network, and calls out `NWListener` for advertising and `NWBrowser` for discovery. ([Apple Developer][1])

One important distinction: you can absolutely advertise a Bonjour service **the same way AirPlay is announced**—service name, service type, TXT record, port—but that does **not** make your app a real AirPlay receiver by itself. That is only the discovery layer. A real AirPlay client also expects the protocol spoken on the advertised port. That last point is an inference from how Bonjour discovery and endpoint connection are separated in Apple’s networking APIs. ([Apple Developer][1])

## Use your own service type

For a custom service, use your own Bonjour type, like `_myreceiver._tcp`. Apple’s guidance is that the service type is the protocol identifier, and if you ship a new one broadly it should follow the RFC 6335 naming rules and be registered with IANA. ([Apple Developer][2])

## Server: advertise a Bonjour service

This advertises a TCP service with TXT-record metadata, the same general pattern AirPlay uses.

```swift
import Foundation
import Network

@MainActor
final class BonjourServer {
    private let serviceName: String
    private let serviceType = "_myreceiver._tcp"
    private var listener: NWListener?
    private var connections: [NWConnection] = []

    init(serviceName: String) {
        self.serviceName = serviceName
    }

    func start() throws {
        let listener = try NWListener(using: .tcp, on: 7000)

        let txtData = NetService.data(fromTXTRecord: [
            "model": Data("MyReceiver1,0".utf8),
            "protovers": Data("1.0".utf8),
            "features": Data("video,audio".utf8),
            "srcvers": Data("1".utf8)
        ])

        listener.service = .init(
            name: serviceName,
            type: serviceType,
            domain: nil,
            txtRecord: txtData
        )

        listener.stateUpdateHandler = { state in
            print("listener state:", state)
        }

        listener.serviceRegistrationUpdateHandler = { change in
            print("service registration:", change)
        }

        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }

            self.connections.append(connection)
            self.configure(connection)
            connection.start(queue: .main)
        }

        listener.start(queue: .main)
        self.listener = listener
    }

    func stop() {
        connections.forEach { $0.cancel() }
        connections.removeAll()
        listener?.cancel()
        listener = nil
    }

    private func configure(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            print("connection state:", state)
        }

        receiveNextMessage(on: connection)
    }

    private func receiveNextMessage(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            if let data, let string = String(data: data, encoding: .utf8) {
                print("received:", string)
            }

            if let error {
                print("receive error:", error)
                return
            }

            guard isComplete == false else { return }
            self?.receiveNextMessage(on: connection)
        }
    }
}
```

Why this shape works:

* `NWListener` is the server-side listener. ([Apple Developer][3])
* A listener advertises Bonjour by setting its `service` property. Apple’s examples show `listener.service = .init(type: "_example._tcp")`, and also show using a custom name. ([Apple Developer][2])
* `NWListener.Service` supports a TXT record, and Foundation’s `NetService.data(fromTXTRecord:)` creates TXT-record `Data`. ([Apple Developer][4])

## Client: browse and connect

This discovers instances of that service and opens a connection to one.

```swift
import Foundation
import Network

@MainActor
final class BonjourClient {
    private let serviceType = "_myreceiver._tcp"
    private var browser: NWBrowser?
    private var connection: NWConnection?

    func startBrowsing() {
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: serviceType, domain: nil),
            using: .tcp
        )

        browser.stateUpdateHandler = { state in
            print("browser state:", state)
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            for result in results {
                print("endpoint:", result.endpoint)

                if case .bonjour(let txtRecord) = result.metadata {
                    if let model = txtRecord["model"] {
                        print("model:", model)
                    }
                    if let features = txtRecord["features"] {
                        print("features:", features)
                    }
                    if let protocolVersion = txtRecord["protovers"] {
                        print("protovers:", protocolVersion)
                    }
                }

                self?.connectIfNeeded(to: result.endpoint)
            }
        }

        browser.start(queue: .main)
        self.browser = browser
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil

        connection?.cancel()
        connection = nil
    }

    private func connectIfNeeded(to endpoint: NWEndpoint) {
        guard connection == nil else { return }

        let connection = NWConnection(to: endpoint, using: .tcp)

        connection.stateUpdateHandler = { state in
            print("outbound connection state:", state)
        }

        connection.start(queue: .main)
        self.connection = connection

        sendHello()
    }

    private func sendHello() {
        let payload = Data("hello\n".utf8)

        connection?.send(content: payload, completion: .contentProcessed { error in
            if let error {
                print("send error:", error)
            }
        })
    }
}
```

Why this works:

* Apple’s examples show `NWBrowser(for: .bonjour(type:domain:), using: .tcp)` for discovery, and `NWConnection(to: endpoint, using: parameters)` for connecting to a discovered peer. ([Apple Developer][2])
* If you want TXT records during discovery, Apple provides `NWBrowser.Descriptor.bonjourWithTXTRecord(type:domain:)`, specifically for discovering a Bonjour service **with associated TXT records**. ([Apple Developer][5])
* The browser result metadata includes Bonjour TXT-record metadata. ([Apple Developer][6])

## iPhone and iPad privacy settings

On iOS and iPadOS, if you browse or advertise Bonjour services, Apple says to declare the service types in `Info.plist` and provide a local-network usage description. That means adding:

```xml
<key>NSBonjourServices</key>
<array>
    <string>_myreceiver._tcp</string>
</array>
<key>NSLocalNetworkUsageDescription</key>
<string>Discover and connect to receivers on your local network.</string>
```

Apple documents both requirements for local-network privacy. ([Apple Developer][1])

## If you want it to look more like AirPlay

AirPlay advertisements carry a lot of capability data in TXT records, such as model, protocol version, features, and source version. You can do the same with your own keys and values. The shape is identical even though the meanings are yours. That is the right way to mimic the **discovery model** of AirPlay.

A good custom TXT payload might include:

* `model=MyReceiver1,0`
* `protovers=1.0`
* `features=video,audio`
* `codec=h264,aac`
* `auth=pin` or `auth=none`

Then your client can decide whether to connect based on those advertised capabilities, just like an AirPlay client does.

## If you need older Foundation APIs

Foundation still has `NetService` and `NetServiceBrowser`, which represent a published service and a service browser. Those are still documented and can be useful, especially if you specifically want classic Bonjour objects. ([Apple Developer][7])

## The main takeaway

* Use **`NWListener`** to announce the service.
* Put your configuration in the **TXT record**.
* Use **`NWBrowser`** to discover it.
* Use **`NWConnection`** to connect to the discovered endpoint. ([Apple Developer][1])

If you want, I can turn this into a small Swift package with one target for the announcer and one target for the browser.

[1]: https://developer.apple.com/news/?id=0oi77447 "How to use multicast networking in your app - Discover - Apple Developer"
[2]: https://developer.apple.com/forums/tags/multipeerconnectivity "Multipeer Connectivity | Apple Developer Forums"
[3]: https://developer.apple.com/documentation/network?utm_source=chatgpt.com "Network | Apple Developer Documentation"
[4]: https://developer.apple.com/documentation/network/nwlistener/service-swift.struct?utm_source=chatgpt.com "NWListener.Service | Apple Developer Documentation"
[5]: https://developer.apple.com/documentation/network/nwbrowser/descriptor-swift.enum/bonjourwithtxtrecord%28type%3Adomain%3A%29?utm_source=chatgpt.com "NWBrowser.Descriptor.bonjourWithTXTRecord(type:domain:)"
[6]: https://developer.apple.com/documentation/network/nwbrowser/result/metadata-swift.enum?utm_source=chatgpt.com "NWBrowser.Result.Metadata"
[7]: https://developer.apple.com/documentation/foundation/netservice?utm_source=chatgpt.com "NetService | Apple Developer Documentation"
