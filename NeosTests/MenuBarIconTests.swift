import XCTest
@testable import Neos
import NeosDomain

final class MenuBarIconTests: XCTestCase {

    func testPlayingShowsActiveSpeaker() {
        XCTAssertEqual(menuBarIconName(connectionState: .connected, isPlaying: true), "speaker.wave.2.fill")
    }

    func testConnectedButIdleShowsFilledSpeaker() {
        XCTAssertEqual(menuBarIconName(connectionState: .connected, isPlaying: false), "hifispeaker.fill")
    }

    func testDisconnectedShowsOutlineSpeaker() {
        XCTAssertEqual(menuBarIconName(connectionState: .disconnected, isPlaying: false), "hifispeaker")
    }

    func testReconnectingShowsOutlineSpeakerEvenWhilePlaying() {
        XCTAssertEqual(menuBarIconName(connectionState: .reconnecting, isPlaying: true), "hifispeaker")
    }

    func testConnectingShowsOutlineSpeaker() {
        XCTAssertEqual(menuBarIconName(connectionState: .connecting, isPlaying: false), "hifispeaker")
    }
}
