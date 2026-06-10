import XCTest

/// All smoke and navigation tests in one class; single app launch, no speaker required.
final class SmokeTests: BaseUITestCase {

    // MARK: - App Launch

    func testAppLaunches() throws {
        waitForElement(app.windows.firstMatch)
    }

    // MARK: - SMOKE-01: Main views exist after app launch

    func testAppLaunchesInDisconnectedMode() {
        let disconnected = DisconnectedScreen(app: app)

        waitForElement(disconnected.title)
    }

    func testDisconnectedViewContainerExists() {
        let disconnected = DisconnectedScreen(app: app)

        waitForElement(disconnected.view)
    }

    // MARK: - SMOKE-03: Disconnected state shows appropriate UI

    func testDisconnectedTitleShowsTroubleshootingText() {
        let disconnected = DisconnectedScreen(app: app)

        waitForElement(disconnected.title)
        // The title text on the discovery/disconnected view is "No Players Found"
        XCTAssertEqual(
            disconnected.title.value as? String,
            "No Players Found",
            "Disconnected title should show 'No Players Found'"
        )
    }

    func testSidebarElementsExistInDisconnectedMode() {
        let sidebar = SidebarScreen(app: app)

        // Wait for the scan button to render
        waitForElement(sidebar.scanButton)

        // Manual connect section auto-opens in --uitesting mode.
        // If not yet visible, tap the toggle to expand it.
        if !sidebar.manualIPField.exists {
            let toggle = DisconnectedScreen(app: app).manualConnectToggle
            waitForElement(toggle)
            toggle.click()
        }

        waitForElement(sidebar.manualIPField, timeout: 3)
        XCTAssertTrue(sidebar.manualIPField.exists, "Manual IP field should exist")
        XCTAssertTrue(sidebar.manualConnectButton.exists, "Manual connect button should exist")
    }

    // MARK: - Connected-only views are NOT visible in disconnected mode

    func testConnectedViewsNotVisibleWhenDisconnected() {
        let home = HomeScreen(app: app)
        let queue = QueueScreen(app: app)

        waitForElement(app.windows.firstMatch)

        XCTAssertFalse(home.view.exists, "Home view should not exist when disconnected")
        XCTAssertFalse(queue.view.exists, "Queue view should not exist when disconnected")
    }

    // MARK: - SMOKE-02: Sidebar navigation

    func testScanButtonExistsInStatusBar() {
        let sidebar = SidebarScreen(app: app)

        waitForElement(sidebar.scanButton)
        XCTAssertTrue(sidebar.scanButton.isEnabled, "Scan button should be enabled when disconnected")
    }

    func testManualConnectButtonDisabledWhenIPFieldEmpty() {
        let sidebar = SidebarScreen(app: app)
        let disconnected = DisconnectedScreen(app: app)

        // Expand the "Connect by IP" disclosure if not already open
        if !sidebar.manualIPField.exists {
            waitForElement(disconnected.manualConnectToggle)
            disconnected.manualConnectToggle.click()
        }

        waitForElement(sidebar.manualIPField, timeout: 3)
        waitForElement(sidebar.manualConnectButton)

        XCTAssertFalse(
            sidebar.manualConnectButton.isEnabled,
            "Connect button should be disabled when IP field is empty"
        )
    }
}
