import XCTest

/// Tests for sidebar navigation and connected UI in demo mode.
/// Verifies the home screen, sidebar elements, and navigation between sections.
final class DemoNavigationTests: DemoTestCase {

    // MARK: - Home Screen

    func testHomeViewExists() {
        let home = HomeScreen(app: app)
        waitForElement(home.view)
        XCTAssertTrue(home.view.exists)
    }

    func testHomeHeaderExists() {
        let home = HomeScreen(app: app)
        waitForElement(home.header)
        XCTAssertTrue(home.header.exists)
    }

    // MARK: - Sidebar Connected Elements

    func testSidebarHomeButtonExists() {
        let sidebar = SidebarScreen(app: app)
        waitForElement(sidebar.homeButton)
        XCTAssertTrue(sidebar.homeButton.exists)
    }

    func testSidebarQueueButtonExists() {
        let sidebar = SidebarScreen(app: app)
        waitForElement(sidebar.queueButton)
        XCTAssertTrue(sidebar.queueButton.exists)
    }

    func testSidebarAmpCardExists() {
        let sidebar = SidebarScreen(app: app)
        waitForElement(sidebar.ampCard)
        XCTAssertTrue(sidebar.ampCard.exists)
    }

    // MARK: - Navigation Flow

    func testNavigateToQueueAndBack() {
        let sidebar = SidebarScreen(app: app)
        let queue = QueueScreen(app: app)
        let home = HomeScreen(app: app)

        // Navigate to queue
        waitForElement(sidebar.queueButton)
        sidebar.queueButton.click()
        waitForElement(queue.view)
        XCTAssertTrue(queue.view.exists)

        // Navigate back to home
        waitForElement(sidebar.homeButton)
        sidebar.homeButton.click()
        waitForElement(home.view)
        XCTAssertTrue(home.view.exists)
    }

    // MARK: - Disconnected Views NOT Visible

    func testDisconnectedViewNotVisibleWhenConnected() {
        let disconnected = DisconnectedScreen(app: app)
        waitForElement(HomeScreen(app: app).view)
        XCTAssertFalse(disconnected.view.exists, "Disconnected view should not exist when connected in demo mode")
    }

    // MARK: - Top Bar

    func testSearchFieldExists() {
        let topBar = TopBarScreen(app: app)
        waitForElement(topBar.searchField)
        XCTAssertTrue(topBar.searchField.exists)
    }
}
