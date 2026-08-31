import Foundation
import NeosDomain
import os

/// Manages automatic reconnection with exponential backoff.
/// Extracted from HEOSService to isolate connection lifecycle concerns.
actor ConnectionCoordinator {
    private let stateUpdater: StateUpdater
    private var reconnectTask: Task<Void, Never>?
    private(set) var isReconnecting = false
    private(set) var lastHost: String?
    private(set) var lastPort: Int?
    private(set) var lastPlayerID: Int?

    typealias ConnectAction = @Sendable (_ host: String, _ port: Int, _ cachedPlayerID: Int?) async throws -> Void

    init(stateUpdater: StateUpdater) {
        self.stateUpdater = stateUpdater
    }

    func recordConnection(host: String, port: Int, playerID: Int?) {
        lastHost = host
        lastPort = port
        lastPlayerID = playerID
        isReconnecting = false
    }

    func updateLastPlayerID(_ pid: Int?) {
        lastPlayerID = pid
    }

    /// Forgets the target, so a later wake-up cannot resurrect a session the user ended.
    func clearTarget() {
        lastHost = nil
        lastPort = nil
        lastPlayerID = nil
    }

    /// `initialDelay` is 0 when a wake-up or a network change makes an immediate attempt worthwhile.
    func startReconnection(initialDelay: TimeInterval = 1.0, using connect: @escaping ConnectAction) {
        isReconnecting = true
        reconnectTask?.cancel()
        reconnectTask = Task {
            var delay = initialDelay
            let maxDelay: TimeInterval = 60.0

            while !Task.isCancelled {
                await stateUpdater.setConnectionState(.reconnecting)
                HEOSLogger.service.info("Reconnecting in \(delay)s...")
                if delay > 0 {
                    try? await Task.sleep(for: .seconds(delay))
                }

                guard !Task.isCancelled,
                      let host = lastHost,
                      let port = lastPort else { break }

                do {
                    try await connect(host, port, lastPlayerID)
                    HEOSLogger.service.info("Reconnected successfully")
                    return
                } catch {
                    HEOSLogger.service.warning("Reconnection failed: \(error.localizedDescription)")
                    delay = min(max(delay * 2, 1.0), maxDelay)
                }
            }
        }
    }

    func cancelReconnection() {
        reconnectTask?.cancel()
        reconnectTask = nil
        isReconnecting = false
    }

    /// True when we have an active, non-reconnecting state.
    var isHealthy: Bool {
        !isReconnecting
    }
}
