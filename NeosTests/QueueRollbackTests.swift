import XCTest
@testable import Neos
import NeosDomain

final class QueueRollbackTests: XCTestCase {
    private func item(_ qid: Int) -> QueueItem {
        QueueItem(qid: qid, song: "Track \(qid)")
    }

    func testFailedRemovalComesBackInPlace() {
        var queue = [item(1), item(3)]

        QueueRollback.reinsert(item(2), into: &queue)

        XCTAssertEqual(queue.map(\.qid), [1, 2, 3])
    }

    func testARollbackDoesNotResurrectARemovalThatSucceeded() {
        // Queue was [1, 2, 3]; removing 2 succeeded, removing 1 is about to fail.
        var queue = [item(3)]

        QueueRollback.reinsert(item(1), into: &queue)

        XCTAssertEqual(queue.map(\.qid), [1, 3])
    }

    func testAnEarlierSuccessfulRemovalDoesNotShiftTheRollback() {
        // Queue was [1, 2, 3, 4]; 2 then 1 were removed, 1 succeeded and 2 fails.
        var queue = [item(3), item(4)]

        QueueRollback.reinsert(item(2), into: &queue)

        XCTAssertEqual(queue.map(\.qid), [2, 3, 4])
    }

    func testTwoFailedRemovalsComeBackInOrderWhicheverFailsFirst() {
        var laterFirst = [item(1), item(4)]
        QueueRollback.reinsert(item(3), into: &laterFirst)
        QueueRollback.reinsert(item(2), into: &laterFirst)

        var earlierFirst = [item(1), item(4)]
        QueueRollback.reinsert(item(2), into: &earlierFirst)
        QueueRollback.reinsert(item(3), into: &earlierFirst)

        XCTAssertEqual([laterFirst.map(\.qid), earlierFirst.map(\.qid)], [[1, 2, 3, 4], [1, 2, 3, 4]])
    }

    func testTheLastItemComesBackAtTheEnd() {
        var queue = [item(3)]

        QueueRollback.reinsert(item(9), into: &queue)

        XCTAssertEqual(queue.map(\.qid), [3, 9])
    }

    func testAnItemAlreadyBackIsNotDuplicated() {
        var queue = [item(1), item(2)]

        QueueRollback.reinsert(item(1), into: &queue)

        XCTAssertEqual(queue.map(\.qid), [1, 2])
    }
}
