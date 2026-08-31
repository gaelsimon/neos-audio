import XCTest
@testable import Neos
import NeosDomain

final class DisplayTitleTests: XCTestCase {

    func testStreamURLKeepsTheSegmentThatIdentifiesIt() {
        XCTAssertEqual("https://icecast.radiofrance.fr/fip-hifi.aac".displayTitle, "fip-hifi.aac")
    }

    /// The host alone collapses every stream a station serves into one indistinguishable title.
    func testTwoStreamsOnOneHostStayDistinct() {
        let jazz = "http://mscp3.live-streams.nl:8340/jazz-flac.flac".displayTitle
        let classical = "http://mscp3.live-streams.nl:8340/class-flac.flac".displayTitle
        XCTAssertEqual(jazz, "jazz-flac.flac")
        XCTAssertEqual(classical, "class-flac.flac")
        XCTAssertNotEqual(jazz, classical)
    }

    func testHTTPStreamURLKeepsItsSegment() {
        XCTAssertEqual("http://stream.example.org:8000/live".displayTitle, "live")
    }

    /// No path to distinguish anything: the host is all there is.
    func testPathlessURLFallsBackToHost() {
        XCTAssertEqual("http://stream.example.org:8000".displayTitle, "stream.example.org")
    }

    func testTrailingSlashFallsBackToHost() {
        XCTAssertEqual("https://www.example.com/".displayTitle, "example.com")
    }

    func testDeepPathUsesTheLastSegment() {
        XCTAssertEqual("https://cdn.example.com/eu/west/fip-rock.aac".displayTitle, "fip-rock.aac")
    }

    func testWWWPrefixIsStrippedWhenTheHostIsUsed() {
        XCTAssertEqual("https://www.example.com".displayTitle, "example.com")
    }

    func testOrdinaryNameIsUnchanged() {
        XCTAssertEqual("FIP Rock".displayTitle, "FIP Rock")
    }

    func testNameMentioningHTTPIsUnchanged() {
        XCTAssertEqual("The http Song".displayTitle, "The http Song")
    }

    func testMalformedURLKeepsOriginalName() {
        XCTAssertEqual("https://".displayTitle, "https://")
    }

    func testEmptyNameIsUnchanged() {
        XCTAssertEqual("".displayTitle, "")
    }

    func testUppercaseSchemeIsRecognized() {
        XCTAssertEqual("HTTPS://Example.com/a.mp3".displayTitle, "a.mp3")
    }

    func testBrowseItemUsesItsName() {
        let item = BrowseItem(
            name: "https://icecast.radiofrance.fr/fip-hifi.aac",
            imageURL: "",
            type: .station,
            playable: true,
            browsable: false
        )

        XCTAssertEqual(item.displayTitle, "fip-hifi.aac")
    }
}
