import XCTest
@testable import Neos
import NeosDomain

final class DisplayTitleTests: XCTestCase {

    func testStreamURLIsShownWhole() {
        XCTAssertEqual(
            "https://icecast.radiofrance.fr/fip-hifi.aac".displayTitle,
            "https://icecast.radiofrance.fr/fip-hifi.aac"
        )
    }

    /// Showing only the file name made these two read as the same station.
    func testTwoHostsServingTheSameFileNameStayDistinct() {
        let one = "http://a.example.com/classic.aac".displayTitle
        let two = "http://b.example.com/classic.aac".displayTitle
        XCTAssertNotEqual(one, two)
    }

    func testTwoStreamsOnOneHostStayDistinct() {
        let jazz = "http://mscp3.live-streams.nl:8340/jazz-flac.flac".displayTitle
        let classical = "http://mscp3.live-streams.nl:8340/class-flac.flac".displayTitle
        XCTAssertNotEqual(jazz, classical)
    }

    func testOrdinaryNameIsUnchanged() {
        XCTAssertEqual("FIP Rock".displayTitle, "FIP Rock")
    }

    func testSurroundingWhitespaceIsTrimmed() {
        XCTAssertEqual("  FIP Rock \n".displayTitle, "FIP Rock")
    }

    func testEmptyNameIsUnchanged() {
        XCTAssertEqual("".displayTitle, "")
    }

    func testBrowseItemUsesItsName() {
        let item = BrowseItem(
            name: "https://icecast.radiofrance.fr/fip-hifi.aac",
            imageURL: "",
            type: .station,
            playable: true,
            browsable: false
        )

        XCTAssertEqual(item.displayTitle, "https://icecast.radiofrance.fr/fip-hifi.aac")
    }
}
