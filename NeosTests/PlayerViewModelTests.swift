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
    func testToggleMuteCallsServiceAndKeepsVolume() async {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setVolume(40)
        state.setMaxVolume(100)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.toggleMute()

        await yieldForTask()
        XCTAssertTrue(mock.calls.contains("toggleMute:1"))
        XCTAssertTrue(state.isMuted)
        XCTAssertEqual(state.volume, 40)
    }

    @MainActor
    func testToggleMuteUnmutesWhenMuted() async {
        let state = AppState()
        state.selectedPlayerID = 1
        state.setMuted(true)
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.toggleMute()

        await yieldForTask()
        XCTAssertTrue(mock.calls.contains("toggleMute:1"))
        XCTAssertFalse(state.isMuted)
    }

    @MainActor
    func testToggleMuteRevertsOnFailure() async {
        let state = AppState()
        state.selectedPlayerID = 1
        let mock = MockAudioService()
        mock.toggleMuteError = NSError(domain: "test", code: 1)
        let vm = PlayerViewModel(service: mock, state: state)

        vm.toggleMute()

        await yieldForTask()
        XCTAssertFalse(state.isMuted)
        XCTAssertNotNil(state.error)
    }

    @MainActor
    func testToggleMuteWithoutSelectedPlayerDoesNothing() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state)

        vm.toggleMute()

        await yieldForTask()
        XCTAssertFalse(mock.calls.contains(where: { $0.hasPrefix("toggleMute") }))
        XCTAssertFalse(state.isMuted)
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

    // MARK: - Track Metadata Retry

    /// Tiny gaps so the schedule runs in milliseconds instead of seconds.
    private static let fastGaps: [Double] = [0.01, 0.01, 0.01, 0.01]

    @MainActor
    private func metadataFetchCount(_ mock: MockAudioService) -> Int {
        mock.calls.filter { $0 == "fetchTrackMetadata" }.count
    }

    /// Waits for a condition instead of a fixed delay, so a loaded machine does not decide the
    /// outcome. Returns whether it held before giving up.
    @MainActor
    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<200 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @MainActor
    func testATrackChangeDuringTheAttemptsIsPickedUpImmediately() async {
        let state = AppState()
        state.selectedPlayerID = 1
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state, metadataAttemptGaps: Self.fastGaps)

        state.setNowPlaying(NowPlayingMedia(song: "A", mid: "A"))
        vm.startTrackMetadataObserver()
        // Let the first attempt land, then move the track under the running loop.
        _ = await eventually { metadataFetchCount(mock) >= 1 }
        state.setNowPlaying(NowPlayingMedia(song: "B", mid: "B"))

        // Track B gets its own attempts. Waiting for the next mid would have stopped at A's.
        let reachedB = await eventually { metadataFetchCount(mock) > 2 }
        XCTAssertTrue(reachedB, "only \(metadataFetchCount(mock)) fetches; B never got its own")
    }

    @MainActor
    func testMetadataArrivingLateIsStillApplied() async {
        let state = AppState()
        state.selectedPlayerID = 1
        let mock = MockAudioService()
        let vm = PlayerViewModel(service: mock, state: state, metadataAttemptGaps: Self.fastGaps)

        state.setNowPlaying(NowPlayingMedia(song: "A", mid: "A"))
        vm.startTrackMetadataObserver()
        // Nothing to report yet, as the amp does for the first seconds of a track.
        _ = await eventually { metadataFetchCount(mock) >= 1 }
        mock.trackMetadata = TrackMetadata(sampleRate: 48_000, bitDepth: 24, codec: "FLAC")

        _ = await eventually { state.trackMetadata?.qualityDescription != nil }
        XCTAssertEqual(state.trackMetadata?.qualityDescription, "24-bit / 48 kHz FLAC")
    }

    @MainActor
    func testTheAttemptsStopOnceTheQualityIsKnown() async {
        let state = AppState()
        state.selectedPlayerID = 1
        let mock = MockAudioService()
        mock.trackMetadata = TrackMetadata(sampleRate: 44_100, bitDepth: 16, codec: "FLAC")
        let vm = PlayerViewModel(service: mock, state: state, metadataAttemptGaps: Self.fastGaps)

        state.setNowPlaying(NowPlayingMedia(song: "A", mid: "A"))
        vm.startTrackMetadataObserver()
        _ = await eventually { state.trackMetadata?.qualityDescription != nil }
        // Long enough that further attempts would have landed had the loop kept going.
        try? await Task.sleep(for: .milliseconds(150))

        // One answer is enough; the remaining gaps are not spent.
        XCTAssertEqual(metadataFetchCount(mock), 1)
    }
}
