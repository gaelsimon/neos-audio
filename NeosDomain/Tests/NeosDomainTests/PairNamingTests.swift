import Testing
@testable import NeosDomain

@Suite("Pair Naming")
struct PairNamingTests {

    private func pair(name: String, leader: String, member: String) -> SpeakerGroup {
        SpeakerGroup(gid: 1, name: name, players: [
            GroupPlayer(name: leader, pid: 1, role: .leader),
            GroupPlayer(name: member, pid: 2, role: .member)
        ])
    }

    // MARK: - Reported Case

    @Test func groupNamedAfterLeaderUsesTheSharedRoomName() {
        let group = pair(name: "Kitchen Left", leader: "Kitchen Left", member: "Kitchen Right")

        #expect(group.collapsedDisplayName == "Kitchen")
    }

    @Test func emptyGroupNameUsesTheSharedRoomName() {
        let group = pair(name: "", leader: "Kitchen Left", member: "Kitchen Right")

        #expect(group.collapsedDisplayName == "Kitchen")
    }

    // MARK: - Already Correct

    @Test func meaningfulGroupNameIsKept() {
        let group = pair(name: "Kitchen", leader: "Kitchen Left", member: "Kitchen Right")

        #expect(group.collapsedDisplayName == "Kitchen")
    }

    @Test func multiRoomStyleNameIsKept() {
        let group = pair(name: "Kitchen + Office", leader: "Kitchen", member: "Office")

        #expect(group.collapsedDisplayName == "Kitchen + Office")
    }

    // MARK: - Fallbacks

    @Test func noSharedPrefixFallsBackToLeaderWithoutChannelSuffix() {
        let group = pair(name: "Studio Left", leader: "Studio Left", member: "Bedroom Right")

        #expect(group.collapsedDisplayName == "Studio")
    }

    @Test func noSharedPrefixAndNoChannelSuffixKeepsLeaderName() {
        let group = pair(name: "Living Room", leader: "Living Room", member: "Bedroom")

        #expect(group.collapsedDisplayName == "Living Room")
    }

    @Test func identicalMemberNamesStripTheChannelSuffix() {
        let group = pair(name: "Den L", leader: "Den L", member: "Den L")

        #expect(group.collapsedDisplayName == "Den")
    }

    @Test func shortChannelSuffixesAreRecognized() {
        let group = pair(name: "Patio L", leader: "Patio L", member: "Patio R")

        #expect(group.collapsedDisplayName == "Patio")
    }

    @Test func separatorsCountAsWordBreaks() {
        let group = pair(name: "Salon-Left", leader: "Salon-Left", member: "Salon-Right")

        #expect(group.collapsedDisplayName == "Salon")
    }

    @Test func partialWordMatchFallsBackToTheLeaderName() {
        // "Kit" is not a shared word, so the name comes from the leader, not from a truncation.
        let group = pair(name: "Kit Left", leader: "Kit Left", member: "Kitchen Right")

        #expect(group.collapsedDisplayName == "Kit")
    }

    @Test func surroundSetKeepsTheSharedPrefix() {
        let group = SpeakerGroup(gid: 2, name: "Den Front Left", players: [
            GroupPlayer(name: "Den Front Left", pid: 1, role: .leader),
            GroupPlayer(name: "Den Front Right", pid: 2, role: .member),
            GroupPlayer(name: "Den Rear Left", pid: 3, role: .member)
        ])

        #expect(group.collapsedDisplayName == "Den")
    }

    // MARK: - Pair Names by Serial

    @Test func collapsedPairNamesKeysOnSerialAndLeaderName() {
        let groups = [pair(name: "Kitchen Left", leader: "Kitchen Left", member: "Kitchen Right")]
        let players = [
            Player(pid: 1, name: "Kitchen Left", model: "HEOS 150", version: "1", ip: "10.0.0.1", serial: "SN-L"),
            Player(pid: 2, name: "Kitchen Right", model: "HEOS 150", version: "1", ip: "10.0.0.2", serial: "SN-R")
        ]

        #expect(groups.collapsedPairNames(players: players) == [
            "SN-L": "Kitchen",
            "Kitchen Left": "Kitchen"
        ])
    }

    @Test func collapsedPairNamesStillNameTheLeaderWithoutASerial() {
        let groups = [pair(name: "Kitchen Left", leader: "Kitchen Left", member: "Kitchen Right")]

        // Bonjour results carry no serial, so the leader name has to carry the mapping.
        #expect(groups.collapsedPairNames(players: []) == ["Kitchen Left": "Kitchen"])
    }

    @Test func collapsedFollowerNamesListsMembersOnly() {
        let groups = [pair(name: "Kitchen Left", leader: "Kitchen Left", member: "Kitchen Right")]

        #expect(groups.collapsedFollowerNames() == ["Kitchen Right"])
    }

    @Test func expandedGroupsContributeNoFollowerNames() {
        let groups = [pair(name: "Kitchen Left", leader: "Kitchen Left", member: "Kitchen Right")]

        #expect(groups.collapsedFollowerNames(expanded: [1]).isEmpty)
    }

    @Test func expandedMultiRoomGroupsAreNotNamed() {
        let groups = [pair(name: "Kitchen Left", leader: "Kitchen Left", member: "Kitchen Right")]
        let players = [
            Player(pid: 1, name: "Kitchen Left", model: "HEOS 150", version: "1", ip: "10.0.0.1", serial: "SN-L")
        ]

        #expect(groups.collapsedPairNames(players: players, expanded: [1]).isEmpty)
    }
}
