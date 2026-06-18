import XCTest
@testable import Neos
import NeosDomain

final class PlayerViewModelTests: XCTestCase {

    // MARK: - togglePlayPause

    @MainActor
    func testTogglePlayPauseWhenPlayingOptimisticallyPauses() async {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setPlayState(.play)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.togglePlayPause()

        XCTAssertEqual(state.playState, .pause)
        await Task.yield()
        await Task.yield()
        let calls = mock.calls
        XCTAssertTrue(calls.contains("pause:1"))
    }

    @MainActor
    func testTogglePlayPauseWhenPausedOptimisticallyPlays() async {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setPlayState(.pause)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.togglePlayPause()

        XCTAssertEqual(state.playState, .play)
        await Task.yield()
        await Task.yield()
        let calls = mock.calls
        XCTAssertTrue(calls.contains("play:1"))
    }

    @MainActor
    func testTogglePlayPauseNoOpWithoutSelectedPlayer() {
        let state = AppState()
        state.setPlayState(.pause)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.togglePlayPause()

        XCTAssertEqual(state.playState, .pause)
    }

    @MainActor
    func testTogglePlayPauseRevertsOnError() async {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setPlayState(.play)
        let mock = MockAudioService()
        mock.pauseError = NSError(domain: "test", code: 1)
        let vm = PlayerViewModel(service: mock, state: state)

        vm.togglePlayPause()

        // Optimistic: immediately pauses
        XCTAssertEqual(state.playState, .pause)

        // Wait for async revert
        await yieldForTask()

        XCTAssertEqual(state.playState, .play)
        XCTAssertNotNil(state.error)
    }

    // MARK: - next / previous

    @MainActor
    func testNextCallsService() async {
        let state = AppState()
        state.selectedPlayerID = 1
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.next()

        XCTAssertTrue(vm.isSkipping)
        await yieldForTask()
        let calls = mock.calls
        XCTAssertTrue(calls.contains("next:1"))
        XCTAssertFalse(vm.isSkipping)
    }

    @MainActor
    func testNextBlocksWhileSkipping() {
        let state = AppState()
        state.selectedPlayerID = 1
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.next()
        XCTAssertTrue(vm.isSkipping)

        // Second call should be ignored
        vm.next()
        // Still only one skip in progress
        XCTAssertTrue(vm.isSkipping)
    }

    @MainActor
    func testNextNoOpWithoutPlayer() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.next()

        XCTAssertFalse(vm.isSkipping)
        let calls = mock.calls
        XCTAssertTrue(calls.isEmpty)
    }

    @MainActor
    func testPreviousCallsService() async {
        let state = AppState()
        state.selectedPlayerID = 1
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.previous()

        await yieldForTask()
        let calls = mock.calls
        XCTAssertTrue(calls.contains("previous:1"))
    }

    // MARK: - setVolume

    @MainActor
    func testSetVolumeUpdatesStateAndCapsToMax() async {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setMaxVolume(50)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.setVolume(80)

        XCTAssertEqual(state.volume, 50)
        await yieldForTask()
        let calls = mock.calls
        XCTAssertTrue(calls.contains("setVolume:1:50"))
    }

    @MainActor
    func testSetVolumeWithinRange() async {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setMaxVolume(100)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.setVolume(30)

        XCTAssertEqual(state.volume, 30)
    }

    @MainActor
    func testSetVolumeNoOpWithoutPlayer() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.setVolume(50)

        XCTAssertEqual(state.volume, 0)
    }

    // MARK: - toggleMute

    @MainActor
    func testToggleMuteSavesAndRestoresVolume() {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setVolume(40)
        state.setMaxVolume(100)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        // Mute
        vm.toggleMute()
        XCTAssertEqual(state.volume, 0)

        // Unmute - restores to 40
        vm.toggleMute()
        XCTAssertEqual(state.volume, 40)
    }

    @MainActor
    func testToggleMuteDefaultsTo20WhenNoSavedVolume() {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setVolume(0)
        state.setMaxVolume(100)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        // Unmute with no saved volume
        vm.toggleMute()
        XCTAssertEqual(state.volume, 20)
    }

    // MARK: - cycleRepeatMode

    @MainActor
    func testCycleRepeatModeOffToOnAll() {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setRepeatMode(.off)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.cycleRepeatMode()
        XCTAssertEqual(state.repeatMode, .onAll)
    }

    @MainActor
    func testCycleRepeatModeOnAllToOnOne() {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setRepeatMode(.onAll)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.cycleRepeatMode()
        XCTAssertEqual(state.repeatMode, .onOne)
    }

    @MainActor
    func testCycleRepeatModeOnOneToOff() {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setRepeatMode(.onOne)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.cycleRepeatMode()
        XCTAssertEqual(state.repeatMode, .off)
    }

    @MainActor
    func testCycleRepeatModeRevertsOnError() async {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setRepeatMode(.off)
        let mock = MockAudioService()
        mock.playModeError = NSError(domain: "test", code: 1)
        let vm = PlayerViewModel(service: mock, state: state)

        vm.cycleRepeatMode()
        XCTAssertEqual(state.repeatMode, .onAll)

        await yieldForTask()
        XCTAssertEqual(state.repeatMode, .off)
    }

    // MARK: - toggleShuffle

    @MainActor
    func testToggleShuffleOffToOn() {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setShuffleMode(.off)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.toggleShuffle()
        XCTAssertEqual(state.shuffleMode, .on)
    }

    @MainActor
    func testToggleShuffleOnToOff() {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setShuffleMode(.on)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.toggleShuffle()
        XCTAssertEqual(state.shuffleMode, .off)
    }

    @MainActor
    func testToggleShuffleRevertsOnError() async {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setShuffleMode(.off)
        let mock = MockAudioService()
        mock.playModeError = NSError(domain: "test", code: 1)
        let vm = PlayerViewModel(service: mock, state: state)

        vm.toggleShuffle()
        XCTAssertEqual(state.shuffleMode, .on)

        await yieldForTask()
        XCTAssertEqual(state.shuffleMode, .off)
    }

    // MARK: - seek

    @MainActor
    func testSeekUpdatesProgress() {
        let state = AppState()
        state.selectedPlayerID = 1
        state.playback.playbackDuration = 300_000
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.seek(to: 60.0)

        XCTAssertEqual(state.playbackPosition, 60_000)
    }

    // MARK: - resyncPlaybackState

    @MainActor
    func testResyncPlaybackStateResyncsSelectedPlayerWhenConnected() async {
        let state = AppState()
        state.connectionState = .connected
        state.selectedPlayerID = 7
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.resyncPlaybackState()
        await Task.yield()
        await Task.yield()

        XCTAssertTrue(mock.calls.contains("resyncPlaybackState:7"))
    }

    @MainActor
    func testResyncPlaybackStateNoOpWhenDisconnected() async {
        let state = AppState()
        state.connectionState = .disconnected
        state.selectedPlayerID = 7
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.resyncPlaybackState()
        await Task.yield()
        await Task.yield()

        XCTAssertFalse(mock.calls.contains { $0.hasPrefix("resyncPlaybackState") })
    }

    @MainActor
    func testResyncPlaybackStateNoOpWithoutSelectedPlayer() async {
        let state = AppState()
        state.connectionState = .connected
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.resyncPlaybackState()
        await Task.yield()
        await Task.yield()

        XCTAssertFalse(mock.calls.contains { $0.hasPrefix("resyncPlaybackState") })
    }
}
