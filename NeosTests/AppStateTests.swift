import XCTest
@testable import Neos
import NeosDomain

final class AppStateTests: XCTestCase {

    // MARK: - setConnectionState

    @MainActor
    func testDisconnectResetsPlaybackState() {
        let state = AppState()
        state.playback.playState = .play
        state.playback.nowPlaying = NowPlayingMedia(song: "Test", mid: "m1")
        state.playback.playbackPosition = 5000
        state.playback.playbackDuration = 200_000
        state.playback.queue = [QueueItem(qid: 1, song: "Q1")]
        state.serviceCapabilities = [1: ServiceCapabilities()]
        state.searchCriteria = [1: [SearchCriteria(scid: 1, name: "Track")]]

        state.setConnectionState(.disconnected)

        XCTAssertEqual(state.connectionState, .disconnected)
        XCTAssertEqual(state.playState, .stop)
        XCTAssertEqual(state.nowPlaying, NowPlayingMedia())
        XCTAssertNil(state.trackMetadata)
        XCTAssertEqual(state.playbackPosition, 0)
        XCTAssertEqual(state.playbackDuration, 0)
        XCTAssertTrue(state.queue.isEmpty)
        XCTAssertTrue(state.serviceCapabilities.isEmpty)
        XCTAssertTrue(state.searchCriteria.isEmpty)
    }

    @MainActor
    func testConnectDoesNotResetState() {
        let state = AppState()
        state.playback.playState = .play

        state.setConnectionState(.connected)

        XCTAssertEqual(state.playState, .play)
        XCTAssertEqual(state.connectionState, .connected)
    }

    // MARK: - setPlayState

    @MainActor
    func testSetPlayStateResetsInterpolationAnchorOnResume() {
        let state = AppState()
        state.playback.playState = .pause
        state.playback.lastProgressUpdate = .distantPast

        let before = Date()
        state.setPlayState(.play)
        let after = Date()

        XCTAssertEqual(state.playState, .play)
        XCTAssertGreaterThanOrEqual(state.lastProgressUpdate, before)
        XCTAssertLessThanOrEqual(state.lastProgressUpdate, after)
    }

    @MainActor
    func testSetPlayStateDoesNotResetAnchorWhenAlreadyPlaying() {
        let state = AppState()
        state.playback.playState = .play
        let anchor = Date.distantPast
        state.playback.lastProgressUpdate = anchor

        state.setPlayState(.play)

        XCTAssertEqual(state.lastProgressUpdate, anchor)
    }

    @MainActor
    func testSetPlayStateClearsLoadingFlag() {
        let state = AppState()
        state.beginTrackLoad()

        state.setPlayState(.pause)

        XCTAssertFalse(state.isLoadingTrack)
    }

    @MainActor
    func testPlaybackStartingKeepsLoadingUntilTrackArrives() {
        let state = AppState()
        state.beginTrackLoad()

        // A waking amp reports play long before it can describe the track.
        state.setPlayState(.play)

        XCTAssertTrue(state.isLoadingTrack)
    }

    @MainActor
    func testTrackArrivingClearsLoadingFlag() {
        let state = AppState()
        state.beginTrackLoad()

        state.setNowPlaying(NowPlayingMedia(song: "Song", mid: "m1"))

        XCTAssertFalse(state.isLoadingTrack)
    }

    @MainActor
    func testWatchdogClearsLoadingWhenTheDeviceStaysSilent() async throws {
        let state = AppState()
        state.beginTrackLoad(timeout: .milliseconds(50))

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(state.isLoadingTrack)
    }

    @MainActor
    func testANewLoadDisarmsTheOlderWatchdog() async throws {
        let state = AppState()
        // The first load's watchdog must not clear the spinner of the load that replaced it.
        state.beginTrackLoad(timeout: .milliseconds(50))
        state.beginTrackLoad(timeout: .seconds(30))

        try await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(state.isLoadingTrack)
    }

    @MainActor
    func testASupersededPlayCannotRollBackTheLoadThatReplacedIt() {
        let state = AppState()
        let first = state.beginTrackLoad()
        // The user clicked another track before the first one answered.
        let second = state.beginTrackLoad()
        state.pendingStreamContext = .init(
            pid: 1, stationName: "Second", browseMID: "mid-2", imageURL: "", streamURL: "http://s/2",
            previousMID: ""
        )

        // The first play now reports its failure; it owns neither the spinner nor the context.
        state.failTrackLoad(generation: first)

        XCTAssertTrue(state.isLoadingTrack)
        XCTAssertNotNil(state.pendingStreamContext)

        state.failTrackLoad(generation: second)

        XCTAssertFalse(state.isLoadingTrack)
        XCTAssertNil(state.pendingStreamContext)
    }

    // MARK: - setNowPlaying

    @MainActor
    func testSetNowPlayingClearsMetadataOnNewTrack() {
        let state = AppState()
        state.playback.nowPlaying = NowPlayingMedia(mid: "old")
        state.playback.trackMetadata = TrackMetadata()
        state.playback.playbackPosition = 5000

        state.setNowPlaying(NowPlayingMedia(mid: "new"))

        XCTAssertNil(state.trackMetadata)
        XCTAssertEqual(state.playbackPosition, 0)
        XCTAssertEqual(state.nowPlaying.mid, "new")
    }

