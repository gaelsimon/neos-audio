import XCTest

/// The iPhone and iPad app in demo mode, along the paths a user takes first.
final class NeosMobileSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo-mode"]
        app.launch()
        XCTAssertTrue(tab("Home").waitForExistence(timeout: 30), "The tabs never appeared")
    }

    // MARK: - Helpers

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// The tab bar on iPhone; the iPad's floating tab bar exposes its tabs as plain buttons.
    private func tab(_ label: String) -> XCUIElement {
        let inBar = app.tabBars.buttons[label]
        return inBar.exists ? inBar : app.buttons[label].firstMatch
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func openPlayer() {
        if isPad {
            app.buttons["Full Screen Player"].firstMatch.tap()
        } else {
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'Playing on'")).firstMatch.tap()
        }
        XCTAssertTrue(app.buttons["Close Player"].waitForExistence(timeout: 5), "The player did not open")
    }

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
        tab("Library").tap()
        app.buttons["Queue"].firstMatch.tap()
        let firstRow = element(AccessibilityID.TrackList.row(1))
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        let removedTitle = firstRow.label

        firstRow.swipeLeft()
        app.buttons["Remove"].firstMatch.tap()

        XCTAssertNotEqual(element(AccessibilityID.TrackList.row(1)).label, removedTitle)
    }

    func testABreadcrumbGoesBackToItsPage() throws {
        try XCTSkipUnless(isPad, "Only the wide layout shows the path")
        tab("Library").tap()
        for label in ["Deezer", "Albums", "Midnight Opera,"] {
            let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), "No \(label) to open")
            row.tap()
        }
        let crumb = element(AccessibilityID.Browse.breadcrumbItem(0))
        XCTAssertTrue(crumb.waitForExistence(timeout: 5))

        crumb.tap()

        // One step back from the source's page is the library; a stacked copy of that page would need more.
        XCTAssertTrue(app.navigationBars["Deezer"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))
    }

    func testTheVolumeLimitSwitchHasAName() {
        app.buttons["Settings"].firstMatch.tap()
        let toggle = app.switches[AccessibilityID.Settings.volumeLimitToggle]

        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertTrue(toggle.label.contains("Volume Limit"), "VoiceOver would read \(toggle.label)")
    }
}
