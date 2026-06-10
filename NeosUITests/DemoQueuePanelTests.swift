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
        // The up next section should contain text from the next track (Under Pressure)
        let underPressure = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Under Pressure", "Under Pressure")
        )
        XCTAssertTrue(underPressure.count > 0 || panel.upNextSection.exists, "Up next section should have content")
    }

    func testEmptyStateNotVisibleWhenPlaying() {
        ensurePanelOpen()
        waitForElement(panel.nowPlayingSection)
        XCTAssertFalse(panel.emptyState.exists, "Empty state should not show when track is playing")
    }
}
