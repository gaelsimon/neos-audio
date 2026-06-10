import XCTest

/// Base class for live hardware integration tests.
/// Launches the app once per test class with real speaker discovery enabled.
/// Waits up to 30s for a HEOS speaker to connect; XCTSkips the entire class if unavailable.
class LiveTestCase: XCTestCase {
    private static var _app: XCUIApplication!
    private static var speakerAvailable = false

    var app: XCUIApplication { Self._app }

    override class func setUp() {
        super.setUp()
        _app = XCUIApplication()
        // --uitesting resets UI state; NO --skip-discovery so real discovery runs
        _app.launchArguments = ["--uitesting"]
        _app.launch()

        let home = _app.descendants(matching: .any)[AccessibilityID.Home.view]

        // Phase 1: Wait up to 10s for auto-connection via cached device
        let autoConnectDeadline = Date().addingTimeInterval(10)
        while Date() < autoConnectDeadline {
            if home.exists { speakerAvailable = true; break }
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Phase 2: If not auto-connected, look for discovered devices and click the first one
        if !speakerAvailable {
            let deviceGrid = _app.descendants(matching: .any)[AccessibilityID.Discovery.deviceGrid]
            let gridDeadline = Date().addingTimeInterval(20)
            while Date() < gridDeadline {
                if deviceGrid.exists { break }
                Thread.sleep(forTimeInterval: 0.1)
            }

            if deviceGrid.exists {
                // Click the first discovered device card to connect.
                // Cards use .buttonStyle(.plain) so search via descendants.
                let firstDevice = deviceGrid.descendants(matching: .any)
                    .matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.deviceCard.'"))
                    .firstMatch
                if firstDevice.waitForExistence(timeout: 5) {
                    firstDevice.click()

                    // Wait for connection to complete (home view appears)
                    let connectDeadline = Date().addingTimeInterval(15)
                    while Date() < connectDeadline {
                        if home.exists { speakerAvailable = true; break }
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                }
            }
        }

        if !speakerAvailable {
            _app.terminate()
        }
    }

    override class func tearDown() {
        if speakerAvailable {
            _app.terminate()
        }
        _app = nil
        super.tearDown()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard Self.speakerAvailable else {
            throw XCTSkip("No HEOS speaker available on network")
        }
    }

    override func tearDownWithError() throws {
        // No-op: each test navigates to its own starting state.
        // Sidebar clicks auto-dismiss search via navigationTapCount.
    }

    // MARK: - Helpers

    /// Scroll the sidebar until an element appears, polling every 100ms.
    @discardableResult
    func scrollSidebarToElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 10
    ) -> XCUIElement {
        let sidebarScroll = app.scrollViews[AccessibilityID.Sidebar.scrollView]
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists { return element }
            sidebarScroll.swipeUp()
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTFail("Element \(element) did not appear after scrolling within \(timeout)s")
        return element
    }

    /// Wait for an element to exist, polling every 100ms (default 10s for hardware ops).
    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 10
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
        timeout: TimeInterval = 10
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTFail("Element \(element) did not disappear within \(timeout)s")
    }
}
