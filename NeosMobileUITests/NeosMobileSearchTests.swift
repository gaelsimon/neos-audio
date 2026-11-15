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
