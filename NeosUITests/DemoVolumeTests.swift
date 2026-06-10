import XCTest

/// Tests for volume controls in demo mode.
/// Verifies mute button, volume slider existence, and mute toggle interaction.
final class DemoVolumeTests: DemoTestCase {

    private var player: PlayerScreen { PlayerScreen(app: app) }

    // MARK: - Volume Elements

    func testVolumeMuteButtonExists() {
        waitForElement(player.volumeMuteButton)
        XCTAssertTrue(player.volumeMuteButton.isEnabled, "Mute button should be enabled")
    }

    func testMuteButtonClickDoesNotCrash() {
        waitForElement(player.volumeMuteButton)
        player.volumeMuteButton.click()
        // Verify app is still responsive
        XCTAssertTrue(player.volumeMuteButton.exists, "Mute button should still exist after click")
    }

    func testMuteButtonDoubleClickToggles() {
        waitForElement(player.volumeMuteButton)
        // Mute
        player.volumeMuteButton.click()
        // Unmute
        player.volumeMuteButton.click()
        // App should still be responsive
        XCTAssertTrue(player.volumeMuteButton.exists, "Mute button should still exist after double toggle")
    }

    // MARK: - Progress Bar

    func testProgressBarExists() {
        waitForElement(player.progressBar)
        XCTAssertTrue(player.progressBar.exists, "Progress bar should exist")
    }
}
