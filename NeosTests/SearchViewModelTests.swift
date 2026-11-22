import XCTest
@testable import Neos
import NeosDomain

final class SearchViewModelTests: XCTestCase {

    // MARK: - clearSearch

    @MainActor
    func testClearSearchResetsAllState() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.query = "rock"
        vm.overlayPhase = .active
        vm.isSearching = true
        vm.serviceResults = [ServiceCriteriaKey(sid: 1, scid: 1): []]
        vm.expandedCategories = [ServiceCriteriaKey(sid: 1, scid: 1)]
        vm.selectedCategoryFilter = 1
        vm.selectedServiceFilters = [1]

        vm.clearSearch()

        XCTAssertEqual(vm.query, "")
        XCTAssertEqual(vm.overlayPhase, .inactive)
        XCTAssertFalse(vm.isOverlayVisible)
        XCTAssertFalse(vm.hasSuspendedSearch)
        XCTAssertFalse(vm.isSearching)
        XCTAssertTrue(vm.serviceResults.isEmpty)
        XCTAssertTrue(vm.expandedCategories.isEmpty)
        XCTAssertNil(vm.selectedCategoryFilter)
        XCTAssertEqual(vm.selectedServiceFilters, [1], "The chosen services outlive a search")
    }

    // MARK: - dismissOverlay

    @MainActor
    func testDismissOverlayHidesWithoutClearing() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.query = "rock"
        vm.overlayPhase = .active
        let key = ServiceCriteriaKey(sid: 1, scid: 1)
        vm.serviceResults = [key: [BrowseItem(name: "Song")]]

        vm.dismissOverlay()

        XCTAssertFalse(vm.isOverlayVisible)
        XCTAssertEqual(vm.query, "rock")
        XCTAssertFalse(vm.serviceResults.isEmpty)
    }

    // MARK: - SearchOverlayPhase Lifecycle

    @MainActor
    func testActivateOverlaySetsActive() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.activateOverlay()

        XCTAssertEqual(vm.overlayPhase, .active)
        XCTAssertTrue(vm.isOverlayVisible)
        XCTAssertFalse(vm.hasSuspendedSearch)
    }

    @MainActor
    func testSuspendForNavigationCapturesIndex() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.overlayPhase = .active
        vm.suspendForNavigation(originToken: 3)

        XCTAssertEqual(vm.overlayPhase, .suspended(originToken: 3))
        XCTAssertFalse(vm.isOverlayVisible)
        XCTAssertTrue(vm.hasSuspendedSearch)
    }

    @MainActor
    func testSuspendForNavigationIgnoredWhenNotActive() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.overlayPhase = .inactive
        vm.suspendForNavigation(originToken: 3)

        XCTAssertEqual(vm.overlayPhase, .inactive)
    }

    @MainActor
    func testTryRestoreSucceedsAtMatchingToken() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.serviceResults = [ServiceCriteriaKey(sid: 1, scid: 1): [BrowseItem(name: "Song")]]
        vm.overlayPhase = .suspended(originToken: 2)

        let restored = vm.tryRestore(atToken: 2)

        XCTAssertTrue(restored)
        XCTAssertEqual(vm.overlayPhase, .active)
        XCTAssertTrue(vm.isOverlayVisible)
    }

    @MainActor
    func testDismissOverlayDoesNotKillSuspendedSearch() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.serviceResults = [ServiceCriteriaKey(sid: 1, scid: 1): [BrowseItem(name: "Song")]]
        vm.overlayPhase = .suspended(originToken: 2)

        // An ambient dismissal (player-bar link, amp settings button) while suspended.
        vm.dismissOverlay()

        XCTAssertTrue(vm.tryRestore(atToken: 2))
        XCTAssertTrue(vm.isOverlayVisible)
    }

    @MainActor
    func testTryRestoreFailsAtOtherToken() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.serviceResults = [ServiceCriteriaKey(sid: 1, scid: 1): [BrowseItem(name: "Song")]]
        vm.overlayPhase = .suspended(originToken: 2)

        let restored = vm.tryRestore(atToken: 5)

        XCTAssertFalse(restored)
        XCTAssertEqual(vm.overlayPhase, .suspended(originToken: 2))
    }

    @MainActor
    func testTryRestoreFailsWithEmptyResults() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.serviceResults = [:]
        vm.overlayPhase = .suspended(originToken: 2)

        let restored = vm.tryRestore(atToken: 2)

        XCTAssertFalse(restored)
        XCTAssertFalse(vm.isOverlayVisible)
    }

    @MainActor
    func testEmptyingTheQueryClearsASuspension() {
        let state = AppState()
        let vm = SearchViewModel(service: MockAudioService(), state: state)
        vm.serviceResults = [ServiceCriteriaKey(sid: 1, scid: 1): [BrowseItem(name: "Song")]]
        vm.overlayPhase = .suspended(originToken: 2)

        vm.onQueryChanged("")

        // Results are gone; a surviving suspension would only strand the back arrow.
        XCTAssertFalse(vm.hasSuspendedSearch)
    }

    @MainActor
    func testClearSearchClearsSuspension() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.overlayPhase = .suspended(originToken: 2)

        vm.clearSearch()

        XCTAssertEqual(vm.overlayPhase, .inactive)
        XCTAssertFalse(vm.hasSuspendedSearch)
    }

    // MARK: - selectCategoryFilter

    @MainActor
    func testSelectCategoryFilterSetsFilter() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.selectCategoryFilter(5)

        XCTAssertEqual(vm.selectedCategoryFilter, 5)
    }

    @MainActor
    func testSelectCategoryFilterTogglesOff() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.selectCategoryFilter(5)
        vm.selectCategoryFilter(5)

        XCTAssertNil(vm.selectedCategoryFilter)
    }

    @MainActor
    func testSelectCategoryFilterSwitchesValue() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.selectCategoryFilter(5)
        vm.selectCategoryFilter(10)

        XCTAssertEqual(vm.selectedCategoryFilter, 10)
    }

    // MARK: - selectServiceFilter

    @MainActor
    func testSelectServiceFilterSetsFilter() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.selectServiceFilter(3)

        XCTAssertEqual(vm.selectedServiceFilters, [3])
    }

    @MainActor
    func testSelectServiceFilterTogglesOff() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.selectServiceFilter(3)
        vm.selectServiceFilter(3)

        XCTAssertTrue(vm.selectedServiceFilters.isEmpty)
    }

    // MARK: - searchableServices

    @MainActor
    func testSearchableServicesExcludesLibraryAndUnavailable() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        state.musicSources = [
            MusicSource(sid: 1025, name: "Playlists", type: "music_service"),  // library SID
            MusicSource(sid: 1026, name: "History", type: "music_service"),    // library SID
            MusicSource(sid: 5, name: "Spotify", type: "music_service"),       // valid
            MusicSource(sid: 6, name: "Unavailable", type: "music_service", available: false),
            MusicSource(sid: 7, name: "AUX Input", type: "heos_server"),       // input source; excluded
            MusicSource(sid: 8, name: "Local Music", type: "heos_server"),     // valid; local server
        ]

        let services = vm.searchableServices
        XCTAssertEqual(services.count, 2)
        XCTAssertEqual(services[0].sid, 5)
        XCTAssertEqual(services[1].sid, 8)
    }

    // MARK: - filteredServiceSIDs

    @MainActor
    func testFilteredServiceSIDsReturnsAllWhenNoFilter() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        state.musicSources = [
            MusicSource(sid: 5, name: "Tidal", type: "music_service"),
            MusicSource(sid: 10, name: "Deezer", type: "music_service"),
        ]
        state.searchCriteria = [
            5: [SearchCriteria(scid: 1, name: "Track")],
            10: [SearchCriteria(scid: 1, name: "Track")],
        ]
        vm.serviceResults = [
            ServiceCriteriaKey(sid: 5, scid: 1): [BrowseItem(name: "A")],
            ServiceCriteriaKey(sid: 10, scid: 1): [BrowseItem(name: "B")],
        ]

        let sids = vm.filteredServiceSIDs
        XCTAssertEqual(Set(sids), Set([5, 10]))
    }

    @MainActor
    func testFilteredServiceSIDsFiltersToSelected() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        state.musicSources = [
            MusicSource(sid: 5, name: "Tidal", type: "music_service"),
            MusicSource(sid: 10, name: "Deezer", type: "music_service"),
        ]
        state.searchCriteria = [
            5: [SearchCriteria(scid: 1, name: "Track")],
            10: [SearchCriteria(scid: 1, name: "Track")],
        ]
        vm.serviceResults = [
            ServiceCriteriaKey(sid: 5, scid: 1): [BrowseItem(name: "A")],
            ServiceCriteriaKey(sid: 10, scid: 1): [BrowseItem(name: "B")],
        ]
        vm.selectedServiceFilters = [5]

        XCTAssertEqual(vm.filteredServiceSIDs, [5])
    }

    @MainActor
    func testFilteredServiceSIDsLeaveOutAServiceThatFoundNothing() {
        let state = AppState()
        let vm = SearchViewModel(service: MockAudioService(), state: state)
        state.musicSources = [
            MusicSource(sid: 5, name: "Tidal", type: "music_service"),
            MusicSource(sid: 10, name: "Deezer", type: "music_service"),
        ]
        state.searchCriteria = [
            5: [SearchCriteria(scid: 1, name: "Track")],
            10: [SearchCriteria(scid: 1, name: "Track")],
        ]

        vm.serviceResults = [
            ServiceCriteriaKey(sid: 5, scid: 1): [],
            ServiceCriteriaKey(sid: 10, scid: 1): [BrowseItem(name: "B")],
        ]

        XCTAssertEqual(vm.filteredServiceSIDs, [10])
    }

    @MainActor
    func testFilteredServiceSIDsAreEmptyWhenEveryServiceFoundNothing() {
        let state = AppState()
        let vm = SearchViewModel(service: MockAudioService(), state: state)
        state.musicSources = [MusicSource(sid: 5, name: "Tidal", type: "music_service")]
        state.searchCriteria = [5: [SearchCriteria(scid: 1, name: "Track")]]

        vm.serviceResults = [ServiceCriteriaKey(sid: 5, scid: 1): []]

        XCTAssertTrue(vm.filteredServiceSIDs.isEmpty)
    }

    @MainActor
    func testFilteredServiceSIDsLeaveOutAServiceWithNothingInTheChosenCategory() {
        let state = AppState()
        let vm = SearchViewModel(service: MockAudioService(), state: state)
        state.musicSources = [
            MusicSource(sid: 5, name: "Tidal", type: "music_service"),
            MusicSource(sid: 10, name: "Deezer", type: "music_service"),
        ]
        state.searchCriteria = [
            5: [SearchCriteria(scid: 1, name: "Track")],
            10: [SearchCriteria(scid: 1, name: "Track"), SearchCriteria(scid: 2, name: "Album")],
        ]
        vm.serviceResults = [
            ServiceCriteriaKey(sid: 5, scid: 1): [BrowseItem(name: "A")],
            ServiceCriteriaKey(sid: 10, scid: 2): [BrowseItem(name: "B")],
        ]

        vm.selectedCategoryFilter = 2

        XCTAssertEqual(vm.filteredServiceSIDs, [10])
    }

    @MainActor
    func testFilteredServiceSIDsKeepAServiceThatIsStillSearching() {
        let state = AppState()
        let vm = SearchViewModel(service: MockAudioService(), state: state)
        state.musicSources = [MusicSource(sid: 5, name: "Tidal", type: "music_service")]
        state.searchCriteria = [5: [SearchCriteria(scid: 1, name: "Track")]]

        vm.loadingServiceSIDs = [5]

        XCTAssertEqual(vm.filteredServiceSIDs, [5])
    }

    @MainActor
    func testAChosenServiceThatIsGoneShowsEveryService() {
        let state = AppState()
        let vm = SearchViewModel(service: MockAudioService(), state: state)
        state.musicSources = [MusicSource(sid: 5, name: "Tidal", type: "music_service")]
        state.searchCriteria = [5: [SearchCriteria(scid: 1, name: "Track")]]
        vm.serviceResults = [
            ServiceCriteriaKey(sid: 5, scid: 1): [BrowseItem(name: "A")],
        ]
        vm.selectedServiceFilters = [99]

        XCTAssertEqual(vm.filteredServiceSIDs, [5])
    }

    // MARK: - Several services

    @MainActor
    private func makeSoundCloudAndTidal() -> (SearchViewModel, AppState) {
        let state = AppState()
        state.musicSources = [
            MusicSource(sid: 5, name: "Deezer", type: "music_service"),
            MusicSource(sid: 9, name: "SoundCloud", type: "music_service"),
            MusicSource(sid: 10, name: "Tidal", type: "music_service"),
        ]
        // As the amp answers get_search_criteria.
        state.searchCriteria = [
            5: [SearchCriteria(scid: 1, name: "Artist"), SearchCriteria(scid: 2, name: "Album"), SearchCriteria(scid: 3, name: "Track")],
            9: [SearchCriteria(scid: 7, name: "Accounts"), SearchCriteria(scid: 3, name: "Track")],
            10: [
                SearchCriteria(scid: 1, name: "Artist"), SearchCriteria(scid: 2, name: "Album"),
                SearchCriteria(scid: 3, name: "Track"), SearchCriteria(scid: 6, name: "Playlist"),
            ],
        ]
        return (SearchViewModel(service: MockAudioService(), state: state), state)
    }

    @MainActor
    func testTheKindsAreWhatTheChosenServiceSearches() {
        let (vm, _) = makeSoundCloudAndTidal()

        vm.selectServiceFilter(9)

        XCTAssertEqual(vm.categoryOptions.map(\.name), ["Track", "Accounts"])
    }

    @MainActor
    func testTheKindsOfTwoServicesAreBothServicesKinds() {
        let (vm, _) = makeSoundCloudAndTidal()

        vm.selectServiceFilter(9)
        vm.selectServiceFilter(10)

        XCTAssertEqual(vm.categoryOptions.map(\.scid), [1, 2, 3, 6, 7])
    }

    @MainActor
    func testAKindNoChosenServiceSearchesGoesBackToAll() {
        let (vm, _) = makeSoundCloudAndTidal()
        vm.selectedCategoryFilter = 1

        vm.selectServiceFilter(9)

        XCTAssertNil(vm.selectedCategoryFilter)
    }

    @MainActor
    func testTwoChosenServicesShowTogetherInTheSourcesOrder() {
        let (vm, _) = makeSoundCloudAndTidal()
        vm.serviceResults = [
            ServiceCriteriaKey(sid: 5, scid: 3): [BrowseItem(name: "A")],
            ServiceCriteriaKey(sid: 9, scid: 3): [BrowseItem(name: "B")],
            ServiceCriteriaKey(sid: 10, scid: 3): [BrowseItem(name: "C")],
        ]

        vm.selectServiceFilter(10)
        vm.selectServiceFilter(9)

        XCTAssertEqual(vm.filteredServiceSIDs, [9, 10])
    }

    @MainActor
    func testAllServicesUnticksEveryService() {
        let (vm, _) = makeSoundCloudAndTidal()
        vm.selectServiceFilter(9)
        vm.selectServiceFilter(10)

        vm.selectServiceFilter(nil)

        XCTAssertTrue(vm.selectedServiceFilters.isEmpty)
    }

    @MainActor
    func testTheChosenServicesAreThereAtTheNextLaunch() async {
        await withIsolatedStores { defaults in
            let (vm, state) = makeSoundCloudAndTidal()
            let first = SearchViewModel(service: MockAudioService(), state: state, filterStore: defaults)
            first.selectServiceFilter(9)
            first.selectServiceFilter(10)

            let next = SearchViewModel(service: MockAudioService(), state: state, filterStore: defaults)

            XCTAssertEqual(next.selectedServiceFilters, [9, 10])
            XCTAssertTrue(vm.selectedServiceFilters.isEmpty, "A model without a store keeps nothing")
        }
    }

    @MainActor
    func testOnlyTheChosenServicesAreSearched() async {
        let (_, state) = makeSoundCloudAndTidal()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)
        vm.selectServiceFilter(9)
        vm.selectServiceFilter(10)

        vm.onQueryChanged("mi")
        await waitUntil { !vm.isSearching && !mock.calls.filter { $0.hasPrefix("search:") }.isEmpty }

        let searched = Set(mock.calls.filter { $0.hasPrefix("search:") }.map { $0.split(separator: ":")[1] })
        XCTAssertEqual(searched, ["9", "10"])
        vm.clearSearch()
    }

    // MARK: - allCriteriaNames

    @MainActor
    func testAllCriteriaNamesDeduplicates() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        // Two services have criteria with same scid=1
        state.searchCriteria = [
            5: [SearchCriteria(scid: 1, name: "Track"), SearchCriteria(scid: 2, name: "Album")],
            10: [SearchCriteria(scid: 1, name: "Track"), SearchCriteria(scid: 3, name: "Artist")],
        ]
        // Only scid 1 and 3 have results
        vm.serviceResults = [
            ServiceCriteriaKey(sid: 5, scid: 1): [BrowseItem(name: "A")],
            ServiceCriteriaKey(sid: 10, scid: 3): [BrowseItem(name: "B")],
        ]

        let criteria = vm.allCriteriaNames
        XCTAssertEqual(criteria.count, 2)
        XCTAssertEqual(criteria[0].scid, 1)
        XCTAssertEqual(criteria[1].scid, 3)
    }

    // MARK: - filteredResults

    @MainActor
    func testFilteredResultsLimitsToPreviewCount() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        state.searchCriteria = [
            5: [SearchCriteria(scid: 1, name: "Track")]
        ]
        let items = (0..<10).map { BrowseItem(name: "Song \($0)", mid: "m\($0)") }
        vm.serviceResults = [ServiceCriteriaKey(sid: 5, scid: 1): items]

        let results = vm.filteredResults(for: 5)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].items.count, vm.previewCount)
    }

    @MainActor
    func testFilteredResultsShowsAllWhenExpanded() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        let key = ServiceCriteriaKey(sid: 5, scid: 1)
        state.searchCriteria = [5: [SearchCriteria(scid: 1, name: "Track")]]
        let items = (0..<10).map { BrowseItem(name: "Song \($0)", mid: "m\($0)") }
        vm.serviceResults = [key: items]
        vm.expandedCategories = [key]

        let results = vm.filteredResults(for: 5)
        XCTAssertEqual(results[0].items.count, 10)
    }

    @MainActor
    func testFilteredResultsAppliesCategoryFilter() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        state.searchCriteria = [
            5: [SearchCriteria(scid: 1, name: "Track"), SearchCriteria(scid: 2, name: "Album")]
        ]
        vm.serviceResults = [
            ServiceCriteriaKey(sid: 5, scid: 1): [BrowseItem(name: "Song")],
            ServiceCriteriaKey(sid: 5, scid: 2): [BrowseItem(name: "Album")],
        ]
        vm.selectedCategoryFilter = 1

        let results = vm.filteredResults(for: 5)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].criteria.scid, 1)
    }

    // MARK: - musicSource lookup

    @MainActor
    func testMusicSourceFindsTopLevelSource() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        state.musicSources = [
            MusicSource(sid: 5, name: "Spotify", type: "music_service"),
        ]

        XCTAssertEqual(vm.musicSource(for: 5)?.name, "Spotify")
        XCTAssertNil(vm.musicSource(for: 99))
    }

    // MARK: - allSearchableServices

    @MainActor
    func testAllSearchableServicesIncludesDiscoveredSubSources() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        state.musicSources = [
            MusicSource(sid: 5, name: "Spotify", type: "music_service"),
            MusicSource(sid: 1024, name: "Local Music", type: "heos_server"),
        ]
        // Spotify has criteria, Local Music does not
        state.searchCriteria[5] = [SearchCriteria(scid: 1, name: "Track")]

        let services = vm.allSearchableServices
        // Only Spotify; Local Music has no criteria and no sub-sources yet
        XCTAssertEqual(services.count, 1)
        XCTAssertEqual(services[0].sid, 5)
    }

    // MARK: - onQueryChanged

    @MainActor
    func testOnQueryChangedEmptyClearsSearch() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.query = "rock"
        vm.overlayPhase = .active
        vm.serviceResults = [ServiceCriteriaKey(sid: 1, scid: 1): [BrowseItem(name: "A")]]

        vm.onQueryChanged("")

        XCTAssertEqual(vm.query, "")
        XCTAssertFalse(vm.isOverlayVisible)
        XCTAssertTrue(vm.serviceResults.isEmpty)
    }

    @MainActor
    func testOnQueryChangedWhitespaceOnlyClearsSearch() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.overlayPhase = .active

        vm.onQueryChanged("   ")

        XCTAssertFalse(vm.isOverlayVisible)
    }

    @MainActor
    func testOnQueryChangedActivatesSearch() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.onQueryChanged("rock")

        XCTAssertEqual(vm.query, "rock")
        XCTAssertTrue(vm.isOverlayVisible)
    }

    // MARK: - Local server preferences

    @MainActor
    private func makeLocalMusicSearch(
        unsearchable: String,
        defaults: UserDefaults,
        criteriaFromBrowsing: [Int: [SearchCriteria]] = [:]
    ) -> (SearchViewModel, MockAudioService, LocalServerPreferences) {
        let prefs = LocalServerPreferences(defaults: defaults)
        prefs.setSearchable(false, for: unsearchable)
        let state = AppState()
        state.searchCriteria = criteriaFromBrowsing
        state.musicSources = [MusicSource(sid: HEOSConstants.localMusicSID, name: "Local Music", type: "heos_server")]
        let mock = MockAudioService()
        mock.searchCriteriaBySID = [HEOSConstants.localMusicSID: []]
        mock.browseResultsBySID = [HEOSConstants.localMusicSID: BrowseResult(items: [
            BrowseItem(name: "Kantele NAS", type: .heosServer, sid: -1),
            BrowseItem(name: "NASPERES", type: .heosServer, sid: -2),
        ])]
        return (SearchViewModel(service: mock, state: state, serverPreferences: prefs), mock, prefs)
    }

    @MainActor
    private func withIsolatedStores(_ body: (UserDefaults) async -> Void) async {
        let savedHistory = SearchHistoryStore.recentQueries()
        let suiteName = "SearchViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        await body(defaults)
        defaults.removePersistentDomain(forName: suiteName)
        SearchHistoryStore.clearAll()
        savedHistory.reversed().forEach(SearchHistoryStore.addQuery)
    }

    @MainActor
    func testUnsearchableServerIsNeverQueried() async {
        await withIsolatedStores { defaults in
            let (vm, mock, _) = makeLocalMusicSearch(unsearchable: "NASPERES", defaults: defaults)

            vm.onQueryChanged("paris")
            await waitUntil { mock.calls.contains { $0.hasPrefix("search:-1:") } && !vm.isSearching }

            XCTAssertEqual(mock.calls.filter { $0.contains(":-2") }, [])
        }
    }

    @MainActor
    func testAServerOpenedBeforeSearchingIsStillSearched() async {
        await withIsolatedStores { defaults in
            let (vm, mock, _) = makeLocalMusicSearch(
                unsearchable: "NASPERES", defaults: defaults,
                criteriaFromBrowsing: [-1: MockData.searchCriteria]
            )

            vm.onQueryChanged("paris")
            await waitUntil { !vm.isSearching && mock.calls.contains { $0.hasPrefix("search:") } }

            XCTAssertNotNil(vm.discoveredSubSources[-1])
            XCTAssertTrue(mock.calls.contains { $0.hasPrefix("search:-1:") })
        }
    }

    @MainActor
    func testFilterOnAServerTakenOutOfSearchFallsBackToAll() async {
        await withIsolatedStores { defaults in
            let (vm, mock, _) = makeLocalMusicSearch(unsearchable: "NASPERES", defaults: defaults)
            vm.selectedServiceFilters = [-2]

            vm.onQueryChanged("paris")
            await waitUntil { mock.calls.contains { $0.hasPrefix("search:-1:") } && !vm.isSearching }

            XCTAssertTrue(vm.activeServiceFilters.isEmpty)
            XCTAssertEqual(vm.selectedServiceFilters, [-2], "Kept for when the server is back in search")
        }
    }

    @MainActor
    func testTurningSearchOffAfterDiscoveryStopsQueryingTheServer() async {
        await withIsolatedStores { defaults in
            let (vm, mock, prefs) = makeLocalMusicSearch(unsearchable: "none", defaults: defaults)
            vm.onQueryChanged("paris")
            await waitUntil { mock.calls.contains { $0.hasPrefix("search:-2:") } && !vm.isSearching }

            prefs.setSearchable(false, for: "NASPERES")
            mock.calls = []
            vm.onQueryChanged("rock")
            await waitUntil { mock.calls.contains { $0.hasPrefix("search:-1:") } && !vm.isSearching }

            XCTAssertEqual(mock.calls.filter { $0.hasPrefix("search:-2:") }, [])
        }
    }

    // MARK: - Searching every category at once

    @MainActor
    private func makeTidalSearch(_ mock: MockAudioService) -> SearchViewModel {
        let state = AppState()
        state.musicSources = [MusicSource(sid: 10, name: "Tidal", type: "music_service")]
        state.searchCriteria = [10: [SearchCriteria(scid: 1, name: "Artist"), SearchCriteria(scid: 3, name: "Track")]]
        return SearchViewModel(service: mock, state: state)
    }

    @MainActor
    func testAQuickCategoryShowsWhileASlowerOneIsStillSearching() async {
        await withIsolatedStores { _ in
            let mock = MockAudioService()
            mock.searchDelays = [1: .seconds(5)]
            let vm = makeTidalSearch(mock)

            vm.onQueryChanged("karma")
            await waitUntil { vm.serviceResults[ServiceCriteriaKey(sid: 10, scid: 3)] != nil }

            XCTAssertTrue(vm.isPending(ServiceCriteriaKey(sid: 10, scid: 1)))
            XCTAssertFalse(vm.isPending(ServiceCriteriaKey(sid: 10, scid: 3)))
            XCTAssertTrue(vm.loadingServiceSIDs.contains(10))
            vm.clearSearch()
        }
    }

    @MainActor
    func testAServiceStopsLoadingOnceEveryCategoryAnswered() async {
        await withIsolatedStores { _ in
            let mock = MockAudioService()
            let vm = makeTidalSearch(mock)

            vm.onQueryChanged("karma")
            await waitUntil { !vm.isSearching && mock.calls.count == 2 }

            XCTAssertTrue(vm.loadingServiceSIDs.isEmpty)
            XCTAssertNotNil(vm.serviceResults[ServiceCriteriaKey(sid: 10, scid: 1)])
            XCTAssertNotNil(vm.serviceResults[ServiceCriteriaKey(sid: 10, scid: 3)])
        }
    }

    @MainActor
    func testTypingDuringASearchKeepsTheResultsOnScreen() async {
        await withIsolatedStores { _ in
            let mock = MockAudioService()
            let vm = makeTidalSearch(mock)
            vm.onQueryChanged("radio")
            await waitUntil { !vm.isSearching && mock.calls.count == 2 }

            mock.searchDelays = [1: .seconds(5), 3: .seconds(5)]
            vm.onQueryChanged("radioh")
            await waitUntil { mock.calls.count == 4 }
            vm.onQueryChanged("radiohe")
            await waitUntil { mock.calls.count == 6 }

            XCTAssertEqual(vm.serviceResults.count, 2)
            vm.clearSearch()
        }
    }

    @MainActor
    func testRemovingAFilterMidSearchSearchesWhatStillShowsTheLastQuery() async {
        await withIsolatedStores { _ in
            let mock = MockAudioService()
            let state = AppState()
            state.musicSources = [
                MusicSource(sid: 10, name: "Tidal", type: "music_service"),
                MusicSource(sid: 13, name: "Qobuz", type: "music_service"),
            ]
            state.searchCriteria = [10: [SearchCriteria(scid: 1, name: "Artist")], 13: []]
            let vm = SearchViewModel(service: mock, state: state)
            vm.onQueryChanged("beatles")
            await waitUntil { !vm.isSearching && mock.calls.count == 1 }

            state.searchCriteria[13] = [SearchCriteria(scid: 2, name: "Artist")]
            mock.searchDelays = [1: .seconds(5), 2: .seconds(5)]
            vm.onQueryChanged("stones")
            await waitUntil { mock.calls.count == 3 }
            vm.selectServiceFilter(13)
            vm.selectServiceFilter(13)
            let tidalSearches = { mock.calls.filter { $0 == "search:10:stones:1" }.count }
            await waitUntil(timeout: 1) { tidalSearches() == 2 }

            XCTAssertEqual(tidalSearches(), 2)
            vm.clearSearch()
        }
    }

    @MainActor
    func testLocalServersAreAskedFirst() {
        let artist = [SearchCriteria(scid: 1, name: "Artist")]
        let state = AppState()
        state.musicSources = [MusicSource(sid: 10, name: "Tidal", type: "music_service")]
        state.searchCriteria = [10: artist, -1: artist]
        let vm = SearchViewModel(service: MockAudioService(), state: state)
        vm.registerSubSource(BrowseItem(name: "Kantele NAS", type: .heosServer, sid: -1), sid: -1)

        let order = vm.searchOrder([10: artist, -1: artist])

        XCTAssertEqual(order.map(\.sid), [-1, 10])
    }

    // MARK: - Recent searches

    @MainActor
    func testTypingDoesNotFillRecentSearches() async {
        await withIsolatedStores { _ in
            SearchHistoryStore.clearAll()
            let mock = MockAudioService()
            let vm = makeTidalSearch(mock)

            vm.onQueryChanged("radio")
            await waitUntil { !vm.isSearching && mock.calls.count == 2 }

            XCTAssertEqual(SearchHistoryStore.recentQueries(), [])
        }
    }

    @MainActor
    func testASubmittedQueryIsKept() {
        let vm = SearchViewModel(service: MockAudioService(), state: AppState())
        let saved = SearchHistoryStore.recentQueries()
        defer {
            SearchHistoryStore.clearAll()
            saved.reversed().forEach(SearchHistoryStore.addQuery)
        }
        SearchHistoryStore.clearAll()

        vm.query = "  radiohead "
        vm.commitQueryToHistory()

        XCTAssertEqual(vm.recentQueries, ["radiohead"])
    }

    @MainActor
    func testSearchingAgainMovesAPastQueryToTheTop() {
        let vm = SearchViewModel(service: MockAudioService(), state: AppState())
        let saved = SearchHistoryStore.recentQueries()
        defer {
            vm.clearSearch()
            SearchHistoryStore.clearAll()
            saved.reversed().forEach(SearchHistoryStore.addQuery)
        }
        SearchHistoryStore.clearAll()
        SearchHistoryStore.addQuery("portishead")
        SearchHistoryStore.addQuery("massive attack")

        vm.searchAgain("portishead")

        XCTAssertEqual(vm.recentQueries, ["portishead", "massive attack"])
    }
}
