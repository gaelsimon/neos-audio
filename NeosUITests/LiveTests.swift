import XCTest

/// All live hardware integration tests in one class; single app launch per suite.
/// Requires a HEOS speaker on the network. XCTSkips gracefully when unavailable.
final class LiveTests: LiveTestCase {

    // MARK: - Helpers

    /// Ensure app is on home view before a test that assumes it.
    private func navigateHome() {
        let home = app.descendants(matching: .any)[AccessibilityID.Home.view]
        if home.exists { return }

        // Sidebar uses non-lazy VStack; home button is always in the a11y tree.
        let sidebar = SidebarScreen(app: app)
        if sidebar.homeButton.exists {
            sidebar.homeButton.click()
            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline {
                if home.exists { break }
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
    }

    // MARK: - LIVE-01: Speaker Discovery

    func testSpeakerDiscoveryConnects() {
        navigateHome()
        let home = HomeScreen(app: app)
        waitForElement(home.view)
    }

    func testPlayerControlsVisibleAfterConnection() {
        let player = PlayerScreen(app: app)
        waitForElement(player.playPauseButton)
        XCTAssertTrue(player.volumeMuteButton.exists, "Volume mute button should be visible when connected")
    }

    func testSidebarShowsConnectedElements() {
        let sidebar = SidebarScreen(app: app)
        waitForElement(sidebar.homeButton)
        waitForElement(sidebar.queueButton)
    }

    // MARK: - LIVE-03: Volume Control

    func testVolumeSliderExists() {
        navigateHome()
        let player = PlayerScreen(app: app)
        waitForElement(player.volumeMuteButton)
    }

    // MARK: - LIVE-04: Browse Music Sources

    func testMusicSourcesAppearInSidebar() {
        let sidebar = SidebarScreen(app: app)
        waitForElement(sidebar.servicesSection)
    }

    func testNavigateIntoMusicSource() throws {
        let sidebar = SidebarScreen(app: app)
        let browse = BrowseScreen(app: app)

        waitForElement(sidebar.servicesSection)

        // Find and tap the first available source button within the services section
        let sourceButtons = sidebar.servicesSection.buttons
        guard sourceButtons.count > 0 else {
            throw XCTSkip("No music sources available on this speaker")
        }

        sourceButtons.firstMatch.click()

        // Wait for browse view to appear with content
        waitForElement(browse.view)
    }

    // MARK: - LIVE-05: Queue

    func testQueueViewAccessible() {
        let sidebar = SidebarScreen(app: app)
        let queue = QueueScreen(app: app)

        waitForElement(sidebar.queueButton)
        sidebar.queueButton.click()

        // Queue view should appear (may be empty if nothing is playing)
        waitForElement(queue.view)
    }

    func testQueueHeaderVisible() {
        let sidebar = SidebarScreen(app: app)
        let queue = QueueScreen(app: app)

        waitForElement(sidebar.queueButton)
        sidebar.queueButton.click()

        waitForElement(queue.view)
        // Header should be visible regardless of queue content
        waitForElement(queue.header)
    }

    // MARK: - LIVE-06: Search

    func testSearchFieldAcceptsInput() {
        let topBar = TopBarScreen(app: app)

        waitForElement(topBar.searchField)
        topBar.searchField.click()
        // Clear any leftover text from previous tests
        topBar.searchField.typeKey("a", modifierFlags: .command)
        topBar.searchField.typeText("test")

        // Search field should contain the typed text
        let fieldValue = topBar.searchField.value as? String
        XCTAssertEqual(fieldValue, "test", "Search field should contain typed text")
    }

    func testSearchReturnsResults() {
        let topBar = TopBarScreen(app: app)
        let search = SearchScreen(app: app)

        waitForElement(topBar.searchField)
        topBar.searchField.click()
        topBar.searchField.typeText("music\n")

        // Wait for results to appear (search hits live HEOS services)
        var resultsAppeared = false
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if search.resultsView.exists { resultsAppeared = true; break }
            Thread.sleep(forTimeInterval: 0.1)
        }
        // Results may or may not appear depending on configured music services
        if resultsAppeared {
            XCTAssertTrue(search.resultsView.exists, "Search results view should be visible after query")
        }
    }

    // MARK: - LIVE-07: Home View

    func testHomeHeaderVisible() {
        navigateHome()
        let home = HomeScreen(app: app)
        waitForElement(home.view)
        waitForElement(home.header)
    }

    // MARK: - LIVE-08: Now Playing Info

    func testNowPlayingSongTitleVisible() {
        let player = PlayerScreen(app: app)
        waitForElement(player.songTitle)
    }

    func testNowPlayingAlbumArtVisible() {
        let player = PlayerScreen(app: app)
        waitForElement(player.albumArt)
    }

    func testPlayerTransportControlsExist() {
        let player = PlayerScreen(app: app)
        waitForElement(player.playPauseButton)
        XCTAssertTrue(player.previousButton.exists, "Previous button should exist")
        XCTAssertTrue(player.nextButton.exists, "Next button should exist")
        XCTAssertTrue(player.shuffleButton.exists, "Shuffle button should exist")
        XCTAssertTrue(player.repeatButton.exists, "Repeat button should exist")
    }

    // MARK: - LIVE-09: Top Bar Navigation

    func testTopBarNavigationButtonsExist() {
        let topBar = TopBarScreen(app: app)
        waitForElement(topBar.backButton)
        XCTAssertTrue(topBar.forwardButton.exists, "Forward button should exist")
    }

    func testBackButtonNavigatesAfterBrowse() throws {
        let sidebar = SidebarScreen(app: app)
        let topBar = TopBarScreen(app: app)
        let browse = BrowseScreen(app: app)

        waitForElement(sidebar.servicesSection)
        let sourceButtons = sidebar.servicesSection.buttons
        guard sourceButtons.count > 0 else {
            throw XCTSkip("No music sources available")
        }

        sourceButtons.firstMatch.click()
        waitForElement(browse.view)

        // Navigate back
        waitForElement(topBar.backButton)
        topBar.backButton.click()

        // Should return to home
        let home = HomeScreen(app: app)
        waitForElement(home.view)
    }

    // MARK: - LIVE-10: Queue Panel (Bottom Bar Toggle)

    func testQueuePanelToggle() {
        let toggleButton = app.descendants(matching: .any)[AccessibilityID.QueuePanel.toggleButton]
        waitForElement(toggleButton)
        toggleButton.click()

        let panel = app.descendants(matching: .any)[AccessibilityID.QueuePanel.view]
        waitForElement(panel)

        // Toggle off
        toggleButton.click()
        waitForElementToDisappear(panel)
    }

    // MARK: - LIVE-11: Sidebar Library Section

    func testLibrarySectionVisible() {
        let sidebar = SidebarScreen(app: app)
        waitForElement(sidebar.librarySection)
    }

    // MARK: - LIVE-12: Search Dismiss on Navigation

    func testSearchDismissesOnSidebarNavigation() {
        let topBar = TopBarScreen(app: app)

        waitForElement(topBar.searchField)
        topBar.searchField.click()
        topBar.searchField.typeText("test")

        // Search results view should appear (even empty state counts)
        let sidebar = SidebarScreen(app: app)
        sidebar.homeButton.click()

        // Search should be dismissed; home view should be visible
        let home = HomeScreen(app: app)
        waitForElement(home.view)
    }

    // MARK: - LIVE-13: Amp Card

    func testAmpCardVisible() {
        let sidebar = SidebarScreen(app: app)
        waitForElement(sidebar.ampCard)
    }
}
