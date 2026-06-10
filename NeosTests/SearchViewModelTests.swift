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
        vm.selectedServiceFilter = 1

        vm.clearSearch()

        XCTAssertEqual(vm.query, "")
        XCTAssertEqual(vm.overlayPhase, .inactive)
        XCTAssertFalse(vm.isOverlayVisible)
        XCTAssertFalse(vm.hasSuspendedSearch)
        XCTAssertFalse(vm.isSearching)
        XCTAssertTrue(vm.serviceResults.isEmpty)
        XCTAssertTrue(vm.expandedCategories.isEmpty)
        XCTAssertNil(vm.selectedCategoryFilter)
        XCTAssertNil(vm.selectedServiceFilter)
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
        vm.suspendForNavigation(originHistoryIndex: 3)

        XCTAssertEqual(vm.overlayPhase, .suspended(originHistoryIndex: 3))
        XCTAssertFalse(vm.isOverlayVisible)
        XCTAssertTrue(vm.hasSuspendedSearch)
    }

    @MainActor
    func testSuspendForNavigationIgnoredWhenNotActive() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.overlayPhase = .inactive
        vm.suspendForNavigation(originHistoryIndex: 3)

        XCTAssertEqual(vm.overlayPhase, .inactive)
    }

    @MainActor
    func testTryRestoreSucceedsAtCorrectIndex() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.serviceResults = [ServiceCriteriaKey(sid: 1, scid: 1): [BrowseItem(name: "Song")]]
        vm.overlayPhase = .suspended(originHistoryIndex: 2)

        let restored = vm.tryRestore(atHistoryIndex: 2)

        XCTAssertTrue(restored)
        XCTAssertEqual(vm.overlayPhase, .active)
        XCTAssertTrue(vm.isOverlayVisible)
    }

    @MainActor
    func testTryRestoreFailsAtWrongIndex() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.serviceResults = [ServiceCriteriaKey(sid: 1, scid: 1): [BrowseItem(name: "Song")]]
        vm.overlayPhase = .suspended(originHistoryIndex: 2)

        let restored = vm.tryRestore(atHistoryIndex: 5)

        XCTAssertFalse(restored)
        XCTAssertEqual(vm.overlayPhase, .suspended(originHistoryIndex: 2))
    }

    @MainActor
    func testTryRestoreFailsWithEmptyResults() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.serviceResults = [:]
        vm.overlayPhase = .suspended(originHistoryIndex: 2)

        let restored = vm.tryRestore(atHistoryIndex: 2)

        XCTAssertFalse(restored)
        XCTAssertFalse(vm.isOverlayVisible)
    }

    @MainActor
    func testDismissOverlayClearsSuspension() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.overlayPhase = .suspended(originHistoryIndex: 2)

        vm.dismissOverlay()

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

        XCTAssertEqual(vm.selectedServiceFilter, 3)
    }

    @MainActor
    func testSelectServiceFilterTogglesOff() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.selectServiceFilter(3)
        vm.selectServiceFilter(3)

        XCTAssertNil(vm.selectedServiceFilter)
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

        vm.serviceResults = [
            ServiceCriteriaKey(sid: 5, scid: 1): [BrowseItem(name: "A")],
            ServiceCriteriaKey(sid: 10, scid: 1): [BrowseItem(name: "B")],
        ]
        vm.selectedServiceFilter = 5

        XCTAssertEqual(vm.filteredServiceSIDs, [5])
    }

    @MainActor
    func testFilteredServiceSIDsEmptyWhenSelectedNotPresent() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = SearchViewModel(service: mock, state: state)

        vm.serviceResults = [
            ServiceCriteriaKey(sid: 5, scid: 1): [BrowseItem(name: "A")],
        ]
        vm.selectedServiceFilter = 99

        XCTAssertTrue(vm.filteredServiceSIDs.isEmpty)
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
}