    @MainActor
    func testSetNowPlayingKeepsMetadataOnSameTrack() {
        let state = AppState()
        state.playback.nowPlaying = NowPlayingMedia(mid: "same")
        let metadata = TrackMetadata()
        state.playback.trackMetadata = metadata
        state.playback.playbackPosition = 5000

        state.setNowPlaying(NowPlayingMedia(song: "Updated Title", mid: "same"))

        XCTAssertNotNil(state.trackMetadata)
        XCTAssertEqual(state.playbackPosition, 5000)
        XCTAssertEqual(state.nowPlaying.song, "Updated Title")
    }

    // MARK: - setVolume

    @MainActor
    func testSetVolumeIgnoredDuringAdjusting() {
        let state = AppState()
        state.playback.volume = 30
        state.isAdjustingVolume = true

        state.setVolume(80)

        XCTAssertEqual(state.volume, 30)
    }

    @MainActor
    func testSetVolumeAppliesWhenNotAdjusting() {
        let state = AppState()
        state.playback.volume = 30

        state.setVolume(80)

        XCTAssertEqual(state.volume, 80)
    }

    // MARK: - interpolatedPosition

    @MainActor
    func testInterpolatedPositionReturnsBareWhenPaused() {
        let state = AppState()
        state.playback.playState = .pause
        state.playback.playbackPosition = 5000

        XCTAssertEqual(state.interpolatedPosition(at: Date()), 5000)
    }

    @MainActor
    func testInterpolatedPositionAdvancesWhilePlaying() {
        let state = AppState()
        state.playback.playState = .play
        state.playback.playbackPosition = 5000
        state.playback.playbackDuration = 300_000
        state.playback.lastProgressUpdate = Date().addingTimeInterval(-2.0)

        let pos = state.interpolatedPosition(at: Date())

        // Should be approximately 5000 + 2000 = 7000ms
        XCTAssertGreaterThan(pos, 6500)
        XCTAssertLessThan(pos, 7500)
    }

    @MainActor
    func testInterpolatedPositionClampsToDuration() {
        let state = AppState()
        state.playback.playState = .play
        state.playback.playbackPosition = 299_000
        state.playback.playbackDuration = 300_000
        state.playback.lastProgressUpdate = Date().addingTimeInterval(-10.0)

        let pos = state.interpolatedPosition(at: Date())

        XCTAssertEqual(pos, 300_000)
    }

    // MARK: - addDiscoveredDevice

    @MainActor
    func testAddDiscoveredDeviceAppendsNew() {
        let state = AppState()
        let dev = DiscoveredDevice(host: "192.168.1.10")

        state.addDiscoveredDevice(dev)

        XCTAssertEqual(state.discoveredDevices.count, 1)
        XCTAssertEqual(state.discoveredDevices[0].host, "192.168.1.10")
    }

    @MainActor
    func testAddDiscoveredDeviceSkipsIPv6() {
        let state = AppState()
        let dev = DiscoveredDevice(host: "fe80::1%en0")

        state.addDiscoveredDevice(dev)

        XCTAssertTrue(state.discoveredDevices.isEmpty)
    }

    @MainActor
    func testAddDiscoveredDeviceDeduplicatesByHost() {
        let state = AppState()
        let dev1 = DiscoveredDevice(host: "192.168.1.10", friendlyName: "192.168.1.10")
        let dev2 = DiscoveredDevice(host: "192.168.1.10", friendlyName: "192.168.1.10")

        state.addDiscoveredDevice(dev1)
        state.addDiscoveredDevice(dev2)

        XCTAssertEqual(state.discoveredDevices.count, 1)
    }

    @MainActor
    func testAddDiscoveredDeviceUpgradesFriendlyName() {
        let state = AppState()
        let bare = DiscoveredDevice(host: "192.168.1.10", friendlyName: "192.168.1.10")
        let rich = DiscoveredDevice(host: "192.168.1.10", friendlyName: "Living Room")

        state.addDiscoveredDevice(bare)
        state.addDiscoveredDevice(rich)

        XCTAssertEqual(state.discoveredDevices.count, 1)
        XCTAssertEqual(state.discoveredDevices[0].friendlyName, "Living Room")
    }

    @MainActor
    func testAddDiscoveredDeviceDoesNotDowngradeName() {
        let state = AppState()
        let rich = DiscoveredDevice(host: "192.168.1.10", friendlyName: "Living Room")
        let bare = DiscoveredDevice(host: "192.168.1.10", friendlyName: "192.168.1.10")

        state.addDiscoveredDevice(rich)
        state.addDiscoveredDevice(bare)

        XCTAssertEqual(state.discoveredDevices[0].friendlyName, "Living Room")
    }

    // MARK: - showToast

    @MainActor
    func testShowToastSetsToast() {
        let state = AppState()

        state.showToast("Saved!")

        XCTAssertNotNil(state.toast)
        XCTAssertEqual(state.toast?.text, "Saved!")
    }

    // MARK: - setMaxVolume

    @MainActor
    func testSetMaxVolumeClampsBelowOne() {
        let state = AppState()

        state.setMaxVolume(0)

        XCTAssertEqual(state.maxVolume, 1)
    }

    @MainActor
    func testSetMaxVolumeNilClearsValue() {
        let state = AppState()
        state.playback.maxVolume = 50

        state.setMaxVolume(nil)

        XCTAssertNil(state.maxVolume)
    }

    // MARK: - Computed Properties

    @MainActor
    func testIsPlayingReflectsPlayState() {
        let state = AppState()
        XCTAssertFalse(state.isPlaying)

        state.playback.playState = .play
        XCTAssertTrue(state.isPlaying)
    }

