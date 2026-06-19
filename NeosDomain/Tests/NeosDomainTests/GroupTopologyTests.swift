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

    // MARK: - leaderPID

    @Test func leaderPIDResolvesMemberToLeader() {
        #expect([pair].leaderPID(for: 101) == 100)
    }

    @Test func leaderPIDLeavesLeaderUnchanged() {
        #expect([pair].leaderPID(for: 100) == 100)
    }

    @Test func leaderPIDLeavesUngroupedPlayerUnchanged() {
        #expect([pair].leaderPID(for: 200) == 200)
    }

    @Test func leaderPIDDoesNotResolveForExpandedGroup() {
        // Expanded (multi-room) group: a member stays individually selectable.
        #expect([pair].leaderPID(for: 101, expanded: [100]) == 101)
    }

    @Test func groupLedByFindsTheGroup() {
        #expect([pair].group(ledBy: 100)?.gid == 100)
        #expect([pair].group(ledBy: 101) == nil)
    }

    // MARK: - collapsingGroups

    @Test func collapsingGroupsHidesMembersKeepsLeaderAndStandalones() {
        let visible = players().collapsingGroups([pair])
        #expect(visible.map(\.pid) == [100, 200])
    }

    @Test func collapsingGroupsIsNoOpWithoutGroups() {
        let all = players()
        #expect(all.collapsingGroups([]).map(\.pid) == all.map(\.pid))
    }

    @Test func collapsingGroupsKeepsExpandedGroupMembersVisible() {
        let visible = players().collapsingGroups([pair], expanded: [100])
        #expect(visible.map(\.pid) == [100, 101, 200])
    }

    // MARK: - multiRoomGroupIDs (channel classifier)

    @Test func allNormalChannelsMarksGroupMultiRoom() {
        let channels = [100: "NORMAL", 101: "NORMAL"]
        #expect([pair].multiRoomGroupIDs(channelsByPID: channels) == [100])
    }

    @Test func leftRightChannelsAreNotMultiRoom() {
        let channels = [100: "LEFT", 101: "RIGHT"]
        #expect([pair].multiRoomGroupIDs(channelsByPID: channels).isEmpty)
    }

    @Test func missingChannelExcludesGroup() {
        // A member we couldn't query → not confirmed multi-room → collapse (safe default).
        let channels = [100: "NORMAL"]
        #expect([pair].multiRoomGroupIDs(channelsByPID: channels).isEmpty)
    }
}
