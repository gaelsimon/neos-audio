import XCTest
@testable import Neos

final class FolderSymbolTests: XCTestCase {
    func testAFolderOfAlbumsShowsTheAlbumSymbol() {
        XCTAssertEqual(FolderSymbol.name(for: "Albums"), DS.Icons.album)
    }

    func testAFrenchNameStillMatches() {
        XCTAssertEqual(FolderSymbol.name(for: "Artistes"), DS.Icons.person)
    }

    func testCaseDoesNotMatter() {
        XCTAssertEqual(FolderSymbol.name(for: "MY PLAYLISTS"), DS.Icons.playlists)
    }

    func testANameThatSaysNothingKeepsTheFolder() {
        XCTAssertNil(FolderSymbol.name(for: "Flow"))
    }
}
