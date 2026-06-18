import Testing
@testable import NeosDomain

@Suite("Group Topology")
struct GroupTopologyTests {

    private let pair = SpeakerGroup(gid: 100, name: "Kitchen", players: [
        GroupPlayer(name: "Kitchen Left", pid: 100, role: .leader),
        GroupPlayer(name: "Kitchen Right", pid: 101, role: .member)
    ])

    private func players() -> [Player] {
        [
            Player(pid: 100, name: "Kitchen Left", lineout: 0),
            Player(pid: 101, name: "Kitchen Right", lineout: 0),
            Player(pid: 200, name: "Bedroom", lineout: 0)
        ]
    }

    @Test func groupedMemberPIDsExcludesLeader() {
        #expect([pair].groupedMemberPIDs == [101])
    }

    @Test func leaderPIDResolvesMemberToLeader() {
        #expect([pair].leaderPID(for: 101) == 100)
    }

    @Test func leaderPIDLeavesLeaderUnchanged() {
        #expect([pair].leaderPID(for: 100) == 100)
    }

    @Test func leaderPIDLeavesUngroupedPlayerUnchanged() {
        #expect([pair].leaderPID(for: 200) == 200)
    }

    @Test func groupLedByFindsTheGroup() {
        #expect([pair].group(ledBy: 100)?.gid == 100)
        #expect([pair].group(ledBy: 101) == nil)
    }

    @Test func collapsingGroupsHidesMembersKeepsLeaderAndStandalones() {
        let visible = players().collapsingGroups([pair])
        #expect(visible.map(\.pid) == [100, 200])
    }

    @Test func collapsingGroupsIsNoOpWithoutGroups() {
        let all = players()
        #expect(all.collapsingGroups([]).map(\.pid) == all.map(\.pid))
    }
}
