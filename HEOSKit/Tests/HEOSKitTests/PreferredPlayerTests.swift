import Testing
import NeosDomain
@testable import HEOSKit

@Suite("Preferred Player Selection")
struct PreferredPlayerTests {

    // MARK: - No cached PID (loadStateTwoPhase path)

    @Test func emptyPlayerListReturnsNil() {
        let result = preferredPlayer(from: [], groups: [], cachedPID: nil)
        #expect(result == nil)
    }

    @Test func singlePlayerReturnsIt() {
        let home150 = Player(pid: 100, name: "Home 150", lineout: 0)
        let result = preferredPlayer(from: [home150], groups: [], cachedPID: nil)
        #expect(result?.pid == 100)
    }

    @Test func prefersStandaloneSpeakerOverAVRZone() {
        // AVR Zone 2 comes first in the list (lineout > 0), Home 150 second (lineout == 0)
        let zone2 = Player(pid: 1, name: "Denon Zone 2", lineout: 2, control: 3)
        let home150 = Player(pid: 2, name: "Home 150", lineout: 0)
        let result = preferredPlayer(from: [zone2, home150], groups: [], cachedPID: nil)
        #expect(result?.pid == 2)
    }

    @Test func prefersLineoutZeroOverLineoutOne() {
        let variableLineout = Player(pid: 1, name: "AVR Aux", lineout: 1)
        let speaker = Player(pid: 2, name: "Speaker", lineout: 0)
        let result = preferredPlayer(from: [variableLineout, speaker], groups: [], cachedPID: nil)
        #expect(result?.pid == 2)
    }

    @Test func allStandaloneSpeakersPicksFirst() {
        let a = Player(pid: 10, name: "Kitchen", lineout: 0)
        let b = Player(pid: 20, name: "Bedroom", lineout: 0)
        let result = preferredPlayer(from: [a, b], groups: [], cachedPID: nil)
        #expect(result?.pid == 10)
    }

    @Test func allAVRZonesPicksFirst() {
        // If only AVR zones exist, still pick one
        let zone1 = Player(pid: 1, name: "Main Zone", lineout: 2)
        let zone2 = Player(pid: 2, name: "Zone 2", lineout: 2)
        let result = preferredPlayer(from: [zone1, zone2], groups: [], cachedPID: nil)
        #expect(result?.pid == 1)
    }

    // MARK: - With cached PID (loadAllStateParallel path)

    @Test func cachedPIDExistsInListReturnsCachedPlayer() {
        let zone2 = Player(pid: 1, name: "Zone 2", lineout: 2)
        let home150 = Player(pid: 100, name: "Home 150", lineout: 0)
        let result = preferredPlayer(from: [zone2, home150], groups: [], cachedPID: 100)
        #expect(result?.pid == 100)
    }

    @Test func cachedPIDNotInListFallsBackToPreference() {
        // Cached PID 999 no longer exists; fall back to standalone speaker heuristic
        let zone2 = Player(pid: 1, name: "Zone 2", lineout: 2)
        let home150 = Player(pid: 2, name: "Home 150", lineout: 0)
        let result = preferredPlayer(from: [zone2, home150], groups: [], cachedPID: 999)
        #expect(result?.pid == 2)
    }

    @Test func cachedPIDIsAVRZoneButExistsStillHonored() {
        // If user explicitly selected an AVR zone last time, respect that
        let zone2 = Player(pid: 1, name: "Zone 2", lineout: 2)
        let home150 = Player(pid: 2, name: "Home 150", lineout: 0)
        let result = preferredPlayer(from: [zone2, home150], groups: [], cachedPID: 1)
        #expect(result?.pid == 1)
    }

    // MARK: - Mixed scenarios

    @Test func multiplePlayersWithMixedLineoutPrefersSpeaker() {
        let mainZone = Player(pid: 1, name: "Main Zone", lineout: 2)
        let zone2 = Player(pid: 2, name: "Zone 2", lineout: 2)
        let home150 = Player(pid: 3, name: "Home 150 Pair", lineout: 0)
        let home350 = Player(pid: 4, name: "Home 350", lineout: 0)
        let result = preferredPlayer(from: [mainZone, zone2, home150, home350], groups: [], cachedPID: nil)
        // Should pick the first standalone speaker
        #expect(result?.pid == 3)
    }

    // MARK: - Stereo pair / group awareness

    private func stereoPair() -> SpeakerGroup {
        SpeakerGroup(gid: 100, name: "Kitchen", players: [
            GroupPlayer(name: "Kitchen Left", pid: 100, role: .leader),
            GroupPlayer(name: "Kitchen Right", pid: 101, role: .member)
        ])
    }

    @Test func neverPicksAGroupMemberAsDefault() {
        // Member (pid 101) sorts first, but the leader must be chosen.
        let member = Player(pid: 101, name: "Kitchen Right", lineout: 0)
        let leader = Player(pid: 100, name: "Kitchen Left", lineout: 0)
        let result = preferredPlayer(from: [member, leader], groups: [stereoPair()], cachedPID: nil)
        #expect(result?.pid == 100)
    }

    @Test func cachedMemberPIDResolvesToLeader() {
        let leader = Player(pid: 100, name: "Kitchen Left", lineout: 0)
        let member = Player(pid: 101, name: "Kitchen Right", lineout: 0)
        let result = preferredPlayer(from: [leader, member], groups: [stereoPair()], cachedPID: 101)
        #expect(result?.pid == 100)
    }
}
