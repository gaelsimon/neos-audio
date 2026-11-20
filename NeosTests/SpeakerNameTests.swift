import XCTest
@testable import Neos
import NeosDomain

@MainActor
final class SpeakerNameTests: XCTestCase {
    func testASingleSpeakerGoesUnnamed() {
        let state = AppState()
        state.players = [Player(pid: 1, name: "Den")]
        state.selectedPlayerID = 1

        XCTAssertNil(state.speakerNameIfChoice)
    }

    func testWithAChoiceTheSelectedSpeakerIsNamed() {
        let state = AppState()
        state.players = [Player(pid: 1, name: "Den"), Player(pid: 2, name: "Bath")]
        state.selectedPlayerID = 2

        XCTAssertEqual(state.speakerNameIfChoice, "Bath")
    }
}
