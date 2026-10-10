import Foundation
import NeosDomain

/// Undoing one optimistic queue removal without disturbing the others.
enum QueueRollback {
    // HEOS numbers a queue from 1 in play order, so qid order is queue order until the next reload.
    static func reinsert(_ item: QueueItem, into queue: inout [QueueItem]) {
        guard !queue.contains(where: { $0.qid == item.qid }) else { return }
        let index = queue.firstIndex { $0.qid > item.qid } ?? queue.count
        queue.insert(item, at: index)
    }
}
