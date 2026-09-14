import Foundation
import NeosDomain

/// Undoing one optimistic queue removal without disturbing the others.
enum QueueRollback {
    /// Puts an item back where it was. The index is clamped, because removals that succeeded
    /// while this one was in flight have already shortened the queue.
    static func reinsert(_ item: QueueItem, at index: Int, into queue: inout [QueueItem]) {
        guard !queue.contains(where: { $0.qid == item.qid }) else { return }
        queue.insert(item, at: min(max(index, 0), queue.count))
    }
}
