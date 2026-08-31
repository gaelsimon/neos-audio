import Testing
import Foundation
@testable import HEOSKit
import NeosDomain

@Suite("EventRouter Tests")
struct EventRouterTests {

    // MARK: - Helpers

    private func makeEvent(_ name: String, message: [String: String] = [:]) -> HEOSEvent {
        HEOSEvent(command: "event/\(name)", message: message)
    }

    @MainActor
    private func makeRouter(selectedPID: Int? = 42) -> (EventRouter, MockStateUpdater) {
        let state = MockStateUpdater()
        state.selectedPlayerID = selectedPID
        let router = EventRouter(stateUpdater: state, playerService: nil, groupService: nil, browseService: nil)
        return (router, state)
    }

    // MARK: - Player State Changed

    @Test @MainActor func playerStateChangedUpdatesPlayState() async {
        let (router, state) = makeRouter()
        let event = makeEvent("player_state_changed", message: ["pid": "42", "state": "play"])

        await router.handle(event)

        #expect(state.playState == .play)
    }

    @Test @MainActor func playerStateChangedIgnoresOtherPlayer() async {
        let (router, state) = makeRouter(selectedPID: 42)
        let event = makeEvent("player_state_changed", message: ["pid": "99", "state": "play"])

        await router.handle(event)

        #expect(state.playState == nil)
    }

    @Test @MainActor func playerStateChangedPause() async {
        let (router, state) = makeRouter()
        let event = makeEvent("player_state_changed", message: ["pid": "42", "state": "pause"])

        await router.handle(event)

        #expect(state.playState == .pause)
    }

    @Test @MainActor func playerStateChangedStop() async {
        let (router, state) = makeRouter()
        let event = makeEvent("player_state_changed", message: ["pid": "42", "state": "stop"])

        await router.handle(event)

        #expect(state.playState == .stop)
    }

    // MARK: - Progress

    @Test @MainActor func nowPlayingProgressUpdatesPositionAndDuration() async {
        let (router, state) = makeRouter()
        let event = makeEvent("player_now_playing_progress", message: ["pid": "42", "cur_pos": "30000", "duration": "240000"])

        await router.handle(event)

        #expect(state.progressPosition == 30000)
        #expect(state.progressDuration == 240000)
    }

    @Test @MainActor func progressIgnoresOtherPlayer() async {
        let (router, state) = makeRouter(selectedPID: 42)
        let event = makeEvent("player_now_playing_progress", message: ["pid": "99", "cur_pos": "100", "duration": "200"])

        await router.handle(event)

        #expect(state.progressPosition == nil)
    }

    // MARK: - Volume

    @Test @MainActor func playerVolumeChangedUpdatesLevel() async {
        let (router, state) = makeRouter()
        let event = makeEvent("player_volume_changed", message: ["pid": "42", "level": "65"])

        await router.handle(event)

        #expect(state.volume == 65)
    }

    @Test @MainActor func playerVolumeChangedUpdatesMute() async {
        let (router, state) = makeRouter()
        let event = makeEvent("player_volume_changed", message: ["pid": "42", "level": "50", "mute": "on"])

        await router.handle(event)

        #expect(state.volume == 50)
        #expect(state.isMuted == true)
    }

    @Test @MainActor func playerVolumeChangedMuteOff() async {
        let (router, state) = makeRouter()
        let event = makeEvent("player_volume_changed", message: ["pid": "42", "level": "50", "mute": "off"])

        await router.handle(event)

        #expect(state.isMuted == false)
    }

    @Test @MainActor func volumeIgnoresOtherPlayer() async {
        let (router, state) = makeRouter(selectedPID: 42)
        let event = makeEvent("player_volume_changed", message: ["pid": "99", "level": "80"])

        await router.handle(event)

        #expect(state.volume == nil)
    }

    // MARK: - Repeat/Shuffle Mode

    @Test @MainActor func repeatModeChangedUpdatesState() async {
        let (router, state) = makeRouter()
        let event = makeEvent("repeat_mode_changed", message: ["pid": "42", "repeat": "on_all"])

        await router.handle(event)

        #expect(state.repeatMode == .onAll)
    }

    @Test @MainActor func shuffleModeChangedUpdatesState() async {
        let (router, state) = makeRouter()
        let event = makeEvent("shuffle_mode_changed", message: ["pid": "42", "shuffle": "on"])

        await router.handle(event)

        #expect(state.shuffleMode == .on)
    }

    @Test @MainActor func repeatModeIgnoresOtherPlayer() async {
        let (router, state) = makeRouter(selectedPID: 42)
        let event = makeEvent("repeat_mode_changed", message: ["pid": "99", "repeat": "on_all"])

        await router.handle(event)

        #expect(state.repeatMode == nil)
    }

