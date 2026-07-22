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
        state.isLoadingTrack = true

        state.setPlayState(.pause)

        XCTAssertFalse(state.isLoadingTrack)
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

    // MARK: - Stream Play Context

    @MainActor
    func testSetNowPlayingEnrichesGenericURLStream() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.pendingStreamContext = .init(
            pid: 42, stationName: "My Radio",
            browseMID: "https://stream.example.com/live",
            imageURL: "https://example.com/art.jpg",
            streamURL: "https://stream.example.com/live"
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
    func testRepeatedUrlStreamEventsAllGetEnriched() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.pendingStreamContext = .init(
            pid: 42, stationName: "My Radio",
            browseMID: "https://stream.example.com/live",
            imageURL: "https://example.com/art.jpg",
            streamURL: "https://stream.example.com/live"
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
            streamURL: "https://old.url"
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
            streamURL: "https://stream.example.com"
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
            imageURL: "", streamURL: "https://icecast.radiofrance.fr/fip-hifi.aac"
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
            streamURL: "https://example.com"
        )

        state.setConnectionState(.disconnected)

        XCTAssertNil(state.pendingStreamContext)
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
}
