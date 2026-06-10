import XCTest

/// Tests for player controls in demo mode.
/// Verifies that the connected UI shows correct now-playing info,
/// player controls are present and interactive, and volume/quality display.
final class DemoPlayerTests: DemoTestCase {

    // MARK: - Now Playing Info

    func testSongTitleDisplaysBohemianRhapsody() {
        let player = PlayerScreen(app: app)
        waitForElement(player.songTitle)
        XCTAssertEqual(player.songTitle.value as? String, "Bohemian Rhapsody")
    }

    func testArtistNameExists() {
        let player = PlayerScreen(app: app)
        waitForElement(player.artistName)
        XCTAssertTrue(player.artistName.exists)
    }

    func testAlbumArtExists() {
        let player = PlayerScreen(app: app)
        waitForElement(player.albumArt)
        XCTAssertTrue(player.albumArt.exists)
    }

    func testQualityBadgeShowsFLAC() {
        let player = PlayerScreen(app: app)
        waitForElement(player.qualityBadge)
        let text = player.qualityBadge.value as? String ?? player.qualityBadge.label
        XCTAssertTrue(text.contains("FLAC"), "Quality badge should mention FLAC, got: \(text)")
    }

    // MARK: - Transport Controls

    func testPlayPauseButtonExists() {
        let player = PlayerScreen(app: app)
        waitForElement(player.playPauseButton)
        XCTAssertTrue(player.playPauseButton.isEnabled)
    }

    func testPreviousButtonExists() {
        let player = PlayerScreen(app: app)
        waitForElement(player.previousButton)
        XCTAssertTrue(player.previousButton.isEnabled)
    }

    func testNextButtonExists() {
        let player = PlayerScreen(app: app)
        waitForElement(player.nextButton)
        XCTAssertTrue(player.nextButton.isEnabled)
    }

    func testShuffleButtonExists() {
        let player = PlayerScreen(app: app)
        waitForElement(player.shuffleButton)
        XCTAssertTrue(player.shuffleButton.exists)
    }

    func testRepeatButtonExists() {
        let player = PlayerScreen(app: app)
        waitForElement(player.repeatButton)
        XCTAssertTrue(player.repeatButton.exists)
    }

    func testPlayPauseButtonIsClickable() {
        let player = PlayerScreen(app: app)
        waitForElement(player.playPauseButton)
        // Should not crash or cause error in demo mode
        player.playPauseButton.click()
    }

    // MARK: - Volume

    func testVolumeMuteButtonExists() {
        let player = PlayerScreen(app: app)
        waitForElement(player.volumeMuteButton)
        XCTAssertTrue(player.volumeMuteButton.isEnabled)
    }
}
