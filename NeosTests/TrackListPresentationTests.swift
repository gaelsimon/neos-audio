import XCTest
@testable import Neos
import NeosDomain

final class TrackListPresentationTests: XCTestCase {

    private func track(_ name: String, album: String?) -> BrowseItem {
        BrowseItem(name: name, type: .song, mid: name, playable: true, album: album)
    }

    func testAnAlbumAndAPlaylistNumberTheirRows() {
        for type in [MediaType.album, .playlist] {
            let target = BrowseTarget(sid: 5, cid: "c", name: "n", mediaType: type)
            XCTAssertTrue(TrackListPresentation.numbersRows(target: target), "\(type)")
        }
    }

    func testStationsAndFoldersHaveNoRowNumbers() {
        XCTAssertFalse(TrackListPresentation.numbersRows(target: BrowseTarget(sid: 1028, name: "Favorites")))
        XCTAssertFalse(TrackListPresentation.numbersRows(target: BrowseTarget(sid: 5, cid: "c", name: "Folder", mediaType: .container)))
        XCTAssertFalse(TrackListPresentation.numbersRows(target: nil))
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

    // MARK: - Track Lists

    private func target(_ type: MediaType, imageURL: String = "") -> BrowseTarget {
        BrowseTarget(sid: 1, cid: "c1", name: "Page", imageURL: imageURL, mediaType: type)
    }

    private func folder(_ name: String, type: MediaType = .album) -> BrowseItem {
        BrowseItem(name: name, type: type, cid: name, browsable: true)
    }

    private func station(_ name: String) -> BrowseItem {
        BrowseItem(name: name, type: .station, mid: name, playable: true)
    }

    func testAnAlbumIsATrackListBeforeItsRowsArrive() {
        XCTAssertTrue(TrackListPresentation.isTrackList(target: target(.album), items: []))
    }

    func testAnArtistIsNeverATrackList() {
        XCTAssertFalse(TrackListPresentation.isTrackList(target: target(.artist), items: [track("a", album: nil)]))
    }

    func testAContainerOfTracksIsATrackList() {
        let items = [track("a", album: nil), track("b", album: nil), folder("c")]
        XCTAssertTrue(TrackListPresentation.isTrackList(target: target(.container), items: items))
    }

    func testAContainerOfFoldersIsNotATrackList() {
        let items = [folder("a"), folder("b"), folder("c"), track("d", album: nil)]
        XCTAssertFalse(TrackListPresentation.isTrackList(target: target(.container), items: items))
    }

    func testNothingLoadedIsNotATrackList() {
        XCTAssertFalse(TrackListPresentation.isTrackList(target: nil, items: []))
    }

    // MARK: - Artwork Header

    func testAnAlbumOpensOnItsArtworkWhileLoading() {
        XCTAssertTrue(TrackListPresentation.opensOnArtwork(target: target(.album), items: []))
    }

    func testAFolderOfAlbumsOpensOnItsList() {
        let items = [folder("Midnight Opera"), folder("Analog Dreams")]
        XCTAssertFalse(TrackListPresentation.opensOnArtwork(target: target(.container), items: items))
    }

    func testAFolderOfStationsOpensOnItsList() {
        let items = [station("Pulse FM"), station("Eclectic FM")]
        XCTAssertFalse(TrackListPresentation.opensOnArtwork(target: target(.container), items: items))
    }

    func testAFolderWithItsOwnPictureOpensOnIt() {
        let items = [folder("Midnight Opera")]
        XCTAssertTrue(TrackListPresentation.opensOnArtwork(target: target(.artist, imageURL: "https://x/a.jpg"), items: items))
    }

    func testAContainerOfTracksOpensOnItsArtwork() {
        let items = [track("a", album: nil), track("b", album: nil)]
        XCTAssertTrue(TrackListPresentation.opensOnArtwork(target: target(.container), items: items))
    }
}
