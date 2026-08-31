import XCTest
import NeosDomain
@testable import Neos

final class ConnectionPresentationTests: XCTestCase {

    func testFirstConnectionShowsTheSplashAndNoContent() {
        let presentation = ConnectionPresentation(
            connectionState: .connecting,
            hasEstablishedSession: false,
            isHoldingConnectedSplash: false
        )

        XCTAssertTrue(presentation.showsSplash)
        XCTAssertFalse(presentation.showsContent)
        XCTAssertFalse(presentation.showsDiscovery)
        XCTAssertFalse(presentation.showsReconnectingBanner)
    }

    func testReconnectingKeepsTheContentAndShowsTheBanner() {
        let presentation = ConnectionPresentation(
            connectionState: .reconnecting,
            hasEstablishedSession: true,
            isHoldingConnectedSplash: false
        )

        XCTAssertTrue(presentation.showsContent)
        XCTAssertTrue(presentation.showsReconnectingBanner)
        XCTAssertFalse(presentation.showsSplash)
        XCTAssertFalse(presentation.showsDiscovery)
    }

    func testConnectedShowsContentOnly() {
        let presentation = ConnectionPresentation(
            connectionState: .connected,
            hasEstablishedSession: true,
            isHoldingConnectedSplash: false
        )

        XCTAssertTrue(presentation.showsContent)
        XCTAssertFalse(presentation.showsReconnectingBanner)
        XCTAssertFalse(presentation.showsSplash)
        XCTAssertFalse(presentation.showsDiscovery)
    }

    func testConnectedHoldKeepsTheSplashOverTheContent() {
        let presentation = ConnectionPresentation(
            connectionState: .connected,
            hasEstablishedSession: true,
            isHoldingConnectedSplash: true
        )

        XCTAssertTrue(presentation.showsSplash)
        XCTAssertTrue(presentation.showsContent)
    }

    func testDisconnectedWithoutASessionShowsDiscovery() {
        let presentation = ConnectionPresentation(
            connectionState: .disconnected,
            hasEstablishedSession: false,
            isHoldingConnectedSplash: false
        )

        XCTAssertTrue(presentation.showsDiscovery)
        XCTAssertFalse(presentation.showsContent)
        XCTAssertFalse(presentation.showsSplash)
    }
}
