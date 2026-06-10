import XCTest

/// Tests for search functionality in demo mode.
/// Verifies search field interaction, results display, and clear behavior.
final class DemoSearchTests: DemoTestCase {

    private var topBar: TopBarScreen { TopBarScreen(app: app) }
    private var search: SearchScreen { SearchScreen(app: app) }

    override func setUp() {
        super.setUp()
        resetToHome()
    }

    private func typeSearch(_ query: String) {
        waitForElement(topBar.searchField)
        topBar.searchField.click()
        topBar.searchField.typeText(query)
    }

    // MARK: - Search Field

    func testSearchFieldAcceptsInput() {
        typeSearch("Queen")
        // The field should contain the typed text
        let value = topBar.searchField.value as? String ?? ""
        XCTAssertTrue(value.contains("Queen"), "Search field should contain typed text, got: \(value)")
    }

    func testSearchResultsViewAppearsAfterTyping() {
        typeSearch("Queen")
        waitForElement(search.resultsView)
        XCTAssertTrue(search.resultsView.exists, "Search results should appear after typing")
    }

    func testClearButtonAppearsWhenSearching() {
        typeSearch("Queen")
        waitForElement(search.clearButton)
        XCTAssertTrue(search.clearButton.exists, "Clear button should appear when query is non-empty")
    }

    func testClearButtonDismissesSearch() {
        typeSearch("Queen")
        waitForElement(search.clearButton)
        search.clearButton.click()

        // After clearing, results should disappear and home should show
        let home = HomeScreen(app: app)
        waitForElement(home.view)
        XCTAssertTrue(home.view.exists, "Home should be visible after clearing search")
    }

    // MARK: - Search to Navigation Flow

    func testSearchThenNavigateBackShowsHome() {
        typeSearch("Queen")
        waitForElement(search.resultsView)

        // Press back to dismiss search
        let backButton = TopBarScreen(app: app).backButton
        waitForElement(backButton)
        backButton.click()

        let home = HomeScreen(app: app)
        waitForElement(home.view)
        XCTAssertTrue(home.view.exists, "Home should be visible after going back from search")
    }
}
