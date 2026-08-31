import XCTest
@testable import Neos
import NeosDomain

final class DisplayTitleTests: XCTestCase {

    func testStreamURLFallsBackToHost() {
        XCTAssertEqual("https://icecast.radiofrance.fr/fip-hifi.aac".displayTitle, "icecast.radiofrance.fr")
    }

    func testHTTPStreamURLFallsBackToHost() {
        XCTAssertEqual("http://stream.example.org:8000/live".displayTitle, "stream.example.org")
    }

    func testWWWPrefixIsStripped() {
        XCTAssertEqual("https://www.example.com/stream.mp3".displayTitle, "example.com")
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
        XCTAssertEqual("HTTPS://Example.com/a.mp3".displayTitle, "Example.com")
    }

    func testBrowseItemUsesItsName() {
        let item = BrowseItem(
            name: "https://icecast.radiofrance.fr/fip-hifi.aac",
            imageURL: "",
            type: .station,
            playable: true,
            browsable: false
        )

        XCTAssertEqual(item.displayTitle, "icecast.radiofrance.fr")
    }
}
