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
        XCTAssertTrue(waitUntil(30) { tab("Home").exists || sidebarButton.exists }, "The app never showed its tabs")
        // A landscape iPad opens with the sidebar it had last time, and the tabs are then rows of it.
        if !tab("Home").exists { sidebarButton.tap() }
        XCTAssertTrue(tab("Home").waitForExistence(timeout: 5), "The tabs never appeared")
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

    /// Shows or hides the iPad's sidebar.
    var sidebarButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'sidebar'")).firstMatch
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func button(startingWith label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label)).firstMatch
    }

    /// A row or a tile of the page, nil until it shows. The iPad's player bar links to the artist and the album by
    /// the same names.
    func item(startingWith label: String) -> XCUIElement? {
        let matches = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", label))
        let bar = element(AccessibilityID.Player.bar)
        let player = isPad && bar.exists ? bar.frame : .null
        return (0..<matches.count).lazy.map { matches.element(boundBy: $0) }.first { !player.contains($0.frame) }
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

    /// A page of the library, through the Library tab.
    func openLibraryPage(_ name: String) {
        let library = tab("Library")
        library.tap()
        let row = app.collectionViews.buttons[name].firstMatch
        // The tab shows the page it was left on; a second tap goes back to its list.
        if !row.waitForExistence(timeout: 2) { library.tap() }
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The library should list \(name)")
        row.tap()
    }

    /// The iPad's tabs turn into rows of the sidebar while it shows.
    var isSidebarShowing: Bool { !tab("Home").exists }

    func showSidebar() {
        if !isSidebarShowing { sidebarButton.tap() }
        XCTAssertTrue(waitUntil { isSidebarShowing }, "The sidebar never opened")
    }

    /// A row of the sidebar. The page behind it may show the same name, as a button or a text.
    func sidebarEntry(_ name: String) -> XCUIElement {
        app.cells[name].firstMatch
    }

    /// A source's own tab, through the iPad's sidebar.
    func openSidebarEntry(_ name: String) {
        showSidebar()
        let entry = sidebarEntry(name)
        XCTAssertTrue(entry.waitForExistence(timeout: 5), "The sidebar should list \(name)")
        entry.tap()
        // In portrait the sidebar closes after a pick; in landscape it stays.
        if !tab("Home").waitForExistence(timeout: 3) { sidebarButton.tap() }
    }

    func open(_ labels: String...) {
        for label in labels {
            XCTAssertTrue(waitUntil { item(startingWith: label) != nil }, "No \(label) to open")
            item(startingWith: label)?.tap()
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

    /// Runs a search and waits for the page to answer.
    func search(_ query: String) {
        tab("Search").tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "No search field")
        field.tap()
        let clear = app.buttons["Clear text"].firstMatch
        if clear.exists { clear.tap() }
        field.typeText(query + "\n")
        XCTAssertTrue(element(AccessibilityID.Search.resultsView).waitForExistence(timeout: 5), "The search never answered")
    }

    /// Ends a search, so the tabs are back whatever the system hid while it ran.
    func leaveSearch() {
        let field = app.searchFields.firstMatch
        guard field.exists else { return }
        for label in ["Cancel", "Close", "Clear text"] {
            let button = app.buttons[label].firstMatch
            if button.exists, button.isHittable {
                button.tap()
                return
            }
        }
    }

    /// Closes whatever is in front and leaves the Library and Home tabs at their first page, Home showing.
    func returnHome() {
        for _ in 0..<4 {
            let inFront = ["Cancel", "Done", "Close Player"].map { app.buttons[$0].firstMatch }.first(where: \.exists)
            guard let inFront else { break }
            inFront.tap()
        }
        leaveSearch()
        // A tap on the tab already showing goes back to its first page.
        for label in ["Library", "Home"] {
            let tab = tab(label)
            guard tab.exists else { continue }
            tab.tap()
            tab.tap()
        }
    }

    // MARK: - The end of a page

    func scrollToTheEnd(swipes: Int = 4) {
        let window = app.windows.firstMatch
        for _ in 0..<swipes {
            let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
            let to = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
            from.press(forDuration: 0.03, thenDragTo: to, withVelocity: .fast, thenHoldForDuration: 0)
        }
    }

    /// Scrolled to its end, a page shows its last line above the player.
    func assertThePageEndsAboveThePlayer(swipes: Int = 4, file: StaticString = #filePath, line: UInt = #line) {
        scrollToTheEnd(swipes: swipes)
        let bar = element(AccessibilityID.Player.bar)
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "No player on this page", file: file, line: line)
        // The scroll settles before the frames are read.
        Thread.sleep(forTimeInterval: 0.8)
        let player = bar.frame
        let hidden = labelledFrames(outside: AccessibilityID.Player.bar).filter { item in
            item.frame.maxY > player.minY + 1 && item.frame.minY < player.maxY
                && item.frame.maxX > player.minX && item.frame.minX < player.maxX
        }
        XCTAssertTrue(hidden.isEmpty, "Under the player: \(hidden.map(\.label))", file: file, line: line)
    }

    /// Every labelled text and button on screen, read in one pass. The bars and what `identifier` names are left out.
    func labelledFrames(outside identifier: String? = nil) -> [(label: String, frame: CGRect)] {
        guard let snapshot = try? app.snapshot() else { return [] }
        var found: [(label: String, frame: CGRect)] = []
        func visit(_ node: XCUIElementSnapshot) {
            if [.tabBar, .navigationBar, .keyboard].contains(node.elementType) { return }
            if let identifier, node.identifier == identifier { return }
            if [.staticText, .button].contains(node.elementType), !node.label.isEmpty, node.frame.height > 0 {
                found.append((node.label, node.frame))
            }
            node.children.forEach(visit)
        }
        visit(snapshot)
        return found.filter { $0.frame.intersects(snapshot.frame) }
    }
}
