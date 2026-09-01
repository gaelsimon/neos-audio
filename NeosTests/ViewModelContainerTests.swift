import XCTest
@testable import Neos
import NeosDomain

/// Covers the navigation commands shared by the top bar arrows and the menu bar shortcuts.
final class ViewModelContainerTests: XCTestCase {

    @MainActor
    private func makeContainer() -> (ViewModelContainer, AppState) {
        let state = AppState()
        return (ViewModelContainer(service: MockAudioService(), state: state), state)
    }

    @MainActor
    private func activateSearchWithResults(_ container: ViewModelContainer) {
        container.searchVM.serviceResults = [ServiceCriteriaKey(sid: 1, scid: 1): [BrowseItem(name: "Song")]]
        container.searchVM.activateOverlay()
    }

    // MARK: - Search Suspension Round-Trips

    @MainActor
    func testSuspendedSearchDoesNotResurrectOnARewrittenBranch() {
        let (container, _) = makeContainer()
        let tidal = MusicSource(sid: 1, name: "TIDAL")
        activateSearchWithResults(container)

        // Suspend, then walk back past the entry the search belongs to.
        container.browseVM.navigateToContainer(source: tidal, containerName: "Album", cid: "abc")
        container.browseVM.goBack()

        // Navigating from here truncates the forward history the search was pinned to.
        container.browseVM.navigateToSettings()
        container.browseVM.navigateToAmpSettings()
        container.goBack()

        XCTAssertFalse(container.searchVM.isOverlayVisible)
        XCTAssertEqual(container.browseVM.currentDestination, .settings)
    }

    @MainActor
    func testGoBackRestoresSearchAfterBrowsing() {
        let (container, _) = makeContainer()
        activateSearchWithResults(container)

        container.browseVM.navigateToContainer(source: MusicSource(sid: 1, name: "TIDAL"), containerName: "Album", cid: "abc")
        XCTAssertTrue(container.searchVM.hasSuspendedSearch)

        container.goBack()

        XCTAssertTrue(container.searchVM.isOverlayVisible)
    }

    /// Settings did not report a navigation, so back closed the search instead of restoring it.
    @MainActor
    func testGoBackRestoresSearchAfterSettings() {
        let (container, _) = makeContainer()
        activateSearchWithResults(container)

        container.browseVM.navigateToSettings()

        container.goBack()

        XCTAssertTrue(container.searchVM.isOverlayVisible)
        XCTAssertEqual(container.browseVM.currentDestination, .home)
    }

    /// The settings and amp buttons toggle: they call the view model straight, not goBack on
    /// the container, and used to close the search before navigating.
    @MainActor
    func testSearchComesBackWhenAToggleNavigatesBack() {
        let (container, _) = makeContainer()
        activateSearchWithResults(container)

        container.browseVM.navigateToAmpSettings()
        XCTAssertTrue(container.searchVM.hasSuspendedSearch)

        // Pressing the same button again goes back through the view model directly.
        container.browseVM.goBack()

        XCTAssertTrue(container.searchVM.isOverlayVisible)
    }

    @MainActor
    func testSwitchingBetweenSettingsAndAmpKeepsTheSearch() {
        let (container, _) = makeContainer()
        activateSearchWithResults(container)

        container.browseVM.navigateToSettings()
        // The amp button leaves settings and goes there instead.
        container.browseVM.goBack()
        container.browseVM.navigateToAmpSettings()
        container.browseVM.goBack()

        XCTAssertTrue(container.searchVM.isOverlayVisible)
    }

    @MainActor
    func testGoBackRestoresSearchAfterTheQueue() {
        let (container, _) = makeContainer()
        activateSearchWithResults(container)

        container.browseVM.selectQueue()

        container.goBack()

        XCTAssertTrue(container.searchVM.isOverlayVisible)
    }

    @MainActor
    func testGoBackWithActiveOverlayOnlyDismissesIt() {
        let (container, _) = makeContainer()
        container.browseVM.navigateToSettings()
        activateSearchWithResults(container)
        let token = container.browseVM.currentHistoryToken

        container.goBack()

        XCTAssertFalse(container.searchVM.isOverlayVisible)
        XCTAssertEqual(container.browseVM.currentHistoryToken, token)
    }

    @MainActor
    func testGoForwardResuspendsRestoredSearch() {
        let (container, _) = makeContainer()
        activateSearchWithResults(container)
        container.browseVM.navigateToContainer(source: MusicSource(sid: 1, name: "TIDAL"), containerName: "Album", cid: "abc")
        container.goBack()
        XCTAssertTrue(container.searchVM.isOverlayVisible)

        container.goForward()
        XCTAssertFalse(container.searchVM.isOverlayVisible)

        container.goBack()
        XCTAssertTrue(container.searchVM.isOverlayVisible)
    }

    @MainActor
    func testCanGoBackIsFalseAtRoot() {
        let (container, _) = makeContainer()

        XCTAssertFalse(container.canGoBack)
        XCTAssertFalse(container.canGoForward)
    }

    @MainActor
    func testGoBackReturnsToPreviousDestination() {
        let (container, _) = makeContainer()
        container.browseVM.navigateToSettings()

        XCTAssertTrue(container.canGoBack)
        container.goBack()

        XCTAssertEqual(container.browseVM.currentDestination, .home)
        XCTAssertTrue(container.canGoForward)
    }

    @MainActor
    func testGoForwardReturnsToNextDestination() {
        let (container, _) = makeContainer()
        container.browseVM.navigateToSettings()
        container.goBack()

        container.goForward()

        XCTAssertEqual(container.browseVM.currentDestination, .settings)
    }

    @MainActor
    func testGoBackDismissesSearchOverlayBeforeNavigating() {
        let (container, _) = makeContainer()
        container.browseVM.navigateToSettings()
        container.searchVM.activateOverlay()

        container.goBack()

        XCTAssertFalse(container.searchVM.isOverlayVisible)
        XCTAssertEqual(container.browseVM.currentDestination, .settings)
    }

    @MainActor
    func testGoForwardSuspendsVisibleSearchOverlay() {
        let (container, _) = makeContainer()
        container.browseVM.navigateToSettings()
        container.goBack()
        container.searchVM.activateOverlay()

        container.goForward()

        XCTAssertTrue(container.searchVM.hasSuspendedSearch)
        XCTAssertEqual(container.browseVM.currentDestination, .settings)
    }
}
