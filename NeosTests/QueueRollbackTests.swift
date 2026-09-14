import XCTest
@testable import Neos
import NeosDomain

final class QueueRollbackTests: XCTestCase {
    private func item(_ qid: Int) -> QueueItem {
        QueueItem(qid: qid, song: "Track \(qid)")
    }

    func testFailedRemovalComesBackAtItsIndex() {
        var queue = [item(2), item(3)]

        QueueRollback.reinsert(item(1), at: 0, into: &queue)

        XCTAssertEqual(queue.map(\.qid), [1, 2, 3])
    }

    /// The case a whole-snapshot rollback got wrong: one removal succeeded while another failed.
    func testARollbackDoesNotResurrectARemovalThatSucceeded() {
        // Queue was [1, 2, 3]; removing 2 succeeded, removing 1 is about to fail.
        var queue = [item(3)]

        QueueRollback.reinsert(item(1), at: 0, into: &queue)

        XCTAssertEqual(queue.map(\.qid), [1, 3], "item 2 was removed on the device and must stay gone")
    }

    func testAnIndexPastTheEndLandsAtTheEnd() {
        var queue = [item(3)]

        QueueRollback.reinsert(item(9), at: 7, into: &queue)

        XCTAssertEqual(queue.map(\.qid), [3, 9])
    }

    func testAnItemAlreadyBackIsNotDuplicated() {
        var queue = [item(1), item(2)]

        QueueRollback.reinsert(item(1), at: 0, into: &queue)

        XCTAssertEqual(queue.map(\.qid), [1, 2])
    }
}
