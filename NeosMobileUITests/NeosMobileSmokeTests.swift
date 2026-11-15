import XCTest

/// The iPhone and iPad app in demo mode, along the paths a user takes first.
final class NeosMobileSmokeTests: MobileDemoTestCase {

    // MARK: - Tests

    func testTheMiniPlayerOpensThePlayer() {
        openPlayer()
    }

    func testThePlayerOpensTheSpeakers() {
        openPlayer()
        let canvas = element(AccessibilityID.NowPlayingCanvas.view)
        canvas.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Playing on'")).firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Speakers"].waitForExistence(timeout: 5))
    }

    func testSwipingAQueueRowRemovesIt() {
        openLibraryPage("Queue")
        let firstRow = element(AccessibilityID.TrackList.row(1))
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        let removedTitle = firstRow.label

        firstRow.swipeLeft()
        app.buttons["Remove"].firstMatch.tap()

        XCTAssertNotEqual(element(AccessibilityID.TrackList.row(1)).label, removedTitle)
    }

    func testABreadcrumbGoesBackToItsPage() throws {
        try XCTSkipUnless(isPad, "Only the wide layout shows the path")
        // The group opens on its first service, which the demo makes Deezer.
        tab("Services").tap()
        for label in ["Albums", "Midnight Opera,"] {
            let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), "No \(label) to open")
            row.tap()
        }
        let crumb = element(AccessibilityID.Browse.breadcrumbItem(1))
        XCTAssertTrue(crumb.waitForExistence(timeout: 5))

        crumb.tap()

        // One step back from the albums is the service; a stacked copy of the albums would need more.
        XCTAssertTrue(app.navigationBars["Albums"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Deezer"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.navigationBars.buttons["Albums"].exists)
    }

    func testTheRootBreadcrumbEmptiesTheStack() throws {
        try XCTSkipUnless(isPad, "Only the wide layout shows the path")
        tab("Services").tap()
        for label in ["Albums", "Midnight Opera,"] {
            let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), "No \(label) to open")
            row.tap()
        }
        let crumb = element(AccessibilityID.Browse.breadcrumbItem(0))
        XCTAssertTrue(crumb.waitForExistence(timeout: 5))

        crumb.tap()

        let albums = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Albums'")).firstMatch
        XCTAssertTrue(albums.waitForExistence(timeout: 5), "The service's first page should be back")
        XCTAssertFalse(app.navigationBars.buttons["Albums"].exists, "Nothing should be left to go back to")
    }

    func testTheVolumeLimitSwitchHasAName() {
        app.buttons["Settings"].firstMatch.tap()
        let toggle = app.switches[AccessibilityID.Settings.volumeLimitToggle]

        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(toggle.label.contains("Volume Limit"), "VoiceOver would read \(toggle.label)")
    }
}
