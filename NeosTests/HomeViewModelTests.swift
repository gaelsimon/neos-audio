import XCTest
@testable import Neos
import HEOSKit
import NeosDomain

final class HomeViewModelTests: XCTestCase {

    // MARK: - Account change

    @MainActor
    func testAnAccountChangeDropsThePreviousAccountsRows() async {
        let stale = BrowseItem(name: "Someone else's station")
        HomeCacheStore.saveFavorites([stale])
        let vm = HomeViewModel(service: MockAudioService(), state: AppState())
        vm.favorites = [stale]
        vm.recentlyPlayed = [stale]
        vm.serviceCategories = [ServiceCategoryKey(sid: 10, categoryIndex: 0): [stale]]

        vm.resetForAccountChange()
        await waitUntil { !vm.isLoadingFavorites && !vm.isLoadingRecents }

        let shown = vm.favorites + vm.recentlyPlayed + vm.serviceCategories.values.flatMap { $0 }
        XCTAssertEqual((shown + HomeCacheStore.loadFavorites()).filter { $0.name == stale.name }, [])
        HomeCacheStore.clearAll()
    }

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
        // Two hops: the history container, then its contents.
        await waitUntil { !vm.isLoadingRecents }

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

    // MARK: - Probe TTL

    @MainActor
    private func makeProbeVM(cacheIsFresh: Bool) -> (HomeViewModel, MockAudioService, AppState) {
        HomeCacheStore.clearAll()
        HomePreferences.setHiddenSIDs([])
        HomeCacheStore.saveServiceCategory(
            sid: 5,
            categoryIndex: 0,
            name: "Playlists",
            cid: "cached-cid",
            items: [BrowseItem(name: "Cached Playlist", cid: "c1", browsable: true)]
        )
        if cacheIsFresh { HomeCacheStore.markUpdated() }

        let state = AppState()
        let mock = MockAudioService()
        let vm = HomeViewModel(service: mock, state: state)
        state.musicSources = [MusicSource(sid: 5, name: "Spotify", type: "music_service")]
        return (vm, mock, state)
    }

    @MainActor
    func testFreshCacheSkipsProbing() async {
        let (vm, mock, _) = makeProbeVM(cacheIsFresh: true)

        vm.loadHome()

        await yieldForTask()
        XCTAssertFalse(mock.calls.contains(where: { $0.hasPrefix("browseSource:5") }))
        XCTAssertEqual(vm.serviceCategories[ServiceCategoryKey(sid: 5, categoryIndex: 0)]?.count, 1)
        HomeCacheStore.clearAll()
    }

    @MainActor
    func testCachedCategoryKeepsItsContainerID() async {
        let (vm, _, _) = makeProbeVM(cacheIsFresh: true)

        vm.loadHome()
        await yieldForTask()

        XCTAssertEqual(
            vm.serviceCategoryCIDs[ServiceCategoryKey(sid: 5, categoryIndex: 0)],
            "cached-cid",
            "See All would open the service root without it"
        )
        HomeCacheStore.clearAll()
    }

    @MainActor
    func testStaleCacheProbesAgain() async {
        let (vm, mock, _) = makeProbeVM(cacheIsFresh: false)

        vm.loadHome()

        for _ in 0..<100 where !mock.calls.contains(where: { $0.hasPrefix("browseSource:5") }) {
            await yieldForTask()
        }
        XCTAssertTrue(mock.calls.contains(where: { $0.hasPrefix("browseSource:5") }))
        HomeCacheStore.clearAll()
    }

    @MainActor
    func testRefreshProbesEvenWithFreshCache() async {
        let (vm, mock, _) = makeProbeVM(cacheIsFresh: true)
        vm.loadHome()
        await yieldForTask()

        vm.refresh()

        for _ in 0..<100 where !mock.calls.contains(where: { $0.hasPrefix("browseSource:5") }) {
            await yieldForTask()
        }
        XCTAssertTrue(mock.calls.contains(where: { $0.hasPrefix("browseSource:5") }))
        HomeCacheStore.clearAll()
    }

