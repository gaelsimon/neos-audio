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

    // MARK: - What a search found

    func testASearchNobodyAnswersSaysSo() {
        typeSearch("zzz")
        waitForElement(search.resultsView)

        let nothing = app.staticTexts
            .matching(NSPredicate(format: "value BEGINSWITH 'No Results' OR label BEGINSWITH 'No Results'")).firstMatch
        XCTAssertTrue(nothing.waitForExistence(timeout: 5), "The page should say nothing was found")
    }

    func testAServiceThatFoundNothingIsLeftOut() {
        let deezer = app.descendants(matching: .any).matching(identifier: AccessibilityID.Search.serviceHeader(2)).firstMatch
        let tuneIn = app.descendants(matching: .any).matching(identifier: AccessibilityID.Search.serviceHeader(3)).firstMatch

        typeSearch("radio")

        XCTAssertTrue(tuneIn.waitForExistence(timeout: 5), "TuneIn answered")
        XCTAssertFalse(deezer.exists, "Deezer found nothing and should not show an empty section")
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
