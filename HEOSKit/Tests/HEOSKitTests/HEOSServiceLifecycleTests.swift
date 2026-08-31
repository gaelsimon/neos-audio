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

    // MARK: - A failed group fetch

    /// A getGroups that times out on reconnect used to publish an empty list: the sidebar lost every
    /// group and a stereo pair un-collapsed into two rows until the next groups_changed.
    @Test @MainActor func aFailedGroupFetchLeavesTheGroupsOnScreenAlone() async {
        let state = MockStateUpdater()
        let pair = SpeakerGroup(
            gid: 1,
            name: "Kitchen Left",
            players: [
                GroupPlayer(name: "Kitchen Left", pid: 1, role: .leader),
                GroupPlayer(name: "Kitchen Right", pid: 2, role: .member)
            ]
        )
        state.groups = [pair]
        state.multiRoomGroupIDs = []
        // No services: every fetch reads as a failure, which is the reconnect-after-a-blip case.
        let service = HEOSService(stateUpdater: state)

        await service.loadStateTwoPhase()

        #expect(state.groups.map(\.gid) == [1])
        #expect(state.calls.contains { $0.hasPrefix("setGroups") } == false)
    }
}
