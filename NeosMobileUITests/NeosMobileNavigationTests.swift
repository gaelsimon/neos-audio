import XCTest

/// Reaching every source from the tabs, and from the iPad's sidebar.
final class NeosMobileNavigationTests: MobileDemoTestCase {
    private let sources = ["Favorites", "Playlists", "History", "Queue", "Deezer", "TuneIn", "TIDAL", "Local Music", "AUX Input"]

    private func sidebarRows(named name: String) -> Int {
        app.cells.matching(NSPredicate(format: "label == %@", name)).count
    }

    func testTheLibraryListsEverySource() {
        tab("Library").tap()

        for name in sources {
            XCTAssertTrue(app.collectionViews.buttons[name].waitForExistence(timeout: 5), "No \(name) in the library")
        }
    }

    func testASourceOpensFromTheLibrary() {
        openLibraryPage("Deezer")

        XCTAssertTrue(app.navigationBars["Deezer"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { item(startingWith: "Albums") != nil })
    }

    func testTheTabBarHoldsNoSectionOfTheSidebar() throws {
        try XCTSkipUnless(isPad, "Only the iPad has a sidebar")

        XCTAssertTrue(tab("Library").exists)
        // As tabs, the sections would each open their first source and hide the others.
        XCTAssertFalse(app.buttons["Services"].exists)
        XCTAssertFalse(app.buttons["Local"].exists)
    }

    func testTheSidebarOpensASourceOnItsOwnPage() throws {
        try XCTSkipUnless(isPad, "Only the iPad has a sidebar")

        openSidebarEntry("Deezer")

        XCTAssertTrue(app.navigationBars["Deezer"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil { item(startingWith: "Albums") != nil })
        XCTAssertFalse(app.navigationBars["Deezer"].buttons["Library"].exists, "The source's own page has nothing to go back to")
    }

    func testTheSidebarListsEverySource() throws {
        try XCTSkipUnless(isPad, "Only the iPad has a sidebar")

        showSidebar()

        for name in sources {
            XCTAssertTrue(sidebarEntry(name).waitForExistence(timeout: 5), "No \(name) in the sidebar")
        }
        openSidebarEntry("Home")
    }

    func testTheSidebarListsLibraryOnlyWhileItIsThePageShowing() throws {
        try XCTSkipUnless(isPad, "Only the iPad has a sidebar")
        tab("Library").tap()
        showSidebar()
        XCTAssertTrue(sidebarEntry("Favorites").waitForExistence(timeout: 5))
        // The tab and the section of the same name.
        XCTAssertEqual(sidebarRows(named: "Library"), sidebarRows(named: "Services") + 1)

        openSidebarEntry("Home")
        showSidebar()
        XCTAssertTrue(sidebarEntry("Favorites").waitForExistence(timeout: 5))

        XCTAssertEqual(sidebarRows(named: "Library"), sidebarRows(named: "Services"), "Only the section should be left")
        openSidebarEntry("Home")
    }

    func testAnArtistWithOneAlbumCountsOneAlbum() {
        openLibraryPage("Deezer")

        open("Artists", "The Velvet Hours")

        XCTAssertTrue(app.staticTexts["1 album"].waitForExistence(timeout: 5))
    }

    func testAnEmptyFolderSaysSo() {
        openLibraryPage("TuneIn")

        open("Podcasts")

        XCTAssertTrue(app.staticTexts["No Items"].waitForExistence(timeout: 5))
    }

    func testAFolderThatFailsOffersToRetry() {
        openLibraryPage("TuneIn")

        open("Talk")

        XCTAssertTrue(app.staticTexts["Couldn't Load"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Retry"].exists)
    }

    func testAnInputPlaysFromItsSpeakerPage() {
        openLibraryPage("AUX Input")

        open("Living Room", "CD")

        XCTAssertTrue(waitUntil { nowPlaying.contains("CD") }, "Playing \(nowPlaying)")
    }
}
