import XCTest

/// Base class for all Neos UI tests.
/// Launches the app once per test class (not per method) for faster execution.
/// All UI test classes should inherit from this instead of raw XCTestCase.
class BaseUITestCase: XCTestCase {
    private static var _app: XCUIApplication!

    var app: XCUIApplication { Self._app }

    override class func setUp() {
        super.setUp()
        _app = XCUIApplication()
        _app.launchArguments = ["--uitesting", "--skip-discovery"]
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

    /// Wait for an element to exist, polling every 100ms instead of XCTest's default ~1s.
    @discardableResult
    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 2
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
        timeout: TimeInterval = 2
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return }
            Thread.sleep(forTimeInterval: 0.1)
        }
        XCTFail("Element \(element) did not disappear within \(timeout)s")
    }
}
