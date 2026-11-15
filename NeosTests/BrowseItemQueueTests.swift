import XCTest
@testable import Neos
import NeosDomain

final class BrowseItemQueueTests: XCTestCase {
    func testATrackCanJoinTheQueue() {
        XCTAssertTrue(BrowseItem(name: "Track", type: .song, mid: "m", playable: true).canJoinQueue)
    }

    func testAPlayableAlbumCanJoinTheQueue() {
        XCTAssertTrue(BrowseItem(name: "Album", type: .album, cid: "c", playable: true, browsable: true).canJoinQueue)
    }

    func testAStationCannot() {
        XCTAssertFalse(BrowseItem(name: "Radio", type: .station, mid: "s", playable: true).canJoinQueue)
    }

    func testAFolderThatDoesNotPlayCannot() {
        XCTAssertFalse(BrowseItem(name: "Folder", type: .container, cid: "c", browsable: true).canJoinQueue)
    }
}
