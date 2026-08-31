import XCTest
@testable import Neos
import NeosDomain

final class MenuBarIconTests: XCTestCase {

    func testPlayingInksTheRecordSolid() {
        XCTAssertEqual(menuBarVinyl(connectionState: .connected, isPlaying: true), .playing)
    }

    func testConnectedButIdleShowsTheRecordAtRest() {
        XCTAssertEqual(menuBarVinyl(connectionState: .connected, isPlaying: false), .idle)
    }

    func testDisconnectedShowsTheBareRing() {
        XCTAssertEqual(menuBarVinyl(connectionState: .disconnected, isPlaying: false), .offline)
    }

    /// A drop keeps the last play state; the ring must still say there is nothing to control.
    func testReconnectingShowsTheBareRingEvenWhilePlaying() {
        XCTAssertEqual(menuBarVinyl(connectionState: .reconnecting, isPlaying: true), .offline)
    }

    func testConnectingShowsTheBareRing() {
        XCTAssertEqual(menuBarVinyl(connectionState: .connecting, isPlaying: false), .offline)
    }

    /// The menu bar owns the colour; a non-template image would stay black on a dark bar.
    func testEveryStateRendersATemplateImage() {
        for vinyl in [MenuBarVinyl.offline, .idle, .playing] {
            let image = vinyl.image()
            XCTAssertTrue(image.isTemplate, "\(vinyl) must be a template image")
            XCTAssertEqual(image.size, NSSize(width: 16, height: 16))
        }
    }
}
