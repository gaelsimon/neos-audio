import Foundation
import Network
import os

/// Thread-safe accumulator for a one-shot browse.
final class DeviceCollector: Sendable {
    private let devices = OSAllocatedUnfairLock(initialState: [DiscoveredDevice]())

    var all: [DiscoveredDevice] { devices.withLock { $0 } }

    func append(_ device: DiscoveredDevice) {
        devices.withLock { $0.append(device) }
        HEOSLogger.discovery.info("Bonjour resolved: \(device.friendlyName) at \(device.host)")
    }
}

/// Per-browse dedup set plus a kill switch, so retries stop when the browser is cancelled.
final class BonjourResolveSession: Sendable {
    let seenHosts = OSAllocatedUnfairLock(initialState: Set<String>())
    private let active = OSAllocatedUnfairLock(initialState: true)

    var isActive: Bool { active.withLock { $0 } }

    func end() {
        active.withLock { $0 = false }
    }
}

public actor BonjourDiscovery {
    private var browser: NWBrowser?
    private var continuousContinuation: AsyncStream<DiscoveredDevice>.Continuation?
    private var continuousSession: BonjourResolveSession?
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
        let collector = DeviceCollector()
        let session = BonjourResolveSession()

        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: params)

        // Single serial queue for all callbacks to avoid data races
        let resolveQueue = DispatchQueue(label: "com.galela.neos.bonjour-resolve")

        browser.browseResultsChangedHandler = Self.makeResultsHandler(
            session: session,
            resolveQueue: resolveQueue
        ) { device in
            collector.append(device)
        }
        browser.stateUpdateHandler = Self.logBrowserFailures
        browser.start(queue: resolveQueue)

        try? await Task.sleep(for: .seconds(timeout))
        session.end()
        browser.cancel()
        // Hop onto the resolve queue first: a probe that turned ready just before the timeout
        // still has its callback queued, and reading straight away would drop that speaker.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            resolveQueue.async { continuation.resume() }
        }
        return collector.all
    }

    // MARK: - Continuous discovery

    public func startContinuous() -> AsyncStream<DiscoveredDevice> {
        stop()

        let (stream, continuation) = AsyncStream<DiscoveredDevice>.makeStream()
        self.continuousContinuation = continuation
        let session = BonjourResolveSession()
        self.continuousSession = session

        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: Self.serviceType, domain: nil), using: params)
        self.browser = browser

        let resolveQueue = DispatchQueue(label: "com.galela.neos.bonjour-continuous")

        browser.browseResultsChangedHandler = Self.makeResultsHandler(
            session: session,
            resolveQueue: resolveQueue
        ) { device in
            continuation.yield(device)
            HEOSLogger.discovery.info("Bonjour continuous: \(device.friendlyName) at \(device.host)")
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

    private static let logBrowserFailures: @Sendable (NWBrowser.State) -> Void = { state in
        if case .failed(let error) = state {
            HEOSLogger.discovery.warning("Bonjour browser failed: \(error.localizedDescription)")
        }
    }

    /// Resolves every result of a browse update through `resolveEndpoint`.
    private static func makeResultsHandler(
        session: BonjourResolveSession,
        resolveQueue: DispatchQueue,
        onDevice: @escaping @Sendable (DiscoveredDevice) -> Void
    ) -> @Sendable (Set<NWBrowser.Result>, Set<NWBrowser.Result.Change>) -> Void {
        { results, _ in
            for result in results {
                resolveEndpoint(result: result, session: session, resolveQueue: resolveQueue, onDevice: onDevice)
            }
        }
    }

    /// A `.waiting` probe usually finds its route within a few hundred ms; only give up if it doesn't.
    static let waitingGrace: TimeInterval = 0.5

    /// 1s, 2s, 4s, then give up: one lost probe must not silence the only reliable channel.
    static func retryDelay(forAttempt attempt: Int) -> TimeInterval? {
        guard attempt < 3 else { return nil }
        return pow(2.0, Double(attempt))
    }

    /// Resolves a browse result to a device over UDP, deduplicated by IPv4 host, retried on failure.
    private static func resolveEndpoint(
        result: NWBrowser.Result,
        session: BonjourResolveSession,
        resolveQueue: DispatchQueue,
        attempt: Int = 0,
        onDevice: @escaping @Sendable (DiscoveredDevice) -> Void
    ) {
        guard case .service(let serviceName, let type, let domain, _) = result.endpoint else { return }
        HEOSLogger.discovery.debug("Bonjour found: \(serviceName) (\(type).\(domain))")

        // Use UDP to resolve the service endpoint; no TCP handshake,
        // no packets sent to the device, avoids RST storms on ports
        // the device doesn't listen on.
        let connection = NWConnection(to: result.endpoint, using: ipv4UDPParams)
        let finish = makeFinishHandler(
            connection: connection,
            result: result,
            session: session,
            resolveQueue: resolveQueue,
            attempt: attempt,
            onDevice: onDevice
        )

        connection.stateUpdateHandler = { connState in
            switch connState {
            case .ready:
                if let device = resolvedDevice(
                    connection: connection,
                    result: result,
                    serviceName: serviceName,
                    session: session
                ) {
                    onDevice(device)
                }
                finish(true)
            case .waiting:
                // Transient "no route yet": killing the probe here costs a full retry delay, which
                // in a 3 s browse lands after the session ended and loses the device entirely.
                resolveQueue.asyncAfter(deadline: .now() + waitingGrace) { finish(false) }
            case .failed:
                finish(false)
            default:
                break
            }
        }
        connection.start(queue: resolveQueue)
    }

    /// Settles one probe once, scheduling the next attempt when it failed and the browse is live.
    private static func makeFinishHandler(
        connection: NWConnection,
        result: NWBrowser.Result,
        session: BonjourResolveSession,
        resolveQueue: DispatchQueue,
        attempt: Int,
        onDevice: @escaping @Sendable (DiscoveredDevice) -> Void
    ) -> @Sendable (Bool) -> Void {
        let settled = OSAllocatedUnfairLock(initialState: false)

        return { succeeded in
            let isFirst = settled.withLock { done -> Bool in
                guard !done else { return false }
                done = true
                return true
            }
            guard isFirst else { return }
            connection.cancel()

            guard !succeeded, session.isActive, let delay = retryDelay(forAttempt: attempt) else { return }
            HEOSLogger.discovery.debug("Bonjour resolve failed; retrying in \(delay)s")
            resolveQueue.asyncAfter(deadline: .now() + delay) {
                guard session.isActive else { return }
                resolveEndpoint(
                    result: result,
                    session: session,
                    resolveQueue: resolveQueue,
                    attempt: attempt + 1,
                    onDevice: onDevice
                )
            }
        }
    }

    /// The device behind a ready connection, or nil when the endpoint is IPv6 or already known.
    private static func resolvedDevice(
        connection: NWConnection,
        result: NWBrowser.Result,
        serviceName: String,
        session: BonjourResolveSession
    ) -> DiscoveredDevice? {
        guard let endpoint = connection.currentPath?.remoteEndpoint,
              case .hostPort(let host, _) = endpoint else { return nil }

        let hostStr = "\(host)".replacingOccurrences(of: "%.*", with: "", options: .regularExpression)

        // Skip IPv6 (link-local fe80:: etc.); HEOS CLI needs IPv4
        guard !hostStr.contains(":") else { return nil }

        let alreadySeen = session.seenHosts.withLock { $0.contains(hostStr) }
        guard !alreadySeen else { return nil }
        session.seenHosts.withLock { _ = $0.insert(hostStr) }

        let metadata = extractTXTMetadata(from: result.metadata)
        return DiscoveredDevice(
            host: hostStr,
            port: 1255,
            friendlyName: metadata.name ?? serviceName,
            modelName: metadata.model ?? "",
            firmwareVersion: metadata.version ?? "",
            deviceID: metadata.deviceID ?? "",
            networkID: metadata.networkID ?? ""
        )
    }

    public func stop() {
        continuousSession?.end()
        continuousSession = nil
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
