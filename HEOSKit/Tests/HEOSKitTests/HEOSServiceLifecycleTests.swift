import Testing
import Foundation
@testable import HEOSKit
import NeosDomain

@Suite("HEOSService Suspend/Resume Tests")
struct HEOSServiceLifecycleTests {

    @Test @MainActor func suspendWithoutASessionDoesNothing() async {
        let state = MockStateUpdater()
        let service = HEOSService(stateUpdater: state)

        await service.suspend()

        #expect(state.connectionState == nil)
    }

    @Test @MainActor func suspendKeepsTheReconnectTarget() async {
        let state = MockStateUpdater()
        let service = HEOSService(stateUpdater: state)
        await service.connectionCoordinator.recordConnection(host: "192.0.2.10", port: 1255, playerID: 7)

        await service.suspend()

        let host = await service.connectionCoordinator.lastHost
        let pid = await service.connectionCoordinator.lastPlayerID
        #expect(host == "192.0.2.10")
        #expect(pid == 7)
        #expect(state.connectionState == .reconnecting)
    }

    @Test @MainActor func resumeWithoutASessionDoesNothing() async {
        let state = MockStateUpdater()
        let service = HEOSService(stateUpdater: state)

        await service.resume()

        let isReconnecting = await service.connectionCoordinator.isReconnecting
        #expect(isReconnecting == false)
    }

    /// Reconnecting keeps the dead connection, so resuming must read the flag, not the nil-ness.
    @Test func resumeIsWorthDoingWhileReconnectingWithAStaleConnection() {
        #expect(HEOSService.shouldResume(hasTarget: true, hasConnection: true, isReconnecting: true))
        #expect(HEOSService.shouldResume(hasTarget: true, hasConnection: false, isReconnecting: false))
        #expect(HEOSService.shouldResume(hasTarget: true, hasConnection: true, isReconnecting: false) == false)
        #expect(HEOSService.shouldResume(hasTarget: false, hasConnection: false, isReconnecting: true) == false)
    }

    @Test @MainActor func disconnectForgetsTheTargetSoASleepCannotResurrectIt() async {
        let state = MockStateUpdater()
        let service = HEOSService(stateUpdater: state)
        await service.connectionCoordinator.recordConnection(host: "192.0.2.10", port: 1255, playerID: nil)

        await service.disconnect()
        await service.suspend()
        await service.resume()

        let host = await service.connectionCoordinator.lastHost
        let isReconnecting = await service.connectionCoordinator.isReconnecting
        #expect(host == nil)
        #expect(isReconnecting == false)
        #expect(state.connectionState == .disconnected)
    }

    @Test @MainActor func resumeRestartsReconnectionForTheSuspendedTarget() async {
        let state = MockStateUpdater()
        let service = HEOSService(stateUpdater: state)
        await service.connectionCoordinator.recordConnection(host: "192.0.2.10", port: 1255, playerID: nil)
        await service.suspend()

        await service.resume()

        let isReconnecting = await service.connectionCoordinator.isReconnecting
        #expect(isReconnecting == true)

        await service.disconnect()
    }
}