    // MARK: - Group Volume

    @Test @MainActor func groupVolumeChangedUpdatesGroupLevel() async {
        let (router, state) = makeRouter()
        let event = makeEvent("group_volume_changed", message: ["gid": "100", "level": "70"])

        await router.handle(event)

        #expect(state.groupVolumes[100] == 70)
    }

    @Test @MainActor func groupVolumeChangedUpdatesGroupMute() async {
        let (router, state) = makeRouter()
        let event = makeEvent("group_volume_changed", message: ["gid": "100", "level": "70", "mute": "on"])

        await router.handle(event)

        #expect(state.groupVolumes[100] == 70)
        #expect(state.groupMuted[100] == true)
    }

    // MARK: - User Changed

    @Test @MainActor func userChangedSignsIn() async {
        let (router, state) = makeRouter()
        let event = makeEvent("user_changed", message: ["un": "test@email.com"])

        await router.handle(event)

        #expect(state.signedInUser == "test@email.com")
    }

    @Test @MainActor func userChangedSignsOut() async {
        let (router, state) = makeRouter()
        state.signedInUser = "old@email.com"
        let event = makeEvent("user_changed", message: ["signed_out": ""])

        await router.handle(event)

        #expect(state.signedInUser == nil)
    }

    // MARK: - Playback Error

    @Test @MainActor func playbackErrorSetsErrorMessage() async {
        let (router, state) = makeRouter()
        let event = makeEvent("player_playback_error", message: ["pid": "42", "error": "Could not decode stream"])

        await router.handle(event)

        #expect(state.errorMessage == .playbackFailed("Could not decode stream"))
    }

    @Test @MainActor func playbackErrorIgnoresOtherPlayer() async {
        let (router, state) = makeRouter(selectedPID: 42)
        let event = makeEvent("player_playback_error", message: ["pid": "99", "error": "fail"])

        await router.handle(event)

        #expect(state.errorMessage == nil)
    }

    // MARK: - System Error

    @Test @MainActor func systemErrorSetsError() async {
        let (router, state) = makeRouter()
        let event = makeEvent("system_error", message: ["command": "browse/browse", "error": "Service unavailable"])

        await router.handle(event)

        #expect(state.errorMessage == .deviceError("Service unavailable"))
        #expect(state.nonFatalReports.count == 1)
        #expect(state.nonFatalReports[0].source == "event.system_error")
    }

    // MARK: - Timeout Retry

    @Test @MainActor func nowPlayingChangedRetriesAfterTimeout() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connection.connect(host: "test", port: 1255)
        let playerService = PlayerService(connection: connection)
        let state = MockStateUpdater()
        state.selectedPlayerID = 42
        let router = EventRouter(
            stateUpdater: state,
            playerService: playerService,
            groupService: nil,
            browseService: nil,
            fetchTimeout: .milliseconds(300)
        )
        // Responses yielded before the receive stream is live would be dropped.
        await waitUntil { await transport.isReceiving }
        let mediaJSON = """
        {"heos":{"command":"player/get_now_playing_media","result":"success","message":"pid=42"},\
        "payload":{"type":"song","song":"Recovered Song","album":"Test Album","artist":"Test Artist",\
        "image_url":"","mid":"m1","qid":"1","sid":"5","album_id":""}}
        """
        let errorJSON = """
        {"heos":{"command":"player/get_now_playing_media","result":"fail","message":"eid=2&text=timeout"}}
        """
        let event = makeEvent("player_now_playing_changed", message: ["pid": "42"])

        // The handler now runs off the event loop, so poll for its effect instead of awaiting it.
        await router.handle(event)

        // First fetch: held past the router timeout, then failed so the abandoned command frees its slot.
        await waitUntil { await transport.sentData.count == 1 }
        try? await Task.sleep(for: .milliseconds(500))
        await transport.enqueueResponse(errorJSON)
        await transport.deliverNextResponse()

        // Retry fetch: answered the moment it is sent, leaving no window to time out again.
        await transport.enqueueResponse(mediaJSON)
        await transport.setAutoRespond(true)

        await waitUntil { await MainActor.run { state.nowPlaying?.song == "Recovered Song" } }

