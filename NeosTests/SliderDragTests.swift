import XCTest
@testable import Neos

final class SliderDragTests: XCTestCase {
    private let drag = SliderDrag(bounds: 0...100, width: 200)

    func testAClickPutsTheValueUnderThePointer() {
        XCTAssertEqual(drag.level(at: 150), 75)
    }

    func testAClickPastTheEndStopsAtTheBound() {
        XCTAssertEqual(drag.level(at: 260), 100)
    }

    func testATouchWithoutMovingKeepsTheValue() {
        XCTAssertEqual(drag.level(from: 20, movedBy: 0), 20)
    }

    func testADragMovesTheValueByTheDistance() {
        XCTAssertEqual(drag.level(from: 20, movedBy: 50), 45)
    }

    func testADragLeftStopsAtTheLowerBound() {
        XCTAssertEqual(drag.level(from: 20, movedBy: -120), 0)
    }

    func testADragFollowsALimitedRange() {
        let limited = SliderDrag(bounds: 0...40, width: 200)

        XCTAssertEqual(limited.level(from: 10, movedBy: 100), 30)
    }

    func testAZeroWidthTrackKeepsTheStart() {
        let collapsed = SliderDrag(bounds: 0...100, width: 0)

        XCTAssertEqual(collapsed.level(from: 30, movedBy: 40), 30)
    }
}
