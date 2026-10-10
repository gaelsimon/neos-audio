import XCTest
@testable import Neos
import NeosDomain

final class TrackListPresentationTests: XCTestCase {

    private func track(_ name: String, album: String?) -> BrowseItem {
        BrowseItem(name: name, type: .song, mid: name, playable: true, album: album)
    }

    func testEveryRowOnTheSameAlbumNamesIt() {
        let items = [track("a", album: "Escape the Flames"), track("b", album: "Escape the Flames")]
        XCTAssertEqual(TrackListPresentation.sharedAlbum(in: items), "Escape the Flames")
    }

    func testTwoAlbumsShareNothing() {
        let items = [track("a", album: "One"), track("b", album: "Two")]
        XCTAssertNil(TrackListPresentation.sharedAlbum(in: items))
    }

    func testARowWithoutAnAlbumBreaksTheMatch() {
        let items = [track("a", album: "One"), track("b", album: nil)]
        XCTAssertNil(TrackListPresentation.sharedAlbum(in: items))
    }

    func testEmptyAlbumsShareNothing() {
        let items = [track("a", album: ""), track("b", album: "")]
        XCTAssertNil(TrackListPresentation.sharedAlbum(in: items))
    }

    func testNoRowsShareNothing() {
        XCTAssertNil(TrackListPresentation.sharedAlbum(in: []))
    }

    func testEveryRowByTheSameArtistNamesThem() {
        let items = [
            BrowseItem(name: "a", type: .song, mid: "a", playable: true, artist: "Scarecrow"),
            BrowseItem(name: "b", type: .song, mid: "b", playable: true, artist: "Scarecrow"),
        ]
        XCTAssertEqual(TrackListPresentation.sharedArtist(in: items), "Scarecrow")
    }

    func testAFeaturedArtistBreaksTheArtistMatch() {
        let items = [
            BrowseItem(name: "a", type: .song, mid: "a", playable: true, artist: "Scarecrow"),
            BrowseItem(name: "b", type: .song, mid: "b", playable: true, artist: "Scarecrow, Kamy"),
        ]
        XCTAssertNil(TrackListPresentation.sharedArtist(in: items))
    }

    func testSurroundingSpacesDoNotSplitAnAlbum() {
        let items = [track("a", album: "One "), track("b", album: " One")]
        XCTAssertEqual(TrackListPresentation.sharedAlbum(in: items), "One")
    }
}
