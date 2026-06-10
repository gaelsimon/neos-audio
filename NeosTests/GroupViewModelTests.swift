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
}
