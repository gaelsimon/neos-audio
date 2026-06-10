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

    func startReconnection(using connect: @escaping ConnectAction) {
        isReconnecting = true
        reconnectTask?.cancel()
        reconnectTask = Task {
            var delay: TimeInterval = 1.0
            let maxDelay: TimeInterval = 60.0

            while !Task.isCancelled {
                await stateUpdater.setConnectionState(.reconnecting)
                HEOSLogger.service.info("Reconnecting in \(delay)s...")
                try? await Task.sleep(for: .seconds(delay))

                guard !Task.isCancelled,
                      let host = lastHost,
                      let port = lastPort else { break }

                do {
                    try await connect(host, port, lastPlayerID)
                    HEOSLogger.service.info("Reconnected successfully")
                    return
                } catch {
                    HEOSLogger.service.warning("Reconnection failed: \(error.localizedDescription)")
                    delay = min(delay * 2, maxDelay)
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
