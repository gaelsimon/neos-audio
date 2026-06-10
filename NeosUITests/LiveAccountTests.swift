import XCTest

/// LIVE-07: Account sign-in and sign-out flow against live HEOS account.
/// Requires HEOS_USERNAME and HEOS_PASSWORD environment variables.
/// XCTSkips when credentials are missing or no speaker is available.
final class LiveAccountTests: XCTestCase {
    private static var _app: XCUIApplication!
    private static var speakerAvailable = false
    private static var username: String?
    private static var password: String?

    var app: XCUIApplication { Self._app }

    override class func setUp() {
        super.setUp()
        username = ProcessInfo.processInfo.environment["HEOS_USERNAME"]
        password = ProcessInfo.processInfo.environment["HEOS_PASSWORD"]

        guard let u = username, let p = password, !u.isEmpty, !p.isEmpty else {
            return
        }

        _app = XCUIApplication()
        _app.launchArguments = ["--uitesting"]
        _app.launch()

        let home = _app.descendants(matching: .any)[AccessibilityID.Home.view]

        // Phase 1: Wait for auto-connection via cached device
        let autoDeadline = Date().addingTimeInterval(10)
        while Date() < autoDeadline {
            if home.exists { speakerAvailable = true; break }
            Thread.sleep(forTimeInterval: 0.1)
        }

        // Phase 2: If not auto-connected, click the first discovered device
        if !speakerAvailable {
            let deviceGrid = _app.descendants(matching: .any)[AccessibilityID.Discovery.deviceGrid]
            let gridDeadline = Date().addingTimeInterval(20)
            while Date() < gridDeadline {
                if deviceGrid.exists { break }
                Thread.sleep(forTimeInterval: 0.1)
            }

            if deviceGrid.exists {
                let firstDevice = deviceGrid.descendants(matching: .any)
                    .matching(NSPredicate(format: "identifier BEGINSWITH 'discovery.deviceCard.'"))
                    .firstMatch
                if firstDevice.waitForExistence(timeout: 5) {
                    firstDevice.click()
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
            _app?.terminate()
        }
        _app = nil
        super.tearDown()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let u = Self.username, let p = Self.password, !u.isEmpty, !p.isEmpty else {
            throw XCTSkip("No HEOS credentials - set HEOS_USERNAME and HEOS_PASSWORD env vars")
        }
        guard Self.speakerAvailable else {
            throw XCTSkip("No HEOS speaker available on network")
        }
        _ = u; _ = p
    }

    // MARK: - Tests

    func testSignInAndSignOut() {
        let settings = SettingsScreen(app: app)
        let topBar = TopBarScreen(app: app)

        // Navigate to settings via profile button
        waitForElement(topBar.profileButton)
        topBar.profileButton.click()

        // Wait for settings view
        waitForElement(settings.view)

        // Type credentials into the sign-in form
        waitForElement(settings.emailField)
        settings.emailField.click()
        settings.emailField.typeText(Self.username!)

        settings.passwordField.click()
        settings.passwordField.typeText(Self.password!)

        // Tap sign in
        settings.signInButton.click()

        // Wait for signed-in state (user label appears)
        waitForElement(settings.signedInUser, timeout: 15)

        // Sign out
        waitForElement(settings.signOutButton)
        settings.signOutButton.click()

        // Wait for signed-out state (email field reappears)
        waitForElement(settings.emailField, timeout: 15)
    }

    // MARK: - Helpers

    @discardableResult
    private func waitForElement(
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
}
