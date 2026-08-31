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
