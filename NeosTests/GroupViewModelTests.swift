import XCTest
@testable import Neos
import NeosDomain

final class GroupViewModelTests: XCTestCase {

    // MARK: - createGroup

    @MainActor
    func testCreateGroupGuardsEmptyMembers() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = GroupViewModel(service: mock, state: state)

        vm.selectedMemberPIDs = []
        vm.createGroup(leaderPID: 1)

        await yieldForTask()
        let calls = mock.calls
        XCTAssertFalse(calls.contains(where: { $0.hasPrefix("createGroup") }))
    }

    @MainActor
    func testCreateGroupExcludesLeaderFromMembers() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = GroupViewModel(service: mock, state: state)

        vm.selectedMemberPIDs = [1, 2, 3]
        vm.createGroup(leaderPID: 1)

        await yieldForTask()
        let calls = mock.calls
        // Should have called createGroup with leader 1 and members [2, 3] (1 excluded)
        XCTAssertTrue(calls.contains(where: { $0.hasPrefix("createGroup:1:") }))
        XCTAssertFalse(vm.isCreatingGroup)
    }

    @MainActor
    func testCreateGroupGuardsOnlyLeaderInMembers() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = GroupViewModel(service: mock, state: state)

        // Only the leader is selected; filtering it out leaves empty
        vm.selectedMemberPIDs = [1]
        vm.createGroup(leaderPID: 1)

        await yieldForTask()
        let calls = mock.calls
        XCTAssertFalse(calls.contains(where: { $0.hasPrefix("createGroup") }))
    }

    @MainActor
    func testCreateGroupClearsSelectionOnSuccess() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = GroupViewModel(service: mock, state: state)

        vm.selectedMemberPIDs = [1, 2]
        vm.createGroup(leaderPID: 1)

        await yieldForTask()
        XCTAssertTrue(vm.selectedMemberPIDs.isEmpty)
    }

    // MARK: - loadGroups

    @MainActor
    func testLoadGroupsUpdatesState() async {
        let state = AppState()
        let mock = MockAudioService()
        let group = SpeakerGroup(gid: 10, name: "Living", players: [])
        mock.groups = [group]
        let vm = GroupViewModel(service: mock, state: state)

        vm.loadGroups()

        await yieldForTask()
        XCTAssertEqual(state.groups.count, 1)
        XCTAssertEqual(state.groups[0].gid, 10)
        XCTAssertFalse(vm.isLoadingGroups)
    }

    // MARK: - ungroup

    @MainActor
    func testUngroupCallsService() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = GroupViewModel(service: mock, state: state)

        vm.ungroup(pid: 5)

        await yieldForTask()
        let calls = mock.calls
        XCTAssertTrue(calls.contains("ungroup:5"))
        XCTAssertFalse(vm.isUngrouping)
    }

    @MainActor
    func testUngroupSetsErrorOnFailure() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.ungroupError = NSError(domain: "test", code: 1)
        let vm = GroupViewModel(service: mock, state: state)

        vm.ungroup(pid: 5)

        await yieldForTask()
        XCTAssertNotNil(state.error)
    }

    // MARK: - Per-speaker volume

    @MainActor
    func testLoadMemberVolumesPopulatesEachMember() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.playerVolume = 37
        let vm = GroupViewModel(service: mock, state: state)
        let group = SpeakerGroup(gid: 1, name: "Den + Bath", players: [
            GroupPlayer(name: "Den", pid: 5003, role: .leader),
            GroupPlayer(name: "Bath", pid: 5004, role: .member)
        ])

        vm.loadMemberVolumes(for: group)

        await yieldForTask()
        XCTAssertEqual(state.playerVolumes[5003], 37)
        XCTAssertEqual(state.playerVolumes[5004], 37)
    }

    @MainActor
    func testSetMemberVolumeCallsServiceWithPid() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = GroupViewModel(service: mock, state: state)

        vm.setMemberVolume(pid: 5004, level: 25)

        // Debounced ~100ms; poll rather than fixed sleep.
        for _ in 0..<100 where !mock.calls.contains("setVolume:5004:25") {
            try? await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(mock.calls.contains("setVolume:5004:25"))
    }

    @MainActor
    func testSetAdjustingMemberVolumeTogglesState() {
        let state = AppState()
        let vm = GroupViewModel(service: MockAudioService(), state: state)
        vm.setAdjustingMemberVolume(pid: 5004, true)
        XCTAssertTrue(state.adjustingVolumePIDs.contains(5004))
        vm.setAdjustingMemberVolume(pid: 5004, false)
        XCTAssertFalse(state.adjustingVolumePIDs.contains(5004))
    }
}