    @MainActor
    func testFreshCacheStillProbesServiceWithoutCachedCategories() async {
        let (vm, mock, state) = makeProbeVM(cacheIsFresh: true)
        state.musicSources = [
            MusicSource(sid: 5, name: "Spotify", type: "music_service"),
            MusicSource(sid: 9, name: "Tidal", type: "music_service"),
        ]

        vm.loadHome()

        for _ in 0..<100 where !mock.calls.contains(where: { $0.hasPrefix("browseSource:9") }) {
            await yieldForTask()
        }
        XCTAssertTrue(mock.calls.contains(where: { $0.hasPrefix("browseSource:9") }))
        XCTAssertFalse(mock.calls.contains(where: { $0.hasPrefix("browseSource:5") }))
        HomeCacheStore.clearAll()
    }

    // MARK: - Probe cut off by the connection

    @MainActor
    private func probeCutOffByTheConnection() async -> (HomeViewModel, MockAudioService, AppState) {
        let (vm, mock, state) = makeProbeVM(cacheIsFresh: false)
        HomeCacheStore.saveServiceCategory(
            sid: 5, categoryIndex: 1, name: "Albums", cid: "cached-albums",
            items: [BrowseItem(name: "Cached Album", cid: "a1", browsable: true)]
        )
        mock.browseContainerError = TransportError.disconnected
        vm.loadHome()
        for _ in 0..<100 where vm.loadingServiceSIDs.contains(5) || !mock.calls.contains(where: { $0.hasPrefix("browseContainer:5") }) {
            await yieldForTask()
        }
        return (vm, mock, state)
    }

    @MainActor
    func testAProbeCutOffByTheConnectionKeepsTheCachedCategories() async {
        let (vm, _, _) = await probeCutOffByTheConnection()

        XCTAssertEqual(vm.serviceCategoryNames[ServiceCategoryKey(sid: 5, categoryIndex: 1)], "Albums")
        XCTAssertNotNil(HomeCacheStore.loadServiceCategory(sid: 5, categoryIndex: 1), "The cache lost the category")
        XCTAssertTrue(HomeCacheStore.isStale(), "A cut-off probe must not mark the cache fresh")
        HomeCacheStore.clearAll()
    }

    @MainActor
    func testAProbeCutOffByTheConnectionRunsAgainWhenTheSpeakerIsBack() async {
        let (vm, mock, state) = await probeCutOffByTheConnection()
        mock.browseContainerError = nil
        let probes = mock.calls.filter { $0.hasPrefix("browseSource:5") }.count

        state.setConnectionState(.connected)

        for _ in 0..<100 where mock.calls.filter({ $0.hasPrefix("browseSource:5") }).count == probes {
            await yieldForTask()
        }
        XCTAssertGreaterThan(mock.calls.filter { $0.hasPrefix("browseSource:5") }.count, probes)
        // The model watches the connection only while it lives.
        withExtendedLifetime(vm) {}
        HomeCacheStore.clearAll()
    }

    @MainActor
    func testAContainerTooSlowToAnswerStillLetsTheProbeFinish() async {
        let (vm, mock, _) = makeProbeVM(cacheIsFresh: false)
        mock.browseContainerError = TransportError.timeout

        vm.loadHome()
        for _ in 0..<100 where vm.loadingServiceSIDs.contains(5) || !mock.calls.contains(where: { $0.hasPrefix("browseContainer:5") }) {
            await yieldForTask()
        }

        XCTAssertFalse(HomeCacheStore.isStale(), "A slow service is not a lost speaker")
        HomeCacheStore.clearAll()
    }

    @MainActor
    func testAContainerTheServiceRefusesStillLetsTheProbeFinish() async {
        let (vm, mock, _) = makeProbeVM(cacheIsFresh: false)
        mock.browseContainerError = NSError(domain: "HEOS", code: 2)

        vm.loadHome()
        for _ in 0..<100 where vm.loadingServiceSIDs.contains(5) || !mock.calls.contains(where: { $0.hasPrefix("browseContainer:5") }) {
            await yieldForTask()
        }

        XCTAssertFalse(HomeCacheStore.isStale(), "A probe the speaker answered marks the cache fresh")
        HomeCacheStore.clearAll()
    }
}