    @MainActor
    func testProgressPercentCalculation() {
        let state = AppState()
        state.playback.playbackPosition = 50_000
        state.playback.playbackDuration = 200_000

        XCTAssertEqual(state.progressPercent, 0.25, accuracy: 0.001)
    }

    @MainActor
    func testProgressPercentZeroWhenNoDuration() {
        let state = AppState()
        state.playback.playbackDuration = 0

        XCTAssertEqual(state.progressPercent, 0)
    }

    // MARK: - reportNonFatal

    @MainActor
    func testReportNonFatalCapsAt100() {
        let state = AppState()
        for i in 0..<110 {
            state.reportNonFatal(source: "test", message: "msg \(i)")
        }

        XCTAssertEqual(state.diagnostics.count, 100)
    }

    @MainActor
    func testSwitchingStationsDoesNotLetTheOldStreamStealTheContext() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.playback.nowPlaying = NowPlayingMedia(song: "Url Stream", mid: "https://old.example.com/live")
        state.pendingStreamContext = .init(
            pid: 42, stationName: "New Station", browseMID: "u33", imageURL: "new.jpg",
            streamURL: "https://new.example.com/live", previousMID: "https://old.example.com/live"
        )

        // The amp replays the outgoing station as a generic Url Stream event.
        state.setNowPlaying(NowPlayingMedia(song: "Url Stream", mid: "https://old.example.com/live"))
        XCTAssertNil(state.nowPlaying.station)
        XCTAssertNotNil(state.pendingStreamContext)

