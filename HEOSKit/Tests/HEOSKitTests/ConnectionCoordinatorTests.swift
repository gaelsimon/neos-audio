import Testing
import Foundation
@testable import HEOSKit
import NeosDomain

@Suite("ConnectionCoordinator Tests")
struct ConnectionCoordinatorTests {

    // MARK: - recordConnection

    @Test @MainActor func recordConnectionStoresHostAndPort() async {
        let state = MockStateUpdater()
        let coordinator = ConnectionCoordinator(stateUpdater: state)

        await coordinator.recordConnection(host: "192.168.1.10", port: 1255, playerID: 42)

        let host = await coordinator.lastHost
        let port = await coordinator.lastPort
        let pid = await coordinator.lastPlayerID
        #expect(host == "192.168.1.10")
        #expect(port == 1255)
        #expect(pid == 42)
    }

    @Test @MainActor func recordConnectionClearsReconnecting() async {
        let state = MockStateUpdater()
        let coordinator = ConnectionCoordinator(stateUpdater: state)

        await coordinator.recordConnection(host: "10.0.0.1", port: 1255, playerID: nil)

        let isReconnecting = await coordinator.isReconnecting
        #expect(isReconnecting == false)
    }

    // MARK: - updateLastPlayerID

    @Test @MainActor func updateLastPlayerIDSetsValue() async {
        let state = MockStateUpdater()
        let coordinator = ConnectionCoordinator(stateUpdater: state)

        await coordinator.updateLastPlayerID(99)

        let pid = await coordinator.lastPlayerID
        #expect(pid == 99)
    }

    // MARK: - isHealthy

    @Test @MainActor func isHealthyTrueWhenNotReconnecting() async {
        let state = MockStateUpdater()
        let coordinator = ConnectionCoordinator(stateUpdater: state)

        let healthy = await coordinator.isHealthy
        #expect(healthy == true)
    }

    // MARK: - startReconnection

    @Test @MainActor func startReconnectionSetsReconnectingState() async {
        let state = MockStateUpdater()
        let coordinator = ConnectionCoordinator(stateUpdater: state)
        await coordinator.recordConnection(host: "10.0.0.1", port: 1255, playerID: nil)

        await coordinator.startReconnection { _, _, _ in
            throw TransportError.timeout
        }

        let isReconnecting = await coordinator.isReconnecting
        #expect(isReconnecting == true)

        // Allow time for first reconnection attempt
        try? await Task.sleep(for: .milliseconds(200))

        let healthy = await coordinator.isHealthy
        #expect(healthy == false)

        await coordinator.cancelReconnection()
    }

    @Test @MainActor func startReconnectionCallsConnectOnSuccess() async {
        let state = MockStateUpdater()
        let coordinator = ConnectionCoordinator(stateUpdater: state)
        await coordinator.recordConnection(host: "10.0.0.1", port: 1255, playerID: 42)

        let tracker = CallTracker()
        await coordinator.startReconnection { host, port, pid in
            await tracker.record()
            #expect(host == "10.0.0.1")
            #expect(port == 1255)
            #expect(pid == 42)
        }

        // Wait for the first reconnection attempt (1s delay + connection)
        try? await Task.sleep(for: .milliseconds(1500))

        let wasCalled = await tracker.wasCalled
        #expect(wasCalled == true)
        await coordinator.cancelReconnection()
    }

    // MARK: - cancelReconnection

    @Test @MainActor func cancelReconnectionStopsAttempts() async {
        let state = MockStateUpdater()
        let coordinator = ConnectionCoordinator(stateUpdater: state)
        await coordinator.recordConnection(host: "10.0.0.1", port: 1255, playerID: nil)

        await coordinator.startReconnection { _, _, _ in
            throw TransportError.timeout
        }

        // Cancel immediately before first attempt
        await coordinator.cancelReconnection()

        let isReconnecting = await coordinator.isReconnecting
        #expect(isReconnecting == false)

        let healthy = await coordinator.isHealthy
        #expect(healthy == true)
    }

    // MARK: - Reconnection without host

    @Test @MainActor func startReconnectionWithoutHostExitsEarly() async {
        let state = MockStateUpdater()
        let coordinator = ConnectionCoordinator(stateUpdater: state)
        // No recordConnection called; lastHost is nil

        let tracker = CallTracker()
        await coordinator.startReconnection { _, _, _ in
            await tracker.record()
        }

        try? await Task.sleep(for: .milliseconds(1500))

        let wasCalled = await tracker.wasCalled
        #expect(wasCalled == false)
        await coordinator.cancelReconnection()
    }
}

private actor CallTracker {
    private(set) var wasCalled = false

    func record() {
        wasCalled = true
    }
}
