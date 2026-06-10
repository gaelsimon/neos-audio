import Foundation
import Network
import os

public actor BonjourDiscovery {
    private var browser: NWBrowser?
    private var continuousContinuation: AsyncStream<DiscoveredDevice>.Continuation?
    private static let serviceType = "_heos-audio._tcp"

    public init() {}

    /// UDP parameters that force IPv4 resolution; HEOS CLI requires IPv4.
    private static var ipv4UDPParams: NWParameters {
        let params = NWParameters.udp
        if let ipOptions = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ipOptions.version = .v4
        }
        return params
    }

    // MARK: - One-shot discovery

    public func discover(timeout: TimeInterval = 3.0) async -> [DiscoveredDevice] {
        await withCheckedContinuation { continuation in
            let devices = OSAllocatedUnfairLock(initialState: [DiscoveredDevice]())
            let seenHosts = OSAllocatedUnfairLock(initialState: Set<String>())

            let params = NWParameters()
            params.includePeerToPeer = true
            let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: params)

            // Single serial queue for all callbacks to avoid data races
            let resolveQueue = DispatchQueue(label: "com.galela.neos.bonjour-resolve")

            browser.browseResultsChangedHandler = { results, _ in
                for result in results {
                    Self.resolveEndpoint(result: result, seenHosts: seenHosts, resolveQueue: resolveQueue) { device in
                        devices.withLock { $0.append(device) }
                        HEOSLogger.discovery.info("Bonjour resolved: \(device.friendlyName) at \(device.host)")
                    }
                }
            }

            browser.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    HEOSLogger.discovery.warning("Bonjour browser failed: \(error.localizedDescription)")
                }
            }

            browser.start(queue: resolveQueue)

            Task {
                try? await Task.sleep(for: .seconds(timeout))
                browser.cancel()
                resolveQueue.async {
                    let finalDevices = devices.withLock { $0 }
                    continuation.resume(returning: finalDevices)
                }
            }
        }
    }

    // MARK: - Continuous discovery

    public func startContinuous() -> AsyncStream<DiscoveredDevice> {
        stop()

        let (stream, continuation) = AsyncStream<DiscoveredDevice>.makeStream()
        self.continuousContinuation = continuation
        let seenHosts = OSAllocatedUnfairLock(initialState: Set<String>())

        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: params)
        self.browser = browser

        let resolveQueue = DispatchQueue(label: "com.galela.neos.bonjour-continuous")

        browser.browseResultsChangedHandler = { results, _ in
            for result in results {
                Self.resolveEndpoint(result: result, seenHosts: seenHosts, resolveQueue: resolveQueue) { device in
                    continuation.yield(device)
                    HEOSLogger.discovery.info("Bonjour continuous: \(device.friendlyName) at \(device.host)")
                }
            }
        }

        browser.stateUpdateHandler = { state in
            if case .failed(let error) = state {
                HEOSLogger.discovery.warning("Bonjour continuous browser failed: \(error.localizedDescription)")
            }
            if case .cancelled = state {
                continuation.finish()
            }
        }

        browser.start(queue: resolveQueue)
        return stream
    }

    // MARK: - Endpoint Resolution

    /// Resolve a Bonjour browse result to a DiscoveredDevice via a lightweight UDP connection.
    /// Deduplicates by IPv4 host using the shared `seenHosts` lock. Calls `onDevice` on success.
    private static func resolveEndpoint(
        result: NWBrowser.Result,
        seenHosts: OSAllocatedUnfairLock<Set<String>>,
        resolveQueue: DispatchQueue,
        onDevice: @escaping @Sendable (DiscoveredDevice) -> Void
    ) {
        let serviceName: String?
        if case .service(let name, let type, let domain, _) = result.endpoint {
            serviceName = name
            HEOSLogger.discovery.debug("Bonjour found: \(name) (\(type).\(domain))")
        } else {
            serviceName = nil
        }

        guard case .service = result.endpoint else { return }

        // Use UDP to resolve the service endpoint; no TCP handshake,
        // no packets sent to the device, avoids RST storms on ports
        // the device doesn't listen on.
        let connection = NWConnection(to: result.endpoint, using: ipv4UDPParams)
        connection.stateUpdateHandler = { connState in
            if case .ready = connState {
                if let endpoint = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, _) = endpoint {
                    let hostStr = "\(host)"
                        .replacingOccurrences(of: "%.*", with: "", options: .regularExpression)

                    // Skip IPv6 (link-local fe80:: etc.); HEOS CLI needs IPv4
                    guard !hostStr.contains(":") else {
                        connection.cancel()
                        return
                    }

                    let alreadySeen = seenHosts.withLock { $0.contains(hostStr) }
                    guard !alreadySeen else {
                        connection.cancel()
                        return
                    }
                    seenHosts.withLock { _ = $0.insert(hostStr) }

                    let metadata = extractTXTMetadata(from: result.metadata)
                    let device = DiscoveredDevice(
                        host: hostStr,
                        port: 1255,
                        friendlyName: metadata.name ?? serviceName ?? hostStr,
                        modelName: metadata.model ?? "",
                        firmwareVersion: metadata.version ?? "",
                        deviceID: metadata.deviceID ?? "",
                        networkID: metadata.networkID ?? ""
                    )
                    onDevice(device)
                }
                connection.cancel()
            } else if case .failed = connState {
                connection.cancel()
            }
        }
        connection.start(queue: resolveQueue)
    }

    public func stop() {
        browser?.cancel()
        browser = nil
        continuousContinuation?.finish()
        continuousContinuation = nil
    }

    // MARK: - TXT Record Parsing

    private struct TXTMetadata {
        let name: String?
        let model: String?
        let version: String?
        let deviceID: String?
        let networkID: String?
    }

    private static func extractTXTMetadata(from metadata: NWBrowser.Result.Metadata?) -> TXTMetadata {
        guard let metadata, case .bonjour(let txtRecord) = metadata else {
            return TXTMetadata(name: nil, model: nil, version: nil, deviceID: nil, networkID: nil)
        }

        return TXTMetadata(
            name: txtRecord["name"],
            model: txtRecord["model"],
            version: txtRecord["vers"],
            deviceID: txtRecord["did"],
            networkID: txtRecord["networkid"]
        )
    }
}
