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
}
