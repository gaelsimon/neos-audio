import Testing
import NeosDomain
@testable import HEOSKit

@Suite("Resync Playback Apply")
@MainActor
struct ResyncPlaybackApplyTests {

    @Test func appliesBothWhenPresent() async {
        let updater = MockStateUpdater()
        await applyResyncedPlayback(playState: .play, nowPlaying: (NowPlayingMedia(), []), to: updater)
        #expect(updater.playState == .play)
        #expect(updater.calls.contains { $0.hasPrefix("setNowPlaying") })
    }

    // The clobber guard: a failed fetch (nil) must leave existing state untouched.
    @Test func skipsEverythingWhenAllNil() async {
        let updater = MockStateUpdater()
        await applyResyncedPlayback(playState: nil, nowPlaying: nil, to: updater)
        #expect(updater.playState == nil)
        #expect(!updater.calls.contains { $0.hasPrefix("setPlayState") })
        #expect(!updater.calls.contains { $0.hasPrefix("setNowPlaying") })
    }

    @Test func appliesPlayStateButSkipsNowPlayingWhenNil() async {
        let updater = MockStateUpdater()
        await applyResyncedPlayback(playState: .pause, nowPlaying: nil, to: updater)
        #expect(updater.playState == .pause)
        #expect(!updater.calls.contains { $0.hasPrefix("setNowPlaying") })
    }
}
