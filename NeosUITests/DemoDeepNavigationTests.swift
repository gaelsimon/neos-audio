import XCTest

/// Tests for deep navigation with back/forward in demo mode.
/// Verifies multi-step navigation flows: home -> source -> settings -> back -> forward.
final class DemoDeepNavigationTests: DemoTestCase {

    private var sidebar: SidebarScreen { SidebarScreen(app: app) }
    private var topBar: TopBarScreen { TopBarScreen(app: app) }
    private var home: HomeScreen { HomeScreen(app: app) }
    private var browse: BrowseScreen { BrowseScreen(app: app) }
    private var settings: SettingsScreen { SettingsScreen(app: app) }
    private var ampSettings: AmpSettingsScreen { AmpSettingsScreen(app: app) }

    override func setUp() {
        super.setUp()
        resetToHome()
    }

    // MARK: - Back/Forward Navigation

    func testBackAndForwardButtonsExist() {
        waitForElement(home.view)
        waitForElement(topBar.backButton)
        waitForElement(topBar.forwardButton)
        XCTAssertTrue(topBar.backButton.exists, "Back button should exist")
        XCTAssertTrue(topBar.forwardButton.exists, "Forward button should exist")
    }

    func testNavigateToSourceThenBack() {
        waitForElement(home.view)

        // Navigate to a music source (Deezer, sid=2)
        waitForElement(sidebar.sourceButton(sid: 2))
        sidebar.sourceButton(sid: 2).click()
        waitForElement(browse.view)
        XCTAssertTrue(browse.view.exists, "Browse view should appear for Deezer")

        // Back should be enabled now
        XCTAssertTrue(topBar.backButton.isEnabled, "Back should be enabled after navigating")

        // Go back to home
        topBar.backButton.click()
        waitForElement(home.view)
        XCTAssertTrue(home.view.exists, "Home should appear after going back")
    }

    func testNavigateBackThenForward() {
        waitForElement(home.view)

        // Navigate to source
        waitForElement(sidebar.sourceButton(sid: 2))
        sidebar.sourceButton(sid: 2).click()
        waitForElement(browse.view)

        // Go back
        topBar.backButton.click()
        waitForElement(home.view)

        // Forward should be enabled
        XCTAssertTrue(topBar.forwardButton.isEnabled, "Forward should be enabled after going back")

        // Go forward to browse
        topBar.forwardButton.click()
        waitForElement(browse.view)
        XCTAssertTrue(browse.view.exists, "Browse should appear after going forward")
    }

    // MARK: - Multi-step Deep Navigation

    func testHomeToSourceToSettingsToBack() {
        waitForElement(home.view)

        // Step 1: Home -> Source
        waitForElement(sidebar.sourceButton(sid: 2))
        sidebar.sourceButton(sid: 2).click()
        waitForElement(browse.view)

        // Step 2: Source -> Settings (via profile button)
        waitForElement(topBar.profileButton)
        topBar.profileButton.click()
        waitForElement(settings.view)
        XCTAssertTrue(settings.view.exists, "Settings should appear")

        // Step 3: Back to Browse
        topBar.backButton.click()
        waitForElement(browse.view)
        XCTAssertTrue(browse.view.exists, "Browse should appear after back from settings")

        // Step 4: Back to Home
        topBar.backButton.click()
        waitForElement(home.view)
        XCTAssertTrue(home.view.exists, "Home should appear after second back")
    }

    func testHomeToQueueToSourceToHome() {
        waitForElement(home.view)

        // Home -> Queue
        waitForElement(sidebar.queueButton)
        sidebar.queueButton.click()
        let queue = QueueScreen(app: app)
        waitForElement(queue.view)

        // Queue -> Source
        waitForElement(sidebar.sourceButton(sid: 2))
        sidebar.sourceButton(sid: 2).click()
        waitForElement(browse.view)

        // Source -> Home (via sidebar)
        waitForElement(sidebar.homeButton)
        sidebar.homeButton.click()
        waitForElement(home.view)
        XCTAssertTrue(home.view.exists)
    }

    // MARK: - Settings Navigation

    func testProfileButtonNavigatesToSettings() {
        waitForElement(home.view)
        waitForElement(topBar.profileButton)
        topBar.profileButton.click()
        waitForElement(settings.view)
        XCTAssertTrue(settings.view.exists)
    }

    func testAmpCardNavigatesToAmpSettings() {
        waitForElement(home.view)
        waitForElement(sidebar.ampCard)
        sidebar.ampCard.click()
        waitForElement(ampSettings.view)
        XCTAssertTrue(ampSettings.view.exists)
    }

    func testProfileButtonTogglesSettings() {
        waitForElement(home.view)

        // Open settings
        topBar.profileButton.click()
        waitForElement(settings.view)

        // Click again to go back
        topBar.profileButton.click()
        waitForElement(home.view)
        XCTAssertTrue(home.view.exists, "Profile button should toggle settings")
    }

    // MARK: - Search Interrupts Navigation

    func testSearchFromBrowseThenBackRestoresBrowse() {
        waitForElement(home.view)

        // Navigate to source
        waitForElement(sidebar.sourceButton(sid: 2))
        sidebar.sourceButton(sid: 2).click()
        waitForElement(browse.view)

        // Type search
        let search = SearchScreen(app: app)
        waitForElement(topBar.searchField)
        topBar.searchField.click()
        topBar.searchField.typeText("test")
        waitForElement(search.resultsView)

        // Back should dismiss search and show browse
        topBar.backButton.click()
        waitForElement(browse.view)
        XCTAssertTrue(browse.view.exists, "Browse should be restored after dismissing search")
    }
}
