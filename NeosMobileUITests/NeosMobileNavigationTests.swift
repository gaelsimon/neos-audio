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

    func testTheSidebarKeepsTheLibraryTabAboveItsSection() throws {
        try XCTSkipUnless(isPad, "Only the iPad has a sidebar")
        showSidebar()
        XCTAssertTrue(sidebarEntry("Favorites").waitForExistence(timeout: 5))

        // The tab and the section of the same name.
        XCTAssertEqual(sidebarRows(named: "Library"), sidebarRows(named: "Services") + 1)
        openSidebarEntry("Home")
    }

    func testTheBarsQueueButtonOpensThePlayerOnItsQueue() throws {
        try XCTSkipUnless(isPad, "Only the iPad's player bar has a queue button")
        let toggle = element(AccessibilityID.QueuePanel.toggleButton)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        toggle.tap()

        XCTAssertTrue(app.buttons["Close Player"].waitForExistence(timeout: 5), "The player never opened")
        XCTAssertTrue(app.staticTexts["Up Next"].waitForExistence(timeout: 5), "The player opened without its queue")
        app.buttons["Close Player"].tap()
    }

    func testThePlayersQueueTakesTheArtworksPlace() {
        openPlayer()
        let artwork = element(AccessibilityID.NowPlayingCanvas.artwork)
        XCTAssertTrue(artwork.waitForExistence(timeout: 5))

        app.buttons["Queue"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Up Next"].waitForExistence(timeout: 5), "The queue never showed")
        // A sheet would slide in over the player.
        Thread.sleep(forTimeInterval: 1)
        XCTAssertTrue(app.buttons["Close Player"].isHittable, "Something covers the player")
        XCTAssertFalse(artwork.exists, "The queue should take the artwork's place")
        app.buttons["Close Player"].tap()
    }

    func testThePlayerBarsSpeakerOpensTheSpeakers() throws {
        try XCTSkipUnless(isPad, "Only the iPad's player bar names the speaker")
        let speaker = element(AccessibilityID.Player.speakerName)
        XCTAssertTrue(speaker.waitForExistence(timeout: 5))

        speaker.tap()

        XCTAssertTrue(app.navigationBars["Speakers"].waitForExistence(timeout: 5), "The speakers never opened")
        app.buttons["Done"].firstMatch.tap()
    }

    func testThePlayersArtistOpensFromItsMenu() {
        // Other tests leave an input playing, which has no artist.
        openLibraryPage("Deezer")
        open("Albums", "Midnight Opera,")
        let play = element(AccessibilityID.Browse.playContainer)
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(waitUntil { nowPlaying.hasPrefix("Paper Lanterns") }, "Playing \(nowPlaying)")
        openPlayer()

        let more = app.buttons["More"].firstMatch
        XCTAssertTrue(more.waitForExistence(timeout: 5), "The player offers no menu")
        more.tap()
        app.buttons["Go to Artist"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["1 album"].waitForExistence(timeout: 8), "The artist's page never opened")
    }

    func testAToastRaisedInASheetShowsOnTheSheet() {
        app.buttons["Settings"].firstMatch.tap()
        let copy = element(AccessibilityID.Settings.copyDiagnosticsButton)
        let settings = app.collectionViews["settings.view"].firstMatch
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        for _ in 0..<5 where !(copy.exists && copy.isHittable) { settings.swipeUp() }

        copy.tap()

        let toast = app.staticTexts["Diagnostics copied to clipboard"]
        XCTAssertTrue(toast.waitForExistence(timeout: 3) && toast.isHittable, "The toast is out of sight under the sheet")
        app.buttons["Done"].firstMatch.tap()
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
