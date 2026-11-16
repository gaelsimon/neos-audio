import XCTest

/// The player floats over the pages of the iPhone and iPad app. Scrolled to its end, each kind of page must still
/// show its last line above it.
final class NeosMobileLayoutTests: MobileDemoTestCase {

    func testHomeEndsAboveThePlayer() {
        assertThePageEndsAboveThePlayer()

        XCTAssertNotNil(item(startingWith: "Harbour Mouth"), "The last card of Home should be on screen")
    }

    func testTheLibraryEndsAboveThePlayer() {
        tab("Library").tap()

        assertThePageEndsAboveThePlayer(swipes: 2)

        XCTAssertTrue(app.collectionViews.buttons["AUX Input"].exists, "The last source should be on screen")
    }

    func testAnAlbumEndsAboveThePlayer() {
        openLibraryPage("Deezer")
        open("Albums", "Midnight Opera,")

        assertThePageEndsAboveThePlayer()

        XCTAssertTrue(element(AccessibilityID.TrackList.row(2)).exists, "The last track should be on screen")
    }

    func testALongPlaylistEndsAboveThePlayer() {
        openLibraryPage("Deezer")
        open("Playlists", "Road Trip")

        assertThePageEndsAboveThePlayer(swipes: 18)

        XCTAssertTrue(element(AccessibilityID.TrackList.row(120)).exists, "The last track should be on screen")
    }

    /// A page that opens on its artwork must give it back to a flick, not stop on the first track.
    func testAFlickBackUpReachesTheArtwork() {
        openLibraryPage("Deezer")
        open("Playlists", "Road Trip")
        let firstTrack = element(AccessibilityID.TrackList.row(1))
        XCTAssertTrue(firstTrack.waitForExistence(timeout: 5), "The playlist never showed its tracks")
        Thread.sleep(forTimeInterval: 1)
        let opening = firstTrack.frame.minY
        let page = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
        page.press(forDuration: 0.1, thenDragTo: page.withOffset(CGVector(dx: 0, dy: -700)), withVelocity: .slow, thenHoldForDuration: 0.3)

        app.windows.firstMatch.swipeDown(velocity: .default)

        XCTAssertTrue(waitUntil { firstTrack.exists && abs(firstTrack.frame.minY - opening) < 1 }, "The flick stopped short of the artwork")
    }

    func testAGridEndsAboveThePlayer() {
        openLibraryPage("Deezer")
        open("Artists", "The Velvet Hours")

        assertThePageEndsAboveThePlayer()

        XCTAssertNotNil(item(startingWith: "Midnight Opera"), "The artist's album should be on screen")
    }

    func testTheQueueEndsAboveThePlayer() {
        openLibraryPage("Queue")

        assertThePageEndsAboveThePlayer(swipes: 2)

        XCTAssertTrue(element(AccessibilityID.TrackList.row(4)).exists, "The last track should be on screen")
    }

    func testSearchResultsEndAboveThePlayer() {
        search("mi")

        assertThePageEndsAboveThePlayer(swipes: 8)

        XCTAssertNotNil(item(startingWith: "Road Trip"), "The last result should be on screen")
    }
}
