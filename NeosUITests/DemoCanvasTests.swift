import XCTest

/// Tests for the full-screen Now Playing Canvas in demo mode.
/// Tests are ordered so the canvas opens once and stays open for content checks,
/// then close/reopen tests come last.
final class DemoCanvasTests: DemoTestCase {

    private var player: PlayerScreen { PlayerScreen(app: app) }
    private var canvas: NowPlayingCanvasScreen { NowPlayingCanvasScreen(app: app) }
    private var queuePanel: QueuePanelScreen { QueuePanelScreen(app: app) }

    /// Ensure canvas is open, opening it if needed.
    private func ensureCanvasOpen() {
        if canvas.view.exists { return }
        waitForElement(player.albumArt)
        player.albumArt.click()
        waitForElement(canvas.view)
    }

    // Tests run alphabetically. We prefix with numbers to control order:
    // 1. Open canvas via album art
    // 2. Check artwork (canvas still open)
    // 3. Check artist name (canvas still open)
    // 4. Queue panel on canvas
    // 5. Close canvas via close button

    func test1_albumArtClickOpensCanvas() {
        // Start from home, canvas closed
        resetToHome()
        waitForElement(player.albumArt)
        player.albumArt.click()
        waitForElement(canvas.view)
        XCTAssertTrue(canvas.view.exists, "Canvas should open when album art is clicked")
    }

    func test2_canvasArtworkExists() {
        ensureCanvasOpen()
        waitForElement(canvas.artwork)
        XCTAssertTrue(canvas.artwork.exists, "Canvas artwork should exist")
    }

    func test3_canvasArtistNameExists() {
        ensureCanvasOpen()
        waitForElement(canvas.artistName)
        XCTAssertTrue(canvas.artistName.exists, "Canvas artist name should exist")
    }

    func test4_queuePanelWorksOnCanvas() {
        ensureCanvasOpen()

        // Open queue panel while canvas is open
        waitForElement(queuePanel.toggleButton)
        queuePanel.toggleButton.click()
        waitForElement(queuePanel.view)
        XCTAssertTrue(queuePanel.view.exists, "Queue panel should open over canvas")

        // Verify sections
        waitForElement(queuePanel.nowPlayingSection)
        XCTAssertTrue(queuePanel.nowPlayingSection.exists, "Now playing section should exist in canvas queue panel")

        // Close queue panel to not block close button for next test
        queuePanel.toggleButton.click()
        waitForElementToDisappear(queuePanel.view)
    }

    func test5_canvasCloseButtonDismissesCanvas() {
        ensureCanvasOpen()
        let close = canvas.closeButton
        waitForElement(close)
        close.click()
        waitForElementToDisappear(canvas.view)
        XCTAssertFalse(canvas.view.exists, "Canvas should close when close button is clicked")
    }
}