        #expect(await transport.sentData.count == 2)
        #expect(state.nowPlaying?.song == "Recovered Song")
        await connection.disconnect()
    }

    // MARK: - Slow Fetches Do Not Block Cheap Events

    @Test @MainActor func slowNowPlayingFetchDoesNotDelayPlayState() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connection.connect(host: "test", port: 1255)
        let playerService = PlayerService(connection: connection)
        let state = MockStateUpdater()
        state.selectedPlayerID = 42
        let router = EventRouter(
            stateUpdater: state,
            playerService: playerService,
            groupService: nil,
            browseService: nil
        )
        await waitUntil { await transport.isReceiving }

        // Mirrors the listener loop: a fetch left outstanding must not hold up the play-state event.
        let started = ContinuousClock.now
        await router.handle(makeEvent("player_now_playing_changed", message: ["pid": "42"]))
        await router.handle(makeEvent("player_state_changed", message: ["pid": "42", "state": "play"]))
        let elapsed = ContinuousClock.now - started

        #expect(state.playState == .play)
        #expect(elapsed < .seconds(2))
        // The fetch runs on its own task, so let it reach the transport before asserting.
        await waitUntil { await transport.sentData.count == 1 }
        #expect(await transport.sentData.count == 1)
        await connection.disconnect()
    }

    @Test @MainActor func replacedFetchDoesNotReportAFailure() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connection.connect(host: "test", port: 1255)
        let playerService = PlayerService(connection: connection)
        let state = MockStateUpdater()
        state.selectedPlayerID = 42
        let router = EventRouter(
            stateUpdater: state,
            playerService: playerService,
            groupService: nil,
            browseService: nil
        )
        await waitUntil { await transport.isReceiving }

        // Each event replaces the previous fetch, and a replaced fetch is not a failure.
        for _ in 0..<4 {
            await router.handle(makeEvent("player_now_playing_changed", message: ["pid": "42"]))
        }
        try? await Task.sleep(for: .milliseconds(300))

        #expect(state.nonFatalReports.filter { $0.source == "event.now_playing_changed" }.isEmpty)
        await connection.disconnect()
    }

    // MARK: - Unknown Event

    @Test @MainActor func unknownEventDoesNothing() async {
        let (router, state) = makeRouter()
        let event = makeEvent("something_new", message: ["data": "value"])

        await router.handle(event)

        #expect(state.calls.isEmpty)
    }

    // MARK: - No PID in Message

    @Test @MainActor func playerStateChangedWithNoPIDIgnored() async {
        let (router, state) = makeRouter()
        let event = makeEvent("player_state_changed", message: ["state": "play"])

        await router.handle(event)

        #expect(state.playState == nil)
    }

    // MARK: - Invalid State Values

    @Test @MainActor func playerStateChangedWithInvalidStateIgnored() async {
        let (router, state) = makeRouter()
        let event = makeEvent("player_state_changed", message: ["pid": "42", "state": "exploding"])

        await router.handle(event)

        #expect(state.playState == nil)
    }

    // MARK: - Groups Changed

    @MainActor
    private func makeRouterWithGroups() async throws -> (EventRouter, MockStateUpdater, MockTCPTransport) {
        let transport = MockTCPTransport(autoRespond: true)
        let connection = HEOSConnection(transport: transport)
        try await connection.connect(host: "test", port: 1255)
        try await Task.sleep(for: .milliseconds(50))
        let state = MockStateUpdater()
        state.selectedPlayerID = 42
        let router = EventRouter(
            stateUpdater: state,
            playerService: nil,
            groupService: GroupService(connection: connection),
            browseService: nil
        )
        return (router, state, transport)
    }

    /// Breaking up a pair is the moment the follower must become selectable again.
    @Test @MainActor func groupsChangedWithNoGroupsPublishesAnEmptyTopology() async throws {
        let (router, state, transport) = try await makeRouterWithGroups()
        await transport.enqueueResponse(
            """
            {"heos":{"command":"group/get_groups","result":"success","message":""},"payload":[]}
            """
        )

        await router.handle(makeEvent("groups_changed"))

        #expect(state.groups.isEmpty)
        #expect(state.multiRoomGroupIDs == [])
    }

    /// A pair still exists, so the caches must be left alone until the topology probe runs.
    @Test @MainActor func groupsChangedWithGroupsLeavesTheTopologyAlone() async throws {
        let (router, state, transport) = try await makeRouterWithGroups()
        await transport.enqueueResponse(
            """
            {"heos":{"command":"group/get_groups","result":"success","message":""},"payload":[{"name":"Kitchen Left","gid":1,"players":[{"name":"Kitchen Left","pid":1,"role":"leader"},{"name":"Kitchen Right","pid":2,"role":"member"}]}]}
            """
        )

        await router.handle(makeEvent("groups_changed"))

        #expect(state.groups.count == 1)
        #expect(state.multiRoomGroupIDs == nil)
    }
}

/// Polls until `condition` holds or the timeout elapses, keeping timing-sensitive tests CI-safe.
private func waitUntil(
    timeout: Duration = .seconds(10),
    _ condition: @Sendable () async -> Bool
) async {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
}
