import XCTest

/// The demo's speaker keeps what it is asked to play, queue and remove. The app launches once and each test starts
/// from what the previous one left playing, so the numbers in the names are the order.
final class NeosMobilePlaybackTests: MobileDemoTestCase {

    private func row(_ index: Int) -> XCUIElement {
        element(AccessibilityID.TrackList.row(index))
    }

    private func openDeezerAlbum(_ name: String) {
        openLibraryPage("Deezer")
        open("Albums", name)
    }

    func test1NextMovesToTheFollowingTrack() {
        let before = nowPlaying

        app.buttons["Next"].firstMatch.tap()

        XCTAssertTrue(waitUntil { nowPlaying != before }, "Still on \(before)")
    }

    func test2AStationPlaysUnderItsName() {
        openLibraryPage("Favorites")
        // The wide layout numbers its rows, and iOS 27 adds the row's menu to its label: the name is in the middle.
        let station = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH 'trackList.row' AND label CONTAINS 'Eclectic FM'")).firstMatch
        XCTAssertTrue(station.waitForExistence(timeout: 5))

        station.tap()

        XCTAssertTrue(waitUntil { nowPlaying.hasPrefix("Eclectic FM") }, "Playing \(nowPlaying)")
    }

    func test3PlayingAnAlbumReplacesTheQueue() {
        openDeezerAlbum("Analog Dreams")
        let play = element(AccessibilityID.Browse.playContainer)
        XCTAssertTrue(play.waitForExistence(timeout: 5))

        play.tap()

        XCTAssertTrue(waitUntil { nowPlaying.hasPrefix("Tape Hiss") }, "Playing \(nowPlaying)")
        returnHome()
        openLibraryPage("Queue")
        XCTAssertTrue(row(3).waitForExistence(timeout: 5), "The album has three tracks")
        XCTAssertFalse(row(4).exists, "The earlier queue should be gone")
    }

    func test4ARemovedTrackStaysOutOfTheQueue() {
        openLibraryPage("Queue")
        XCTAssertTrue(row(3).waitForExistence(timeout: 5))

        row(3).swipeLeft()
        app.buttons["Remove"].firstMatch.tap()

        XCTAssertTrue(waitUntil { !row(3).exists }, "The row is still there")
        returnHome()
        openLibraryPage("Queue")
        XCTAssertTrue(row(2).waitForExistence(timeout: 5))
        XCTAssertFalse(row(3).exists, "The track came back")
    }

    func test5ClearingTheQueueLeavesNothingPlaying() {
        openLibraryPage("Queue")
        let clear = element(AccessibilityID.Queue.clearButton)
        XCTAssertTrue(clear.waitForExistence(timeout: 5))

        clear.tap()
        app.buttons["Clear Queue"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Queue Is Empty"].waitForExistence(timeout: 5))
        XCTAssertTrue(nowPlaying.hasPrefix("Not Playing"), "Playing \(nowPlaying)")
    }
}
