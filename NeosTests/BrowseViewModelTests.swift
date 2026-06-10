import XCTest
@testable import Neos
import HEOSKit
import NeosDomain

final class BrowseViewModelTests: XCTestCase {
    @MainActor
    func testBrowseSourceIgnoresStaleResponseFromPreviousSelection() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let backend = MockBrowseBackend()

        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            getMusicSources: { [] },
            browseSource: { sid in
                try await backend.browseSource(sid: sid)
            },
            browseContainer: { sid, cid, range in
                try await backend.browseContainer(sid: sid, cid: cid, range: range)
            }
        )

        let sourceA = MusicSource(sid: 101, name: "Source A")
        let sourceB = MusicSource(sid: 202, name: "Source B")

        viewModel.selectSource(sourceA)
        viewModel.selectSource(sourceB)

        await waitUntil(timeoutSeconds: 1.0) {
            await backend.pendingSourceRequestCount() == 2
        }

        await backend.resumeBrowseSource(
            sid: 202,
            with: BrowseResult(items: [BrowseItem(name: "B track", cid: "b-cid", browsable: true)])
        )
        await yieldForTask()

        XCTAssertEqual(viewModel.items.map(\.name), ["B track"])
        XCTAssertEqual(viewModel.browseStack.last?.sid, 202)

        await backend.resumeBrowseSource(
            sid: 101,
            with: BrowseResult(items: [BrowseItem(name: "A track", cid: "a-cid", browsable: true)])
        )
        await yieldForTask()

        XCTAssertEqual(viewModel.items.map(\.name), ["B track"])
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    private func waitUntil(timeoutSeconds: TimeInterval, condition: @escaping () async -> Bool) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if await condition() {
                return
            }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition not met within timeout")
    }

    @MainActor
    func testGoBackPushesToForwardStack() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Track", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "Album", cid: "c1", browsable: true))
        await yieldForTask()

        XCTAssertEqual(viewModel.browseStack.count, 2)
        XCTAssertFalse(viewModel.canGoForward)

        viewModel.goBack()
        await yieldForTask()

        XCTAssertEqual(viewModel.browseStack.count, 1)
        XCTAssertTrue(viewModel.canGoForward)
    }

    @MainActor
    func testGoForwardRestoresBrowseStack() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Track", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "Album", cid: "c1", browsable: true))
        await yieldForTask()

        viewModel.goBack()
        await yieldForTask()

        XCTAssertTrue(viewModel.canGoForward)

        viewModel.goForward()
        await yieldForTask()

        XCTAssertEqual(viewModel.browseStack.count, 2)
        XCTAssertEqual(viewModel.browseStack.last?.name, "Album")
        XCTAssertFalse(viewModel.canGoForward)
    }

    @MainActor
    func testCanGoForwardReflectsStackState() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Track", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        XCTAssertFalse(viewModel.canGoForward)

        let source = MusicSource(sid: 1, name: "TIDAL")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "Album", cid: "c1", browsable: true))
        await yieldForTask()

        viewModel.goBack()
        await yieldForTask()

        XCTAssertTrue(viewModel.canGoForward)

        viewModel.goForward()
        await yieldForTask()

        XCTAssertFalse(viewModel.canGoForward)
    }

    @MainActor
    func testBrowseItemClearsForwardStack() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Track", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "Album", cid: "c1", browsable: true))
        await yieldForTask()

        viewModel.goBack()
        await yieldForTask()

        XCTAssertTrue(viewModel.canGoForward)

        viewModel.browseItem(BrowseItem(name: "Other Album", cid: "c2", browsable: true))
        await yieldForTask()

        XCTAssertFalse(viewModel.canGoForward)
    }

    @MainActor
    func testBrowseSourceClearsForwardStack() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Track", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "Album", cid: "c1", browsable: true))
        await yieldForTask()

        viewModel.goBack()
        await yieldForTask()

        XCTAssertTrue(viewModel.canGoForward)

        let source2 = MusicSource(sid: 2, name: "Spotify")
        viewModel.selectSource(source2)
        await yieldForTask()

        XCTAssertFalse(viewModel.canGoForward)
    }

    @MainActor
    func testNavigateToBreadcrumbClearsForwardStack() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Track", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: [BrowseItem(name: "Inner", cid: "c2", browsable: true)]) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "Album", cid: "c1", browsable: true))
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "SubFolder", cid: "c2", browsable: true))
        await yieldForTask()

        viewModel.goBack()
        await yieldForTask()

        XCTAssertTrue(viewModel.canGoForward)

        viewModel.navigateToBreadcrumb(at: 0)
        await yieldForTask()

        XCTAssertFalse(viewModel.canGoForward)
    }

    // MARK: - isSubSource Property Tests

    @MainActor
    func testIsSubSourceProperty() {
        // DLNA server with SID, no CID -> sub-source
        let nas = BrowseItem(name: "NAS", type: .dlnaServer, sid: 5555)
        XCTAssertTrue(nas.isSubSource)

        // HEOS server with SID, no CID -> sub-source
        let heosServer = BrowseItem(name: "Server", type: .heosServer, sid: 999)
        XCTAssertTrue(heosServer.isSubSource)

        // HEOS service with SID, no CID -> sub-source
        let heosService = BrowseItem(name: "Svc", type: .heosService, sid: 888)
        XCTAssertTrue(heosService.isSubSource)

        // Song with CID -> NOT sub-source
        let track = BrowseItem(name: "Track", type: .song, cid: "c1", playable: true)
        XCTAssertFalse(track.isSubSource)

        // Container with CID -> NOT sub-source
        let folder = BrowseItem(name: "Folder", type: .container, cid: "0$1", browsable: true)
        XCTAssertFalse(folder.isSubSource)

        // Music service type -> NOT sub-source (external services handled differently)
        let musicService = BrowseItem(name: "Spotify", type: .musicService, sid: 100)
        XCTAssertFalse(musicService.isSubSource)
    }

    // MARK: - browseSubSource Navigation Tests

    @MainActor
    func testBrowseSubSourcePushesTargetWithSubSourceSID() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        // Browse into parent source (Local Music, SID 1024)
        let source = MusicSource(sid: 1024, name: "Local Music")
        viewModel.selectSource(source)
        await yieldForTask()

        // Browse into sub-source (NAS, SID 5555)
        let subSource = BrowseItem(name: "Nasperes", type: .dlnaServer, sid: 5555)
        viewModel.browseSubSource(subSource)
        await yieldForTask()

        XCTAssertEqual(viewModel.browseStack.count, 2)
        XCTAssertEqual(viewModel.browseStack.last?.sid, 5555, "Sub-source target should use the sub-source's own SID")
        XCTAssertNil(viewModel.browseStack.last?.cid, "Sub-source target should have nil CID")
        XCTAssertEqual(viewModel.browseStack.last?.name, "Nasperes")
        XCTAssertEqual(viewModel.browseStack.first?.sid, 1024, "Root target should retain parent SID")
    }

    @MainActor
    func testBrowseSubSourceClearsForwardStack() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Track", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        // Build a forward stack: source -> item -> goBack
        let source = MusicSource(sid: 1024, name: "Local Music")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "Folder", cid: "c1", browsable: true))
        await yieldForTask()

        viewModel.goBack()
        await yieldForTask()

        XCTAssertTrue(viewModel.canGoForward, "Should have forward entry after goBack")

        // browseSubSource should clear forward stack
        let subSource = BrowseItem(name: "Nasperes", type: .dlnaServer, sid: 5555)
        viewModel.browseSubSource(subSource)
        await yieldForTask()

        XCTAssertFalse(viewModel.canGoForward, "browseSubSource should clear forward history")
    }

    @MainActor
    func testBackFromSubSourceReturnesToParentSID() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        // source(1024) -> subSource(5555) -> item(cid: "0$1")
        let source = MusicSource(sid: 1024, name: "Local Music")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.browseSubSource(BrowseItem(name: "Nasperes", type: .dlnaServer, sid: 5555))
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "Music", cid: "0$1", browsable: true))
        await yieldForTask()

        XCTAssertEqual(viewModel.browseStack.count, 3)

        // Go back from container -> should be at sub-source (SID 5555)
        viewModel.goBack()
        await yieldForTask()

        XCTAssertEqual(viewModel.browseStack.last?.sid, 5555, "After first goBack, should be at sub-source SID")
        XCTAssertEqual(viewModel.browseStack.count, 2)

        // Go back from sub-source -> should be at parent (SID 1024)
        viewModel.goBack()
        await yieldForTask()

        XCTAssertEqual(viewModel.browseStack.last?.sid, 1024, "After second goBack, should be at parent SID")
        XCTAssertEqual(viewModel.browseStack.count, 1)
    }

    // MARK: - Cross-Destination History Tests

    @MainActor
    func testCrossDestinationBackAndForward() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Track", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        // Home -> Spotify -> Album -> Queue
        let source = MusicSource(sid: 1, name: "Spotify")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "Album", cid: "c1", browsable: true))
        await yieldForTask()

        viewModel.selectQueue()

        XCTAssertEqual(viewModel.currentDestination, .queue)

        // Back -> should return to Album (browse with 2-item stack)
        viewModel.goBack()
        await yieldForTask()

        XCTAssertEqual(viewModel.browseStack.count, 2)
        XCTAssertEqual(viewModel.browseStack.last?.name, "Album")

        // Forward -> should return to Queue
        viewModel.goForward()

        XCTAssertEqual(viewModel.currentDestination, .queue)

        // Back -> Album, Back -> Spotify root, Back -> Home
        viewModel.goBack()
        await yieldForTask()

        XCTAssertEqual(viewModel.browseStack.last?.name, "Album")

        viewModel.goBack()
        await yieldForTask()

        XCTAssertEqual(viewModel.browseStack.count, 1)
        XCTAssertEqual(viewModel.browseStack.first?.name, "Spotify")

        viewModel.goBack()

        XCTAssertEqual(viewModel.currentDestination, .home)
        XCTAssertFalse(viewModel.canGoBack)
    }

    @MainActor
    func testHistoryTruncationOnNewNavigation() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Track", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        // Home -> Spotify -> Album
        let source = MusicSource(sid: 1, name: "Spotify")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.browseItem(BrowseItem(name: "Album", cid: "c1", browsable: true))
        await yieldForTask()

        // Go back twice: at Home
        viewModel.goBack()
        await yieldForTask()

        viewModel.goBack()

        XCTAssertEqual(viewModel.currentDestination, .home)
        XCTAssertTrue(viewModel.canGoForward)

        // Navigate to a new source; should truncate forward history
        let source2 = MusicSource(sid: 2, name: "TIDAL")
        viewModel.selectSource(source2)
        await yieldForTask()

        XCTAssertFalse(viewModel.canGoForward)
        XCTAssertTrue(viewModel.canGoBack)
    }

    @MainActor
    func testNavigateToHomeFromBrowse() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let viewModel = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        let source = MusicSource(sid: 1, name: "Spotify")
        viewModel.selectSource(source)
        await yieldForTask()

        viewModel.navigateToHome()

        XCTAssertEqual(viewModel.currentDestination, .home)
        XCTAssertTrue(viewModel.canGoBack)
        XCTAssertFalse(viewModel.canGoForward)

        // Back should go to Spotify
        viewModel.goBack()
        await yieldForTask()

        if case .browse(let target) = viewModel.currentDestination {
            XCTAssertEqual(target.sid, 1)
        } else {
            XCTFail("Expected browse destination")
        }
    }

    // MARK: - Content Loading Tests

    @MainActor
    func testLoadSourcesPopulatesMusicSources() async {
        let state = AppState()
        let mock = MockAudioService()
        let sources = [MusicSource(sid: 1, name: "Tidal"), MusicSource(sid: 2, name: "Spotify")]
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            getMusicSources: { sources }
        )

        vm.loadSources()
        await yieldForTask()

        XCTAssertEqual(state.musicSources.count, 2)
        XCTAssertEqual(state.musicSources[0].name, "Tidal")
        XCTAssertEqual(state.musicSources[1].name, "Spotify")
    }

    @MainActor
    func testLoadSourcesSetsIsLoading() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            getMusicSources: {
                try? await Task.sleep(for: .milliseconds(10))
                return [MusicSource(sid: 1, name: "Tidal")]
            }
        )

        vm.loadSources()

        XCTAssertTrue(vm.isLoading)

        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertFalse(vm.isLoading)
    }

    @MainActor
    func testRetryRefetchesCurrentBreadcrumb() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Folder", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: [BrowseItem(name: "Track", cid: "t1", playable: true)]) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        vm.selectSource(source)
        await yieldForTask()

        vm.browseItem(BrowseItem(name: "Folder", cid: "c1", browsable: true))
        await yieldForTask()

        XCTAssertEqual(vm.items.first?.name, "Track")

        vm.retry()
        await yieldForTask()

        XCTAssertEqual(vm.items.first?.name, "Track")
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor
    func testShouldLoadMoreReturnsTrueNearEnd() async {
        let state = AppState()
        let mock = MockAudioService()
        let items = (0..<20).map { BrowseItem(name: "Item\($0)", cid: "c\($0)", browsable: true) }
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Folder", cid: "f1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: items, count: 100) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        vm.selectSource(source)
        await yieldForTask()

        vm.browseItem(BrowseItem(name: "Folder", cid: "f1", browsable: true))
        await yieldForTask()

        XCTAssertEqual(vm.items.count, 20)
        XCTAssertTrue(vm.hasMore)
        XCTAssertTrue(vm.shouldLoadMore(at: 18))
    }

    @MainActor
    func testShouldLoadMoreReturnsFalseWhenNoMore() async {
        let state = AppState()
        let mock = MockAudioService()
        let items = (0..<5).map { BrowseItem(name: "Item\($0)", cid: "c\($0)", browsable: true) }
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "Folder", cid: "f1", browsable: true)]) },
            browseContainer: { _, _, _ in BrowseResult(items: items, count: 5) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        vm.selectSource(source)
        await yieldForTask()

        vm.browseItem(BrowseItem(name: "Folder", cid: "f1", browsable: true))
        await yieldForTask()

        XCTAssertFalse(vm.hasMore)
        XCTAssertFalse(vm.shouldLoadMore(at: 3))
    }

    // MARK: - Navigation Tests

    @MainActor
    func testNavigateToContainerPushesStackWithCID() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        vm.navigateToContainer(source: source, containerName: "My Album", cid: "album-123", mediaType: .album)
        await yieldForTask()

        XCTAssertEqual(vm.browseStack.count, 2)
        XCTAssertEqual(vm.browseStack[0].sid, 1)
        XCTAssertNil(vm.browseStack[0].cid)
        XCTAssertEqual(vm.browseStack[1].cid, "album-123")
        XCTAssertEqual(vm.browseStack[1].name, "My Album")
    }

    @MainActor
    func testNavigateToSettingsSetsDestination() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = BrowseViewModel(service: mock, state: state)

        vm.navigateToSettings()

        XCTAssertEqual(vm.currentDestination, .settings)
        XCTAssertTrue(vm.items.isEmpty)
    }

    @MainActor
    func testIsBrowsingReturnsTrueForCurrentSource() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        let source = MusicSource(sid: 42, name: "Spotify")
        vm.selectSource(source)
        await yieldForTask()

        XCTAssertTrue(vm.isBrowsing(sid: 42))
    }

    @MainActor
    func testIsBrowsingReturnsFalseForOtherSource() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        let source = MusicSource(sid: 42, name: "Spotify")
        vm.selectSource(source)
        await yieldForTask()

        XCTAssertFalse(vm.isBrowsing(sid: 99))
    }

    // MARK: - Computed Property Tests

    @MainActor
    func testSelectedSourceReturnsMatchingSource() async {
        let state = AppState()
        let mock = MockAudioService()
        state.musicSources = [MusicSource(sid: 1, name: "Tidal"), MusicSource(sid: 2, name: "Spotify")]
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        vm.selectSource(MusicSource(sid: 2, name: "Spotify"))
        await yieldForTask()

        XCTAssertEqual(vm.selectedSource?.sid, 2)
        XCTAssertEqual(vm.selectedSource?.name, "Spotify")
    }

    @MainActor
    func testSelectedSourceReturnsNilWhenNotBrowsing() {
        let state = AppState()
        let mock = MockAudioService()
        state.musicSources = [MusicSource(sid: 1, name: "Tidal")]
        let vm = BrowseViewModel(service: mock, state: state)

        XCTAssertNil(vm.selectedSource)
    }

    @MainActor
    func testCurrentLocationNameShowsSourceName() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        XCTAssertEqual(vm.currentLocationName, "Home")

        vm.selectSource(MusicSource(sid: 1, name: "TIDAL"))
        await yieldForTask()

        XCTAssertEqual(vm.currentLocationName, "TIDAL")
    }

    @MainActor
    func testHasMoreReflectsPaginationState() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        // At home, hasMore is false (not in container)
        XCTAssertFalse(vm.hasMore)

        // Browse into a source root (no CID); still false
        vm.selectSource(MusicSource(sid: 1, name: "TIDAL"))
        await yieldForTask()

        XCTAssertFalse(vm.hasMore)
    }

    // MARK: - Playback Tests

    @MainActor
    func testPlayItemSetsPlayingItemID() async {
        let state = AppState()
        let mock = MockAudioService()
        state.selectedPlayerID = 123
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        vm.selectSource(source)
        await yieldForTask()

        let item = BrowseItem(name: "Song", mid: "mid-1", playable: true)
        vm.playItem(item)

        // playingItemID is set synchronously before the async Task runs
        XCTAssertEqual(vm.playingItemID, item.id)

        await yieldForTask()

        // After async completes, playingItemID is cleared
        XCTAssertNil(vm.playingItemID)
    }

    @MainActor
    func testAddToQueueCallsService() async {
        let state = AppState()
        let mock = MockAudioService()
        state.selectedPlayerID = 123
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        let source = MusicSource(sid: 1, name: "TIDAL")
        vm.selectSource(source)
        await yieldForTask()

        let item = BrowseItem(name: "Song", cid: "c1", mid: "mid-1", playable: true)
        vm.addToQueue(item)
        await yieldForTask()

        XCTAssertTrue(mock.calls.contains("addToQueue:123"))
    }

    @MainActor
    func testPlayContainerRequiresPlayerSelected() async {
        let state = AppState()
        let mock = MockAudioService()
        state.selectedPlayerID = nil
        let vm = BrowseViewModel(service: mock, state: state)

        vm.playContainer()
        await yieldForTask()

        XCTAssertEqual(state.toast?.text, "No player selected")
        XCTAssertEqual(state.toast?.style, .error)
    }

    @MainActor
    func testAddContainerToQueueRequiresPlayerSelected() async {
        let state = AppState()
        let mock = MockAudioService()
        state.selectedPlayerID = nil
        let vm = BrowseViewModel(service: mock, state: state)

        vm.addContainerToQueue()
        await yieldForTask()

        XCTAssertEqual(state.toast?.text, "No player selected")
        XCTAssertEqual(state.toast?.style, .error)
    }

    // MARK: - Cross-Link Tests

    @MainActor
    func testPushAlbumCrossLinkPassesCIDAsIs() async {
        let state = AppState()
        let mock = MockAudioService()
        state.musicSources = [MusicSource(sid: 1, name: "TIDAL")]
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        vm.pushAlbumCrossLink(sid: 1, cid: "LIBALBUM-12345", albumName: "My Album")
        await yieldForTask()

        XCTAssertEqual(vm.browseStack.last?.cid, "LIBALBUM-12345")
        XCTAssertEqual(vm.browseStack.last?.name, "My Album")
    }

    @MainActor
    func testPushArtistCrossLinkPassesCIDAsIs() async {
        let state = AppState()
        let mock = MockAudioService()
        state.musicSources = [MusicSource(sid: 1, name: "TIDAL")]
        let vm = BrowseViewModel(
            service: mock,
            state: state,
            browseSource: { _ in BrowseResult(items: []) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        vm.pushArtistCrossLink(sid: 1, cid: "LIBARTIST-67890", artistName: "The Artist")
        await yieldForTask()

        XCTAssertEqual(vm.browseStack.last?.cid, "LIBARTIST-67890")
        XCTAssertEqual(vm.browseStack.last?.name, "The Artist")
    }

    // MARK: - Back-Navigation Cache Tests

    @MainActor
    func testGoBackRestoresCachedItems() async {
        let sourceItems = [BrowseItem(name: "Album1", cid: "c1", browsable: true)]
        let containerItems = [BrowseItem(name: "Track1"), BrowseItem(name: "Track2")]
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let vm = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: sourceItems) },
            browseContainer: { _, _, _ in BrowseResult(items: containerItems) }
        )

        // Navigate to source
        vm.selectSource(MusicSource(sid: 1, name: "TIDAL"))
        await yieldForTask()
        XCTAssertEqual(vm.items.count, 1)

        // Drill into container
        vm.browseItem(BrowseItem(name: "Album1", cid: "c1", browsable: true))
        await yieldForTask()
        XCTAssertEqual(vm.items.count, 2)

        // Go back; should instantly restore source items from cache
        vm.goBack()
        XCTAssertEqual(vm.items.map(\.name), ["Album1"])
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor
    func testGoForwardRestoresCachedItems() async {
        let sourceItems = [BrowseItem(name: "Album1", cid: "c1", browsable: true)]
        let containerItems = [BrowseItem(name: "Track1"), BrowseItem(name: "Track2")]
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let vm = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: sourceItems) },
            browseContainer: { _, _, _ in BrowseResult(items: containerItems) }
        )

        vm.selectSource(MusicSource(sid: 1, name: "TIDAL"))
        await yieldForTask()

        vm.browseItem(BrowseItem(name: "Album1", cid: "c1", browsable: true))
        await yieldForTask()

        // Back then forward; forward should also use cache
        vm.goBack()
        vm.goForward()
        XCTAssertEqual(vm.items.map(\.name), ["Track1", "Track2"])
        XCTAssertFalse(vm.isLoading)
    }

    @MainActor
    func testDrillDownAlwaysFetchesFresh() async {
        var fetchCount = 0
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let vm = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "A", cid: "c1", browsable: true)]) },
            browseContainer: { _, _, _ in
                fetchCount += 1
                return BrowseResult(items: [BrowseItem(name: "T\(fetchCount)")])
            }
        )

        vm.selectSource(MusicSource(sid: 1, name: "TIDAL"))
        await yieldForTask()

        vm.browseItem(BrowseItem(name: "A", cid: "c1", browsable: true))
        await yieldForTask()
        XCTAssertEqual(fetchCount, 1)

        // Go back then drill down again; should fetch fresh, not use cache
        vm.goBack()
        vm.browseItem(BrowseItem(name: "A", cid: "c1", browsable: true))
        await yieldForTask()
        XCTAssertEqual(fetchCount, 2)
    }

    @MainActor
    func testBackFromNonBrowseDoesNotCrash() async {
        let state = AppState()
        let service = HEOSService(stateUpdater: state)
        let vm = BrowseViewModel(
            service: service,
            state: state,
            browseSource: { _ in BrowseResult(items: [BrowseItem(name: "A")]) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )

        vm.selectSource(MusicSource(sid: 1, name: "TIDAL"))
        await yieldForTask()

        vm.navigateToSettings()
        vm.goBack()

        // Should restore cached source items
        XCTAssertEqual(vm.items.map(\.name), ["A"])
    }
}

private actor MockBrowseBackend {
    private var sourceContinuations: [Int: CheckedContinuation<BrowseResult, Error>] = [:]

    func browseSource(sid: Int) async throws -> BrowseResult {
        try await withCheckedThrowingContinuation { continuation in
            sourceContinuations[sid] = continuation
        }
    }

    func browseContainer(sid: Int, cid: String, range: ClosedRange<Int>?) async throws -> BrowseResult {
        _ = sid
        _ = cid
        _ = range
        return BrowseResult(items: [])
    }

    func pendingSourceRequestCount() -> Int {
        sourceContinuations.count
    }

    func resumeBrowseSource(sid: Int, with result: BrowseResult) {
        guard let continuation = sourceContinuations.removeValue(forKey: sid) else {
            return
        }
        continuation.resume(returning: result)
    }
}
