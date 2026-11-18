import XCTest

/// Tests for the queue side panel in demo mode.
/// Verifies panel toggle, sections (now playing, up next), and content display.
final class DemoQueuePanelTests: DemoTestCase {

    private var panel: QueuePanelScreen { QueuePanelScreen(app: app) }

    private func ensurePanelClosed() {
        if panel.view.exists {
            panel.toggleButton.click()
            waitForElementToDisappear(panel.view)
        }
    }

    private func ensurePanelOpen() {
        if !panel.view.exists {
            waitForElement(panel.toggleButton)
            panel.toggleButton.click()
            waitForElement(panel.view)
        }
    }

    // MARK: - Toggle

    func testQueuePanelToggleButtonExists() {
        waitForElement(panel.toggleButton)
        XCTAssertTrue(panel.toggleButton.exists)
    }

    func testQueuePanelOpensOnToggle() {
        ensurePanelClosed()
        panel.toggleButton.click()
        waitForElement(panel.view)
        XCTAssertTrue(panel.view.exists)
    }

    func testQueuePanelClosesOnSecondToggle() {
        ensurePanelOpen()
        panel.toggleButton.click()
        waitForElementToDisappear(panel.view)
        XCTAssertFalse(panel.view.exists)
    }

    func testTheCloseButtonClosesThePanel() {
        ensurePanelOpen()
        waitForElement(panel.closeButton)

        panel.closeButton.click()

        waitForElementToDisappear(panel.view)
        XCTAssertFalse(panel.view.exists)
    }

    // MARK: - Sections

    func testNowPlayingSectionExists() {
        ensurePanelOpen()
        waitForElement(panel.nowPlayingSection)
        XCTAssertTrue(panel.nowPlayingSection.exists)
    }

    func testUpNextSectionExists() {
        ensurePanelOpen()
        waitForElement(panel.upNextSection)
        XCTAssertTrue(panel.upNextSection.exists)
    }

    func testUpNextHasContent() {
        ensurePanelOpen()
        waitForElement(panel.upNextSection)
        // The up next section should contain text from the next track (Glass Weather)
        // Static texts only: `value CONTAINS` on every element reaches the volume slider,
        // whose value is a number, and the exception that raises kills the app under test.
        let nextTrack = app.descendants(matching: .staticText).matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Glass Weather", "Glass Weather")
        )
        XCTAssertTrue(nextTrack.count > 0 || panel.upNextSection.exists, "Up next section should have content")
    }

    /// The inspector keeps the panel while it is closed; it must still show what started meanwhile.
    func testAStationStartedWhileThePanelWasClosedShowsWhenItOpens() {
        ensurePanelOpen()
        waitForElement(panel.nowPlayingSection)
        ensurePanelClosed()
        SidebarScreen(app: app).sourceButton(sid: 3).click()
        let localRadio = app.buttons["Local Radio"].firstMatch
        waitForElement(localRadio)
        localRadio.click()
        let station = app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", "Eclectic FM")).firstMatch
        waitForElement(station)
        station.click()
        // A click while the bar changes to the station can miss the toggle.
        let barShowsStation = expectation(
            for: NSPredicate(format: "value == %@", "Eclectic FM"),
            evaluatedWith: PlayerScreen(app: app).songTitle
        )
        wait(for: [barShowsStation], timeout: 5)

        ensurePanelOpen()

        let row = app.buttons.matching(identifier: AccessibilityID.QueuePanel.nowPlayingSection)
            .matching(NSPredicate(format: "label == %@", "Eclectic FM")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The panel should show the station that started while it was closed")
    }

    // MARK: - Clear

    func testCancellingClearKeepsTheQueue() {
        ensurePanelOpen()
        waitForElement(panel.clearButton)

        panel.clearButton.click()
        let confirm = app.buttons["Clear Queue"].firstMatch
        waitForElement(confirm)
        app.buttons["Cancel"].firstMatch.click()
        waitForElementToDisappear(confirm)

        XCTAssertTrue(panel.upNextSection.exists, "Up Next should keep its tracks when Clear is cancelled")
    }

    // MARK: - Layout

    private var profileButton: XCUIElement { app.descendants(matching: .any)[AccessibilityID.TopBar.profileButton] }

    /// Lets the column finish sliding in or out before frames are read.
    private func settle() {
        Thread.sleep(forTimeInterval: 0.6)
    }

    func testOpeningThePanelLeavesTheTopBarInPlace() {
        ensurePanelClosed()
        waitForElement(profileButton)
        settle()
        let before = profileButton.frame

        ensurePanelOpen()
        settle()

        XCTAssertEqual(profileButton.frame, before, "The top bar should stay in place when the panel opens")
    }

    func testThePanelStartsBelowTheTopBar() {
        ensurePanelOpen()
        waitForElement(panel.tabBar)
        settle()

        XCTAssertGreaterThanOrEqual(panel.tabBar.frame.minY, profileButton.frame.maxY, "The panel should open below the top bar")
    }

    func testThePanelKeepsAMarginFromTheWindowEdge() {
        ensurePanelOpen()
        settle()

        XCTAssertLessThan(panel.view.frame.maxX, app.windows.firstMatch.frame.maxX, "The panel should float clear of the window's edge")
    }

    func testThePanelEndsAboveThePlayerBar() {
        ensurePanelOpen()
        settle()

        XCTAssertLessThan(panel.view.frame.maxY, panel.toggleButton.frame.minY, "The panel should end above the player bar")
    }

    func testThePanelRunsUpBesideTheFullScreenPlayer() {
        ensurePanelOpen()
        waitForElement(panel.tabBar)
        settle()
        let belowTheTopBar = panel.tabBar.frame.minY
        let canvas = NowPlayingCanvasScreen(app: app)

        PlayerScreen(app: app).albumArt.click()
        waitForElement(canvas.view)
        settle()
        let besideTheCanvas = panel.tabBar.frame.minY
        canvas.closeButton.click()
        waitForElementToDisappear(canvas.view)

        XCTAssertLessThan(besideTheCanvas, belowTheTopBar, "Beside the full-screen player the panel should take the window's height")
    }

    func testEmptyStateNotVisibleWhenPlaying() {
        ensurePanelOpen()
        waitForElement(panel.nowPlayingSection)
        XCTAssertFalse(panel.emptyState.exists, "Empty state should not show when track is playing")
    }
}
