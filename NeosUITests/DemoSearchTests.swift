import XCTest

/// Search in demo mode. No test leaves Home, so none goes back to it first.
final class DemoSearchTests: DemoTestCase {

    private var topBar: TopBarScreen { TopBarScreen(app: app) }
    private var search: SearchScreen { SearchScreen(app: app) }

    /// Empties the field first: the previous test's query is still in it, and typing would add to it.
    private func typeSearch(_ query: String) {
        waitForElement(topBar.searchField)
        if search.clearButton.exists { search.clearButton.click() }
        topBar.searchField.click()
        topBar.searchField.typeText(query)
    }

    // MARK: - Search Field

    func testSearchFieldAcceptsInput() {
        typeSearch("The Velvet Hours")
        let value = topBar.searchField.value as? String ?? ""
        XCTAssertTrue(value.contains("The Velvet Hours"), "Search field should contain typed text, got: \(value)")
    }

    func testSearchResultsViewAppearsAfterTyping() {
        typeSearch("The Velvet Hours")
        waitForElement(search.resultsView)
        XCTAssertTrue(search.resultsView.exists, "Search results should appear after typing")
    }

    func testClearButtonAppearsWhenSearching() {
        typeSearch("The Velvet Hours")
        waitForElement(search.clearButton)
        XCTAssertTrue(search.clearButton.exists, "Clear button should appear when query is non-empty")
    }

    func testClearButtonDismissesSearch() {
        typeSearch("The Velvet Hours")
        waitForElement(search.clearButton)
        search.clearButton.click()

        let home = HomeScreen(app: app)
        waitForElement(home.view)
        XCTAssertTrue(home.view.exists, "Home should be visible after clearing search")
    }

    // MARK: - Search to Navigation Flow

    func testSearchThenNavigateBackShowsHome() {
        typeSearch("The Velvet Hours")
        waitForElement(search.resultsView)

        let backButton = TopBarScreen(app: app).backButton
        waitForElement(backButton)
        backButton.click()

        let home = HomeScreen(app: app)
        waitForElement(home.view)
        XCTAssertTrue(home.view.exists, "Home should be visible after going back from search")
    }
}
