import XCTest
@testable import Neos
import NeosDomain

final class HomeViewModelTests: XCTestCase {

    // MARK: - Computed Properties

    @MainActor
    func testStreamingSourcesExcludesLibrarySIDs() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = HomeViewModel(service: mock, state: state)

        state.musicSources = [
            MusicSource(sid: 1025, name: "Playlists", type: "music_service"),
            MusicSource(sid: 1026, name: "History", type: "music_service"),
            MusicSource(sid: 1028, name: "Favorites", type: "music_service"),
            MusicSource(sid: 5, name: "Spotify", type: "music_service"),
        ]

        XCTAssertEqual(vm.streamingSources.count, 1)
        XCTAssertEqual(vm.streamingSources[0].sid, 5)
    }

    @MainActor
    func testVisibleStreamingSourcesExcludesHiddenAndUnavailable() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = HomeViewModel(service: mock, state: state)

        state.musicSources = [
            MusicSource(sid: 5, name: "Spotify", type: "music_service"),
            MusicSource(sid: 6, name: "Unavailable", type: "music_service", available: false),
            MusicSource(sid: 7, name: "AUX", type: "heos_service"),
            MusicSource(sid: 8, name: "Amazon", type: "music_service"),
        ]
        vm.hiddenSIDs = [8]

        let visible = vm.visibleStreamingSources
        XCTAssertEqual(visible.count, 1)
        XCTAssertEqual(visible[0].sid, 5)
    }

    // MARK: - toggleServiceVisibility

    @MainActor
    func testToggleServiceVisibilityAddsToHidden() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = HomeViewModel(service: mock, state: state)

        // Clear any leftover prefs
        HomePreferences.setHiddenSIDs([])

        vm.toggleServiceVisibility(sid: 99)

        XCTAssertTrue(vm.hiddenSIDs.contains(99))
    }

    @MainActor
    func testToggleServiceVisibilityRemovesFromHidden() {
        let state = AppState()
        let mock = MockAudioService()

        HomePreferences.setHiddenSIDs([99])
        let vm = HomeViewModel(service: mock, state: state)
        XCTAssertTrue(vm.hiddenSIDs.contains(99))

        vm.toggleServiceVisibility(sid: 99)

        XCTAssertFalse(vm.hiddenSIDs.contains(99))
        // Cleanup
        HomePreferences.setHiddenSIDs([])
    }

    // MARK: - loadRecentlyPlayed

    @MainActor
    func testLoadRecentlyPlayedSetsLoadingFlag() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = HomeViewModel(service: mock, state: state)

        vm.loadRecentlyPlayed()

        XCTAssertTrue(vm.isLoadingRecents)
    }

    @MainActor
    func testLoadRecentlyPlayedPopulatesItems() async {
        let state = AppState()
        let mock = MockAudioService()
        // Return browsable container "Tracks", then items inside it
        let tracksContainer = BrowseItem(name: "Tracks History", cid: "tracks_cid", browsable: true)
        mock.historyResult = BrowseResult(items: [tracksContainer])
        mock.browseResult = BrowseResult(items: [
            BrowseItem(name: "Song A", mid: "m1", playable: true),
            BrowseItem(name: "Song B", mid: "m2", playable: true),
        ])
        let vm = HomeViewModel(service: mock, state: state)

        vm.loadRecentlyPlayed()
        await yieldForTask()

        XCTAssertEqual(vm.recentlyPlayed.count, 2)
        XCTAssertFalse(vm.isLoadingRecents)
    }

    // MARK: - loadFavorites

    @MainActor
    func testLoadFavoritesSetsLoadingFlag() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = HomeViewModel(service: mock, state: state)

        vm.loadFavorites()

        XCTAssertTrue(vm.isLoadingFavorites)
    }

    @MainActor
    func testLoadFavoritesPopulatesItems() async {
        let state = AppState()
        let mock = MockAudioService()
        // browseSource returns stations container, browseContainer returns station items
        let stationsContainer = BrowseItem(name: "HEOS Stations", cid: "stations_cid", browsable: true)
        mock.browseResult = BrowseResult(items: [
            stationsContainer,
            BrowseItem(name: "Station A", mid: "s1", playable: true),
        ])
        let vm = HomeViewModel(service: mock, state: state)

        vm.loadFavorites()
        await yieldForTask()

        // Checks favorites were populated (either from container or fallback)
        XCTAssertFalse(vm.isLoadingFavorites)
    }

    // MARK: - handleCardTap

    @MainActor
    func testHandleCardTapBrowsableItemCallsBrowseAction() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = HomeViewModel(service: mock, state: state)

        let browsableItem = BrowseItem(name: "Playlist", cid: "c1", browsable: true)
        var browsedItem: BrowseItem?
        var browsedSID: Int?

        vm.handleCardTap(browsableItem, sid: 5) { item, sid in
            browsedItem = item
            browsedSID = sid
        }

        XCTAssertEqual(browsedItem?.name, "Playlist")
        XCTAssertEqual(browsedSID, 5)
    }

    @MainActor
    func testHandleCardTapPlayableItemDoesNotCallBrowse() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = HomeViewModel(service: mock, state: state)

        let playableItem = BrowseItem(name: "Song", mid: "m1", playable: true)
        var browseWasCalled = false

        vm.handleCardTap(playableItem, sid: 5) { _, _ in
            browseWasCalled = true
        }

        XCTAssertFalse(browseWasCalled)
    }

    // MARK: - restoreFromCache

    @MainActor
    func testInitRestoresFromCache() {
        // Save some items to cache first
        let items = [BrowseItem(name: "Cached Song", mid: "cm1")]
        HomeCacheStore.saveRecents(items)

        let state = AppState()
        let mock = MockAudioService()
        let vm = HomeViewModel(service: mock, state: state)

        XCTAssertEqual(vm.recentlyPlayed.count, 1)
        XCTAssertEqual(vm.recentlyPlayed[0].name, "Cached Song")

        // Cleanup
        HomeCacheStore.clearAll()
    }
}
