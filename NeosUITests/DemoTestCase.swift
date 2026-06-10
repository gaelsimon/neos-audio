import XCTest

/// Base class for demo-mode UI tests.
/// Launches the app with `--demo-mode` for deterministic, offline testing.
/// AppState is pre-populated with sample data; no network or hardware required.
class DemoTestCase: XCTestCase {
    private static var _app: XCUIApplication!

    var app: XCUIApplication { Self._app }

    override class func setUp() {
        super.setUp()
        _app = XCUIApplication()
        _app.launchArguments = ["--uitesting", "--demo-mode"]
        _app.launch()
    }

    override class func tearDown() {
        _app.terminate()
        _app = nil
        super.tearDown()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    /// Reset the app to home state: close queue panel, close canvas, navigate home.
    func resetToHome() {
        let home = app.descendants(matching: .any)[AccessibilityID.Home.view]
        if home.exists { return }

        // Close queue panel first; its tap-catcher overlay blocks the canvas close button
        let queuePanel = app.descendants(matching: .any)[AccessibilityID.QueuePanel.view]
        if queuePanel.exists {
            let queueToggle = app.descendants(matching: .any)[AccessibilityID.QueuePanel.toggleButton]
            if queueToggle.exists { queueToggle.click() }
            waitForElementToDisappear(queuePanel, timeout: 3)
        }

        // Close canvas if open
        let canvasClose = app.descendants(matching: .any)[AccessibilityID.NowPlayingCanvas.closeButton]
        if canvasClose.exists { canvasClose.click() }

        // Navigate to home via sidebar
        let homeButton = app.descendants(matching: .any)[AccessibilityID.Sidebar.home]
        if homeButton.exists { homeButton.click() }

        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline {
            if home.exists { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    /// Wait for an element to exist, polling every 100ms.
    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) -> XCUIElement {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return element }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTFail("Element \(element) did not appear within \(timeout)s")
        return element
    }

    /// Wait for an element to disappear, polling every 100ms.
    func waitForElementToDisappear(
        _ element: XCUIElement,
        timeout: TimeInterval = 5
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTFail("Element \(element) did not disappear within \(timeout)s")
    }
}
