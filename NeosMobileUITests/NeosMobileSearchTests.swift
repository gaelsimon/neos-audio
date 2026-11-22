import XCTest

/// Searching from the iPhone and iPad app, against the demo's services.
final class NeosMobileSearchTests: MobileDemoTestCase {
    private let deezer = 2
    private let tuneIn = 3

    private func header(_ sid: Int) -> XCUIElement {
        element(AccessibilityID.Search.serviceHeader(sid))
    }

    func testASearchShowsWhatEachServiceFound() {
        search("mi")

        XCTAssertTrue(header(deezer).waitForExistence(timeout: 5), "Deezer answered")
        XCTAssertTrue(header(tuneIn).exists, "TuneIn answered")
        XCTAssertNotNil(item(startingWith: "Paper Hearts"), "A track should be listed")
    }

    func testAServiceThatFoundNothingIsLeftOut() {
        search("radio")

        XCTAssertTrue(header(tuneIn).waitForExistence(timeout: 5), "TuneIn answered")
        XCTAssertFalse(header(deezer).exists, "Deezer found nothing and should not show an empty section")
    }

    func testASearchNobodyAnswersSaysSo() {
        search("zzz")

        let nothing = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'No Results'")).firstMatch
        XCTAssertTrue(nothing.waitForExistence(timeout: 5), "The page should say nothing was found")
        XCTAssertFalse(header(deezer).exists)
        XCTAssertFalse(header(tuneIn).exists)
    }

    func testATrackFoundPlays() {
        search("mi")

        open("Paper Hearts")

        XCTAssertTrue(waitUntil { nowPlaying.hasPrefix("Paper Hearts") }, "Playing \(nowPlaying)")
    }

    func testScrollingTheResultsPutsTheKeyboardAway() {
        tab("Search").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No search field")
        field.tap()
        field.typeText("mi")
        XCTAssertTrue(element(AccessibilityID.Search.resultsView).waitForExistence(timeout: 5), "The search never answered")
        XCTAssertTrue(app.keyboards.firstMatch.exists, "The keyboard should be up while typing")

        let results = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        results.press(forDuration: 0.1, thenDragTo: results.withOffset(CGVector(dx: 0, dy: -150)), withVelocity: .default, thenHoldForDuration: 0.2)

        XCTAssertTrue(waitUntil { !app.keyboards.firstMatch.exists }, "Scrolling the results should put the keyboard away")
    }

    func testOnlyASubmittedSearchIsRemembered() {
        tab("Search").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No search field")
        field.tap()
        let clearText = app.buttons["Clear text"].firstMatch
        if clearText.exists { clearText.tap() }
        let clearRecents = app.buttons["Clear Recent Searches"].firstMatch
        if clearRecents.exists { clearRecents.tap() }
        // iPadOS ends the search on the clear button, there being no Cancel, so typing again starts with a tap.
        if isPad { field.tap() }

        field.typeText("pap")
        XCTAssertTrue(element(AccessibilityID.Search.resultsView).waitForExistence(timeout: 5), "The search never answered")
        clearText.tap()
        XCTAssertFalse(app.buttons["pap"].waitForExistence(timeout: 1), "Typing alone should not be remembered")

        if isPad { field.tap() }
        field.typeText("paper\n")
        XCTAssertTrue(element(AccessibilityID.Search.resultsView).waitForExistence(timeout: 5), "The search never answered")
        clearText.tap()
        XCTAssertTrue(app.buttons["paper"].waitForExistence(timeout: 5), "A submitted search should be remembered")
    }

    func testTheTabsAreInReachOfTheResults() {
        search("mi")
        if isPad, #available(iOS 26, *) {
            XCTAssertTrue(tab("Home").exists, "The iPad draws its tabs where a search would hide them")
        }

        leaveSearch()

        XCTAssertTrue(tab("Home").waitForExistence(timeout: 5), "No way back to the tabs")
        tab("Home").tap()
        XCTAssertTrue(element(AccessibilityID.Home.view).waitForExistence(timeout: 5))
    }
}
