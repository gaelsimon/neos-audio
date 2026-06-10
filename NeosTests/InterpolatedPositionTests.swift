import XCTest
@testable import Neos

final class InterpolatedPositionTests: XCTestCase {

    @MainActor
    func testReturnsBarePositionWhenNotPlaying() {
        let state = AppState()
        state.playback.playState = .pause
        state.playback.playbackPosition = 5000
        state.playback.playbackDuration = 200_000
        state.playback.lastProgressUpdate = Date().addingTimeInterval(-3)

        let now = Date()
        XCTAssertEqual(state.interpolatedPosition(at: now), 5000)
    }

    @MainActor
    func testReturnsBarePositionWhenStopped() {
        let state = AppState()
        state.playback.playState = .stop
        state.playback.playbackPosition = 5000
        state.playback.playbackDuration = 200_000
        state.playback.lastProgressUpdate = Date().addingTimeInterval(-3)

        XCTAssertEqual(state.interpolatedPosition(at: Date()), 5000)
    }

    @MainActor
    func testInterpolatesForwardWhilePlaying() {
        let state = AppState()
        state.playback.playState = .play
        state.playback.playbackPosition = 10_000  // 10s
        state.playback.playbackDuration = 300_000 // 5min
        let baseTime = Date()
        state.playback.lastProgressUpdate = baseTime

        // 2 seconds later
        let later = baseTime.addingTimeInterval(2.0)
        XCTAssertEqual(state.interpolatedPosition(at: later), 12_000)
    }

    @MainActor
    func testClampsToDuration() {
        let state = AppState()
        state.playback.playState = .play
        state.playback.playbackPosition = 299_000  // 1s before end
        state.playback.playbackDuration = 300_000
        let baseTime = Date()
        state.playback.lastProgressUpdate = baseTime

        // 5 seconds later; would be 304s, clamp to 300s
        let later = baseTime.addingTimeInterval(5.0)
        XCTAssertEqual(state.interpolatedPosition(at: later), 300_000)
    }

    @MainActor
    func testReturnsPositionWhenElapsedIsZero() {
        let state = AppState()
        state.playback.playState = .play
        state.playback.playbackPosition = 50_000
        state.playback.playbackDuration = 200_000
        let now = Date()
        state.playback.lastProgressUpdate = now

        XCTAssertEqual(state.interpolatedPosition(at: now), 50_000)
    }

    @MainActor
    func testReturnsPositionWhenNowIsBeforeLastUpdate() {
        let state = AppState()
        state.playback.playState = .play
        state.playback.playbackPosition = 50_000
        state.playback.playbackDuration = 200_000
        let now = Date()
        state.playback.lastProgressUpdate = now

        // 'now' is before lastProgressUpdate; elapsed is negative
        let before = now.addingTimeInterval(-1.0)
        XCTAssertEqual(state.interpolatedPosition(at: before), 50_000)
    }

    @MainActor
    func testProgressPercentZeroWhenDurationIsZero() {
        let state = AppState()
        state.playback.playState = .play
        state.playback.playbackPosition = 5000
        state.playback.playbackDuration = 0

        XCTAssertEqual(state.interpolatedProgressPercent(at: Date()), 0)
    }

    @MainActor
    func testProgressPercentInterpolates() {
        let state = AppState()
        state.playback.playState = .play
        state.playback.playbackPosition = 100_000
        state.playback.playbackDuration = 200_000
        let baseTime = Date()
        state.playback.lastProgressUpdate = baseTime

        // 10 seconds later: 100_000 + 10_000 = 110_000 / 200_000 = 0.55
        let later = baseTime.addingTimeInterval(10.0)
        XCTAssertEqual(state.interpolatedProgressPercent(at: later), 0.55, accuracy: 0.001)
    }
}