        // The new station then arrives and gets its name.
        state.setNowPlaying(NowPlayingMedia(song: "Url Stream", mid: "https://new.example.com/live"))
        XCTAssertEqual(state.nowPlaying.station, "New Station")
        XCTAssertEqual(state.browseMID(forDeviceMID: "https://new.example.com/live"), "u33")
        XCTAssertNil(state.browseMID(forDeviceMID: "https://old.example.com/live"))
    }

    @MainActor
    func testStartingAPlayLetsTheSameErrorShowAgain() {
        let state = AppState()
        state.setError(.playbackFailed("Unable to stream from TuneIn. Please try again later."))
        state.toast = nil

        // The user retries the same station.
        _ = state.beginTrackLoad()
        state.setError(.playbackFailed("Unable to stream from TuneIn. Please try again later."))

        XCTAssertEqual(state.toast?.text, "Unable to stream from TuneIn. Please try again later.")
    }

    @MainActor
    func testResolvedImageURLUpgradesPlaintextArtwork() {
        let state = AppState()

        XCTAssertEqual(
            state.resolvedImageURL(forMID: "s1", originalURL: "http://art.example.com/a.jpg"),
            "https://art.example.com/a.jpg"
        )
        // Device-hosted artwork stays plaintext; the local network is allowed.
        XCTAssertEqual(
            state.resolvedImageURL(forMID: "s2", originalURL: "http://192.168.8.219:8200/a.jpg"),
            "http://192.168.8.219:8200/a.jpg"
        )
    }

    // MARK: - Artwork Resolution

    @MainActor
    func testCustomArtworkIsNotUpgradedBackToTheOriginal() {
        let state = AppState()
        state.imageCache.customStationImages["s1"] = "https://example.com/my-cover.jpg"

        let artwork = state.artwork(forMID: "s1", originalURL: "https://cdns-images.dzcdn.net/images/x/250x250.jpg")

        XCTAssertEqual(artwork.base?.absoluteString, "https://example.com/my-cover.jpg")
        // The upgrade must never be the artwork the custom image replaced.
        XCTAssertNotEqual(artwork.highRes?.absoluteString.contains("dzcdn.net"), true)
    }

    @MainActor
    func testArtworkUpgradeComesFromTheImageActuallyShown() {
        let state = AppState()

        let artwork = state.artwork(forMID: "s2", originalURL: "https://cdns-images.dzcdn.net/images/x/250x250.jpg")

        XCTAssertEqual(artwork.base?.absoluteString, "https://cdns-images.dzcdn.net/images/x/250x250.jpg")
        XCTAssertEqual(artwork.highRes?.absoluteString, "https://cdns-images.dzcdn.net/images/x/1000x1000.jpg")
    }

    @MainActor
    func testTwoURLStreamsSharingAPlaceholderMidStillEnrich() {
        // Captured from the amp: every raw url stream is reported as mid "1".
        let state = AppState()
        state.selectedPlayerID = 42
        state.playback.nowPlaying = NowPlayingMedia(song: "Url Stream", mid: "1")
        state.pendingStreamContext = .init(
            pid: 42, stationName: "France Musique", browseMID: "u40", imageURL: "",
            streamURL: "https://icecast.radiofrance.fr/francemusique-hifi.aac", previousMID: "1"
        )

        // The outgoing stream is replayed under the same placeholder mid.
        state.setNowPlaying(NowPlayingMedia(song: "Url Stream", mid: "1"))
        XCTAssertNotNil(state.pendingStreamContext)

        // The station we asked for arrives, indistinguishable except for its turn.
        state.setNowPlaying(NowPlayingMedia(song: "Url Stream", mid: "1"))
        XCTAssertEqual(state.nowPlaying.station, "France Musique")
        XCTAssertEqual(state.browseMID(forDeviceMID: "1"), "u40")
    }

    @MainActor
    func testFavoriteMatchesWhenTheDeviceSwitchesScheme() {
        // Captured: the same station reported over http on one play and https on the next.
        let state = AppState()
        state.playback.nowPlaying = NowPlayingMedia(mid: "https://provisioning.streamtheworld.com/pls/KLINAMAAC")
        let favorite = BrowseItem(
            name: "KLIN", type: .station,
            mid: "http://provisioning.streamtheworld.com/pls/KLINAMAAC"
        )

        XCTAssertTrue(state.isNowPlaying(favorite))
    }

    @MainActor
    func testTuneInFavoriteMatchesWithAnEmptyStationName() {
        // Captured: album_id carries the station id while station comes back empty.
        let state = AppState()
        state.playback.nowPlaying = NowPlayingMedia(
            albumID: "s44491", mid: "https://open.live.bbc.co.uk/mediaselector/6/redir", station: ""
        )
        let favorite = BrowseItem(name: "BBC Radio 6 Music", type: .station, mid: "s44491")

        XCTAssertTrue(state.isNowPlaying(favorite))
    }

    @MainActor
    func testATrackIsNotMatchedByItsAlbumID() {
        let state = AppState()
        state.playback.nowPlaying = NowPlayingMedia(albumID: "82425106", mid: "82425107")
        let track = BrowseItem(name: "Some Song", type: .song, mid: "82425106")

        XCTAssertFalse(state.isNowPlaying(track))
    }

    // MARK: - Station Row Matching

    @MainActor
    func testStationNamedAfterItsStreamIsHighlighted() {
        let state = AppState()
        state.playback.nowPlaying = NowPlayingMedia(mid: "https://icecast.radiofrance.fr/fip-hifi.aac")
        let row = BrowseItem(name: "https://icecast.radiofrance.fr/fip-hifi.aac", type: .station, mid: "u32")

        XCTAssertTrue(state.isNowPlaying(row))
    }

    @MainActor
    func testTwoStationsSharingAFileNameAreToldApart() {
        let state = AppState()
        state.playback.nowPlaying = NowPlayingMedia(mid: "https://a.example.com/classic.aac")
        let playing = BrowseItem(name: "https://a.example.com/classic.aac", type: .station, mid: "u1")
        let other = BrowseItem(name: "https://b.example.com/classic.aac", type: .station, mid: "u2")

        XCTAssertTrue(state.isNowPlaying(playing))
        XCTAssertFalse(state.isNowPlaying(other))
        // And they no longer read the same in the list.
        XCTAssertNotEqual(playing.displayTitle, other.displayTitle)
    }

    // MARK: - Timeline Hold On Resume

    @MainActor
    func testTimelineHoldsUntilTheAmpConfirmsTheResume() async throws {
        let state = AppState()
        state.setPlayState(.play)
        state.setProgress(position: 16_000, duration: 188_000)
        state.setPlayStateOptimistically(.pause)

        state.setPlayStateOptimistically(.play)
        try await Task.sleep(for: .milliseconds(120))

        // The amp has not answered, so the position must not have moved.
        XCTAssertFalse(state.isTimelineRunning)
        XCTAssertEqual(state.playback.interpolatedPosition(at: Date()), state.playbackPosition)
    }

    @MainActor
    func testTimelineRunsOnceTheAmpConfirms() async throws {
        let state = AppState()
        state.setPlayState(.play)
        state.setProgress(position: 16_000, duration: 188_000)
        state.setPlayStateOptimistically(.pause)
        state.setPlayStateOptimistically(.play)

        // The amp reports that it resumed.
        state.setPlayState(.play)
        XCTAssertTrue(state.isTimelineRunning)

        try await Task.sleep(for: .milliseconds(120))
        XCTAssertGreaterThan(state.playback.interpolatedPosition(at: Date()), state.playbackPosition)
    }

    @MainActor
    func testAProgressReportAlsoReleasesTheHold() {
        let state = AppState()
        state.setPlayState(.play)
        state.setProgress(position: 16_000, duration: 188_000)
        state.setPlayStateOptimistically(.pause)
        state.setPlayStateOptimistically(.play)

        state.setProgress(position: 16_500, duration: 188_000)

        XCTAssertTrue(state.isTimelineRunning)
    }

    // MARK: - Progress On Pause

    @MainActor
    func testPausingFreezesWherePlaybackActuallyGot() async throws {
        let state = AppState()
        state.setPlayState(.play)
        state.setProgress(position: 16_000, duration: 188_000)

        // Playback runs on past the last position the amp sent.
        try await Task.sleep(for: .milliseconds(150))
        state.setPlayState(.pause)

        // Pausing must not rewind to the amp's last report.
        XCTAssertGreaterThan(state.playbackPosition, 16_000)
        XCTAssertLessThan(state.playbackPosition, 17_000)
    }

    // MARK: - Progress On Resume

    @MainActor
    func testANewTrackIgnoresTheZeroTheAmpReportsFirst() {
        let state = AppState()
        state.setNowPlaying(NowPlayingMedia(song: "A", mid: "A"))
        let baseline = state.playback.lastProgressUpdate

        // Arrives a couple of seconds in, reporting a position playback has already passed.
        state.setProgress(position: 0, duration: 519_000)

        // The interpolation baseline must not move, or the bar jumps back to the start.
        XCTAssertEqual(state.playback.lastProgressUpdate, baseline)
        XCTAssertEqual(state.playbackPosition, 0)
    }

    @MainActor
    func testTheDurationIsTakenFromTheZeroTheAmpReportsFirst() {
        let state = AppState()
        state.setNowPlaying(NowPlayingMedia(song: "A", mid: "A"))

        state.setProgress(position: 0, duration: 519_000)

        // The amp sends the duration with that first event; dropping it leaves no bar.
        XCTAssertEqual(state.playbackDuration, 519_000)
    }

    @MainActor
    func testTheRealPositionAfterANewTrackIsTaken() {
        let state = AppState()
        state.setNowPlaying(NowPlayingMedia(song: "A", mid: "A"))
        state.setProgress(position: 0, duration: 519_000)

        state.setProgress(position: 1_000, duration: 519_000)

        XCTAssertEqual(state.playbackPosition, 1_000)
    }

    @MainActor
    func testAZeroLongAfterTheTrackStartedIsTaken() {
        let state = AppState()
        state.setNowPlaying(NowPlayingMedia(song: "A", mid: "A"))
        state.setProgress(position: 30_000, duration: 519_000)
        // Past the window, so a zero is the track really being back at the start.
        state.playback.positionBaselineAt = Date().addingTimeInterval(-30)

        state.setProgress(position: 0, duration: 519_000)

        XCTAssertEqual(state.playbackPosition, 0)
    }

    @MainActor
    func testResumeIgnoresTheZeroTheAmpReportsFirst() {
        let state = AppState()
        state.setProgress(position: 16_000, duration: 188_000)
        state.setPlayState(.pause)
        state.setPlayState(.play)

        state.setProgress(position: 0, duration: 188_000)

        XCTAssertEqual(state.playbackPosition, 16_000)
    }

    @MainActor
    func testTheRealPositionAfterAResumeIsTaken() {
        let state = AppState()
        state.setProgress(position: 16_000, duration: 188_000)
        state.setPlayState(.pause)
        state.setPlayState(.play)
        state.setProgress(position: 0, duration: 188_000)

        state.setProgress(position: 17_000, duration: 188_000)

        XCTAssertEqual(state.playbackPosition, 17_000)
    }

    @MainActor
    func testZeroIsTakenWhenPlaybackDidNotJustResume() {
        let state = AppState()
        state.setPlayState(.play)
        state.setProgress(position: 16_000, duration: 188_000)

        // A second zero, with no resume in between, is a real one.
        state.setProgress(position: 0, duration: 188_000)

        XCTAssertEqual(state.playbackPosition, 0)
    }

    // MARK: - Now Playing Display

    @MainActor
    func testPlayingStationWithoutTrackNameShowsTheStation() {
        let media = NowPlayingMedia(song: "", mid: "https://bbc/6music", station: "BBC Radio 6 Music")

        XCTAssertEqual(media.displayedTitle, "BBC Radio 6 Music")
        // Would only repeat the title.
        XCTAssertNil(media.displayedStation)
    }

    @MainActor
    func testStationWithATrackNameKeepsBothLines() {
        let media = NowPlayingMedia(song: "Roy Ayers", mid: "https://wefunk", station: "WEFUNK Radio")

        XCTAssertEqual(media.displayedTitle, "Roy Ayers")
        XCTAssertEqual(media.displayedStation, "WEFUNK Radio")
    }

    @MainActor
    func testNothingPlayingStillSaysNotPlaying() {
        XCTAssertEqual(NowPlayingMedia().displayedTitle, "Not Playing")
    }

    // MARK: - Playback Error Dedupe

    @MainActor
    func testRepeatedPlaybackErrorShowsOneBanner() {
        let state = AppState()

        state.setError(.playbackFailed("Unable to stream from TuneIn. Please try again later."))
        XCTAssertEqual(state.toast?.text, "Unable to stream from TuneIn. Please try again later.")

        state.toast = nil
        state.setError(.playbackFailed("Unable to stream from TuneIn. Please try again later."))
        XCTAssertNil(state.toast)

        state.setError(.playbackFailed("A different error"))
        XCTAssertEqual(state.toast?.text, "A different error")
    }

    // MARK: - Stream Play Context

    @MainActor
    func testSetNowPlayingEnrichesGenericURLStream() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.pendingStreamContext = .init(
            pid: 42, stationName: "My Radio",
            browseMID: "https://stream.example.com/live",
            imageURL: "https://example.com/art.jpg",
            streamURL: "https://stream.example.com/live",
            previousMID: state.nowPlaying.mid
        )

        let generic = NowPlayingMedia(
            song: "Url Stream", album: "Url Stream", artist: "Url Stream",
            mid: "https://stream.example.com/live"
        )
        state.setNowPlaying(generic)

        XCTAssertEqual(state.nowPlaying.station, "My Radio")
        XCTAssertEqual(state.nowPlaying.imageURL, "https://example.com/art.jpg")
        // Context stays alive for subsequent device events with same stream
        XCTAssertNotNil(state.pendingStreamContext)
    }

    @MainActor
    func testOldTrackTailEventDoesNotKillFreshStreamContext() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.playback.nowPlaying = NowPlayingMedia(song: "Old Song", mid: "old-track-mid")
        state.pendingStreamContext = .init(
            pid: 42, stationName: "Fresh Station",
            browseMID: "u32", imageURL: "art.jpg",
            streamURL: "https://stream.example.com/live",
            previousMID: "old-track-mid"
        )

        // The device replays the outgoing track before the stream starts.
        state.setNowPlaying(NowPlayingMedia(song: "Old Song", mid: "old-track-mid"))
        XCTAssertNotNil(state.pendingStreamContext)

        // The stream then arrives and still gets enriched.
        state.setNowPlaying(NowPlayingMedia(song: "Url Stream", mid: "https://device.resolved/url"))
        XCTAssertEqual(state.nowPlaying.station, "Fresh Station")
    }

    @MainActor
    func testGenuinelyNewTrackDropsStaleStreamContext() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.pendingStreamContext = .init(
            pid: 42, stationName: "Stale Station", browseMID: "u32", imageURL: "art.jpg",
            streamURL: "https://stream.example.com/live", previousMID: "old-track-mid"
        )

        state.setNowPlaying(NowPlayingMedia(song: "Some New Song", mid: "another-track"))

        XCTAssertNil(state.pendingStreamContext)
        XCTAssertNil(state.nowPlaying.station)
    }

    @MainActor
    func testStreamContextBoundToOneStreamDoesNotEnrichAnother() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.pendingStreamContext = .init(
            pid: 42, stationName: "First Station", browseMID: "u32", imageURL: "art.jpg",
            streamURL: "https://one.example.com/live", previousMID: ""
        )
        state.setNowPlaying(NowPlayingMedia(song: "Url Stream", mid: "https://one.example.com/live"))
        XCTAssertEqual(state.nowPlaying.station, "First Station")

        // A different stream starts (e.g. from the amp itself): no stolen identity.
        state.setNowPlaying(NowPlayingMedia(song: "Url Stream", mid: "https://two.example.com/live"))
        XCTAssertNil(state.nowPlaying.station)
        XCTAssertNil(state.pendingStreamContext)
    }

    @MainActor
    func testRepeatedUrlStreamEventsAllGetEnriched() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.pendingStreamContext = .init(
            pid: 42, stationName: "My Radio",
            browseMID: "https://stream.example.com/live",
            imageURL: "https://example.com/art.jpg",
            streamURL: "https://stream.example.com/live",
            previousMID: state.nowPlaying.mid
        )

        let generic = NowPlayingMedia(
            song: "Url Stream", album: "Url Stream", artist: "Url Stream",
            mid: "https://stream.example.com/live"
        )

        // Device fires 3 now_playing_changed events
        state.setNowPlaying(generic)
        XCTAssertEqual(state.nowPlaying.station, "My Radio")

        state.setNowPlaying(generic)
        XCTAssertEqual(state.nowPlaying.station, "My Radio")

        state.setNowPlaying(generic)
        XCTAssertEqual(state.nowPlaying.station, "My Radio")
    }

    @MainActor
    func testSetNowPlayingDoesNotEnrichNonGenericMedia() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.pendingStreamContext = .init(
            pid: 42, stationName: "Old Station",
            browseMID: "u32", imageURL: "",
            streamURL: "https://old.url", previousMID: ""
        )

        let real = NowPlayingMedia(
            song: "Real Song", album: "Real Album", artist: "Real Artist",
            mid: "s12345", sid: 5
        )
        state.setNowPlaying(real)

        XCTAssertNil(state.nowPlaying.station)
        // Context cleared because a non-"Url Stream" track started
        XCTAssertNil(state.pendingStreamContext)
    }

    @MainActor
    func testSetNowPlayingIgnoresContextForWrongPlayer() {
        let state = AppState()
        state.selectedPlayerID = 99
        state.pendingStreamContext = .init(
            pid: 42, stationName: "Wrong Player",
            browseMID: "u32", imageURL: "",
            streamURL: "https://stream.example.com", previousMID: ""
        )

        let generic = NowPlayingMedia(
            song: "Url Stream", mid: "https://stream.example.com"
        )
        state.setNowPlaying(generic)

        XCTAssertNil(state.nowPlaying.station)
    }

    @MainActor
    func testStreamMIDAliasResolvesCustomArtwork() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.imageCache.customStationImages["u32"] = "https://example.com/custom-art.jpg"
        state.pendingStreamContext = .init(
            pid: 42, stationName: nil, browseMID: "u32",
            imageURL: "", streamURL: "https://icecast.radiofrance.fr/fip-hifi.aac",
            previousMID: ""
        )

        let generic = NowPlayingMedia(
            song: "Url Stream", mid: "https://icecast.radiofrance.fr/fip-hifi.aac"
        )
        state.setNowPlaying(generic)

        let resolved = state.resolvedImageURL(
            forMID: state.nowPlaying.mid, originalURL: ""
        )
        XCTAssertEqual(resolved, "https://example.com/custom-art.jpg")
    }

    @MainActor
    func testDisconnectClearsPendingStreamContext() {
        let state = AppState()
        state.pendingStreamContext = .init(
            pid: 42, stationName: "Test",
            browseMID: "u32", imageURL: "",
            streamURL: "https://example.com", previousMID: ""
        )

        state.setConnectionState(.disconnected)

        XCTAssertNil(state.pendingStreamContext)
    }

    @MainActor
    func testReconnectingKeepsTheSessionAndItsPlaybackState() {
        let state = AppState()
        state.setConnectionState(.connected)
        state.playback.playState = .play
        state.playback.nowPlaying = NowPlayingMedia(song: "Test", mid: "m1")

        state.setConnectionState(.reconnecting)

        XCTAssertTrue(state.hasEstablishedSession)
        XCTAssertEqual(state.playState, .play)
        XCTAssertEqual(state.nowPlaying.song, "Test")
    }

    @MainActor
    func testDisconnectEndsTheSession() {
        let state = AppState()
        state.setConnectionState(.connected)

        state.setConnectionState(.disconnected)

        XCTAssertFalse(state.hasEstablishedSession)
    }

    // MARK: - Group collapse / expand

    @MainActor
    func testGroupCollapsesByDefaultThenExpandsWhenMultiRoom() {
        let state = AppState()
        state.players = [Player(pid: 1, name: "Kitchen Left"), Player(pid: 2, name: "Kitchen Right")]
        state.setGroups([SpeakerGroup(gid: 1, name: "Kitchen", players: [
            GroupPlayer(name: "Kitchen Left", pid: 1, role: .leader),
            GroupPlayer(name: "Kitchen Right", pid: 2, role: .member)
        ])])

        // Collapsed by default: one row, labelled with the group name.
        XCTAssertEqual(state.displayPlayers.map(\.pid), [1])
        XCTAssertEqual(state.displayName(for: state.players[0]), "Kitchen")

        // Classified as multi-room: both rows, individual names.
        state.setMultiRoomGroups([1])
        XCTAssertEqual(state.displayPlayers.map(\.pid), [1, 2])
        XCTAssertEqual(state.displayName(for: state.players[0]), "Kitchen Left")
    }

    // MARK: - Stereo follower discovery

    @MainActor
    func testStereoPairFollowerHiddenFromDiscoveryList() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = AppState()
        state.discoveredDevices = [
            DiscoveredDevice(host: "10.0.0.1", friendlyName: "Kitchen Left", serialNumber: "SN-L"),
            DiscoveredDevice(host: "10.0.0.2", friendlyName: "Kitchen Right", serialNumber: "SN-R")
        ]
        state.players = [
            Player(pid: 1, name: "Kitchen Left", serial: "SN-L"),
            Player(pid: 2, name: "Kitchen Right", serial: "SN-R")
        ]
        state.setGroups([SpeakerGroup(gid: 1, name: "Kitchen", players: [
            GroupPlayer(name: "Kitchen Left", pid: 1, role: .leader),
            GroupPlayer(name: "Kitchen Right", pid: 2, role: .member)
        ])])

        // Stereo classification (members not multi-room) records the follower serial and persists it.
        state.setMultiRoomGroups([])
        XCTAssertEqual(state.knownFollowerSerials, ["SN-R"])
        XCTAssertEqual(state.visibleDiscoveredDevices.map(\.serialNumber), ["SN-L"])
        XCTAssertEqual(FollowerCache.load(), ["SN-R"])
    }

    @MainActor
    func testMultiRoomMembersNotHiddenFromDiscoveryList() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = AppState()
        state.discoveredDevices = [
            DiscoveredDevice(host: "10.0.0.1", serialNumber: "SN-L"),
            DiscoveredDevice(host: "10.0.0.2", serialNumber: "SN-R")
        ]
        state.players = [
            Player(pid: 1, name: "Kitchen", serial: "SN-L"),
            Player(pid: 2, name: "Bedroom", serial: "SN-R")
        ]
        state.setGroups([SpeakerGroup(gid: 1, name: "Everywhere", players: [
            GroupPlayer(name: "Kitchen", pid: 1, role: .leader),
            GroupPlayer(name: "Bedroom", pid: 2, role: .member)
        ])])

        state.setMultiRoomGroups([1])
        XCTAssertTrue(state.knownFollowerSerials.isEmpty)
        XCTAssertEqual(state.visibleDiscoveredDevices.count, 2)
    }

    // MARK: - Stereo pair naming

    @MainActor
    private func makePairState() -> AppState {
        let state = AppState()
        state.discoveredDevices = [
            DiscoveredDevice(host: "10.0.0.1", friendlyName: "Kitchen Left", serialNumber: "SN-L"),
            DiscoveredDevice(host: "10.0.0.2", friendlyName: "Kitchen Right", serialNumber: "SN-R")
        ]
        state.players = [
            Player(pid: 1, name: "Kitchen Left", serial: "SN-L"),
            Player(pid: 2, name: "Kitchen Right", serial: "SN-R")
        ]
        // HEOS reports the leader's name as the group name for a configured pair.
        state.setGroups([SpeakerGroup(gid: 1, name: "Kitchen Left", players: [
            GroupPlayer(name: "Kitchen Left", pid: 1, role: .leader),
            GroupPlayer(name: "Kitchen Right", pid: 2, role: .member)
        ])])
        return state
    }

    @MainActor
    func testPairLeaderShowsRoomNameNotLeaderName() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()

        state.setMultiRoomGroups([])

        XCTAssertEqual(state.displayName(for: state.players[0]), "Kitchen")
    }

    @MainActor
    func testPairNameIsPersistedForPreConnectDiscovery() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()

        state.setMultiRoomGroups([])

        // Keyed by serial and by leader name; discovery may report either.
        let expected = ["SN-L": "Kitchen", "Kitchen Left": "Kitchen"]
        XCTAssertEqual(state.knownPairNames, expected)
        XCTAssertEqual(FollowerCache.loadPairNames(), expected)
    }

    @MainActor
    func testDiscoveredPairLeaderUsesCachedRoomName() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()
        state.setMultiRoomGroups([])

        let leader = state.visibleDiscoveredDevices[0]
        XCTAssertEqual(state.displayName(for: leader), "Kitchen")
    }

    @MainActor
    func testBonjourPairLeaderWithoutSerialStillShowsRoomName() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()
        state.setMultiRoomGroups([])

        // Bonjour reports no serial, so only the leader name can carry the mapping.
        let bonjourLeader = DiscoveredDevice(host: "10.0.0.1", friendlyName: "Kitchen Left")
        XCTAssertEqual(state.displayName(for: bonjourLeader), "Kitchen")
    }

    @MainActor
    func testBonjourFollowerWithoutSerialIsHidden() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()
        state.setMultiRoomGroups([])

        state.discoveredDevices = [
            DiscoveredDevice(host: "10.0.0.1", friendlyName: "Kitchen Left"),
            DiscoveredDevice(host: "10.0.0.2", friendlyName: "Kitchen Right")
        ]

        XCTAssertEqual(state.visibleDiscoveredDevices.map(\.friendlyName), ["Kitchen Left"])
    }

    /// A group whose UPnP channels could not be read only collapses by fallback: caching its
    /// members by name would hide a plain multi-room speaker from discovery for good.
    @MainActor
    func testUnclassifiedGroupDoesNotHideItsMembersFromDiscovery() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()

        state.setMultiRoomGroups([], unconfirmed: [1])

        XCTAssertTrue(state.knownFollowerNames.isEmpty)
        XCTAssertTrue(FollowerCache.loadFollowerNames().isEmpty)
        state.discoveredDevices = [
            DiscoveredDevice(host: "10.0.0.1", friendlyName: "Kitchen Left"),
            DiscoveredDevice(host: "10.0.0.2", friendlyName: "Kitchen Right")
        ]
        XCTAssertEqual(
            state.visibleDiscoveredDevices.map(\.friendlyName),
            ["Kitchen Left", "Kitchen Right"]
        )
    }

    /// Same fallback, reached by serial: a Bonjour result that does carry one must not be
    /// hidden either, or a multi-room speaker vanishes until the channels read cleanly again.
    @MainActor
    func testUnclassifiedGroupDoesNotCacheItsMembersBySerial() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()

        state.setMultiRoomGroups([], unconfirmed: [1])

        XCTAssertTrue(state.knownFollowerSerials.isEmpty)
        XCTAssertTrue(FollowerCache.load().isEmpty)
        XCTAssertEqual(
            state.visibleDiscoveredDevices.map(\.friendlyName),
            ["Kitchen Left", "Kitchen Right"]
        )
    }

    /// A name learned from an unread group would survive as a pair label it was never proven to be.
    @MainActor
    func testUnclassifiedGroupDoesNotCacheAPairName() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()

        state.setMultiRoomGroups([], unconfirmed: [1])

        XCTAssertTrue(state.knownPairNames.isEmpty)
        XCTAssertTrue(FollowerCache.loadPairNames().isEmpty)
    }

    @MainActor
    func testDemoDataNeverTouchesTheRealCaches() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()
        state.persistsDiscoveryCaches = false

        state.setMultiRoomGroups([])

        XCTAssertTrue(state.knownFollowerNames.isEmpty)
        XCTAssertTrue(FollowerCache.loadFollowerNames().isEmpty)
        XCTAssertTrue(FollowerCache.loadPairNames().isEmpty)
    }

    @MainActor
    func testUngroupingClearsTheHidingCaches() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()
        state.setMultiRoomGroups([])
        XCTAssertFalse(state.knownFollowerNames.isEmpty)

        // The pair was taken apart, so the follower must become selectable again.
        state.setGroups([])
        state.setMultiRoomGroups([])

        XCTAssertTrue(state.knownFollowerNames.isEmpty)
        XCTAssertTrue(state.knownPairNames.isEmpty)
        XCTAssertTrue(FollowerCache.loadFollowerNames().isEmpty)
    }

    @MainActor
    func testUnknownDeviceKeepsItsFriendlyName() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = AppState()
        let device = DiscoveredDevice(host: "10.0.0.9", friendlyName: "Office", serialNumber: "SN-X")

        XCTAssertEqual(state.displayName(for: device), "Office")
    }

    @MainActor
    func testCorrectGroupNameIsLeftAlone() {
        FollowerCache.clear()
        defer { FollowerCache.clear() }
        let state = makePairState()
        state.setGroups([SpeakerGroup(gid: 1, name: "Kitchen", players: [
            GroupPlayer(name: "Kitchen Left", pid: 1, role: .leader),
            GroupPlayer(name: "Kitchen Right", pid: 2, role: .member)
        ])])

        state.setMultiRoomGroups([])

        XCTAssertEqual(state.displayName(for: state.players[0]), "Kitchen")
    }

    // MARK: - Per-speaker volume

    @MainActor
    func testSetPlayerVolumeStoresPerPid() {
        let state = AppState()
        state.setPlayerVolume(pid: 5001, level: 42)
        state.setPlayerVolume(pid: 5002, level: 38)
        XCTAssertEqual(state.playerVolumes[5001], 42)
        XCTAssertEqual(state.playerVolumes[5002], 38)
    }

    @MainActor
    func testSetPlayerVolumeIgnoredWhileAdjusting() {
        let state = AppState()
        state.setPlayerVolume(pid: 5001, level: 40)
        state.setAdjustingVolume(pid: 5001, true)

        state.setPlayerVolume(pid: 5001, level: 90) // event during drag, must be ignored

        XCTAssertEqual(state.playerVolumes[5001], 40)

        state.setAdjustingVolume(pid: 5001, false)
        state.setPlayerVolume(pid: 5001, level: 90)
        XCTAssertEqual(state.playerVolumes[5001], 90)
    }

    @MainActor
    func testAdjustingOnePidDoesNotBlockAnother() {
        let state = AppState()
        state.setAdjustingVolume(pid: 5001, true)
        state.setPlayerVolume(pid: 5002, level: 55)
        XCTAssertEqual(state.playerVolumes[5002], 55)
    }
}
