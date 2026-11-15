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
