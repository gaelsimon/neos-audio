import XCTest

/// The iPhone and iPad app in demo mode, launched once for the class. Each test starts on the first page of Home.
class MobileDemoTestCase: XCTestCase {
    private static var launched: XCUIApplication?

    var app: XCUIApplication {
        guard let app = Self.launched else { preconditionFailure("The app is launched before any test runs") }
        return app
    }

    override class func setUp() {
        super.setUp()
        let app = XCUIApplication()
        app.launchArguments = ["--demo-mode"]
        app.launch()
        launched = app
    }

    override class func tearDown() {
        launched?.terminate()
        launched = nil
        super.tearDown()
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCTAssertTrue(tab("Home").waitForExistence(timeout: 30), "The tabs never appeared")
    }

    override func tearDownWithError() throws {
        returnHome()
    }

    // MARK: - Finding things

    var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    /// The tab bar on iPhone; the iPad's floating tab bar exposes its tabs as plain buttons.
    func tab(_ label: String) -> XCUIElement {
        let inBar = app.tabBars.buttons[label]
        return inBar.exists ? inBar : app.buttons[label].firstMatch
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func button(startingWith label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    /// What the player says is on.
    var nowPlaying: String {
        element(AccessibilityID.Player.songTitle).label
    }

    func waitUntil(_ timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }

    // MARK: - Getting around

    /// A page of the library: a row of the Library tab on iPhone, an entry of the sidebar on iPad.
    func openLibraryPage(_ name: String) {
        if isPad {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch.tap()
            let entry = app.staticTexts[name].firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 5), "The sidebar should list \(name)")
            entry.tap()
        } else {
            tab("Library").tap()
            let row = app.buttons[name].firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5), "The library should list \(name)")
            row.tap()
        }
    }

    func openPlayer() {
        if isPad {
            app.buttons["Full Screen Player"].firstMatch.tap()
        } else {
            element(AccessibilityID.Player.songTitle).tap()
        }
        XCTAssertTrue(app.buttons["Close Player"].waitForExistence(timeout: 5), "The player did not open")
    }

    /// Closes whatever is in front and leaves the tab the test was on at its first page, then goes to Home.
    func returnHome() {
        for _ in 0..<4 {
            let inFront = ["Cancel", "Done", "Close Player"].map { app.buttons[$0].firstMatch }.first(where: \.exists)
            guard let inFront else { break }
            inFront.tap()
        }
        // A tap on the tab already showing goes back to its first page.
        app.tabBars.buttons.allElementsBoundByIndex.first(where: \.isSelected)?.tap()
        let home = tab("Home")
        guard home.exists else { return }
        home.tap()
        home.tap()
    }
}
