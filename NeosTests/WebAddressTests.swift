import XCTest
@testable import Neos

final class WebAddressTests: XCTestCase {
    func testAnHTTPSAddressIsKept() {
        XCTAssertEqual(URL(webAddress: "https://example.com/stream.mp3")?.absoluteString, "https://example.com/stream.mp3")
    }

    func testThePastedSpaceAroundAnAddressIsDropped() {
        XCTAssertEqual(URL(webAddress: "  http://example.com/a.png\n")?.absoluteString, "http://example.com/a.png")
    }

    func testTheSchemeMayBeInCapitals() {
        XCTAssertNotNil(URL(webAddress: "HTTP://example.com"))
    }

    func testAnotherSchemeIsRefused() {
        XCTAssertNil(URL(webAddress: "ftp://example.com/a.png"))
    }

    func testTextWithoutASchemeIsRefused() {
        XCTAssertNil(URL(webAddress: "example.com/stream"))
    }

    func testNothingTypedIsRefused() {
        XCTAssertNil(URL(webAddress: "   "))
    }
}
