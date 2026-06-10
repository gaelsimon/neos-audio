import Foundation
import NeosDomain

@Observable
@MainActor
final class QueueViewModel {
    private let service: any AudioService
    private let state: AppState
    private let fetchQueue: (_ pid: Int, _ range: ClosedRange<Int>?) async throws -> [QueueItem]
    private(set) var isLoadingQueue = false
    private(set) var isLoadingMore = false
    private(set) var isClearing = false

    private var currentOffset: Int = 0
    private let pageSize: Int = 100
    private(set) var hasMore: Bool = false
    private let queueLoadTask = CancellableTaskHandle()
    private let queueTracker = RequestTracker()

    init(
        service: any AudioService,
        state: AppState,
        getQueue: ((_ pid: Int, _ range: ClosedRange<Int>?) async throws -> [QueueItem])? = nil
    ) {
        self.service = service
        self.state = state
        self.fetchQueue = getQueue ?? { pid, range in
            try await service.getQueue(pid: pid, range: range)
        }
    }

    func loadQueue() {
        guard let pid = state.selectedPlayerID else { return }
        let requestID = queueTracker.next()
        isLoadingQueue = true
        currentOffset = 0
        hasMore = false
        queueLoadTask.replace(with: Task {
            do {
                let items = try await fetchQueue(pid, 0...(pageSize - 1))
                guard queueTracker.isCurrent(requestID), !Task.isCancelled, state.selectedPlayerID == pid else { return }
                state.playback.queue = items
                currentOffset = items.count
                hasMore = items.count == pageSize
            } catch {
                guard queueTracker.isCurrent(requestID), !Task.isCancelled, state.selectedPlayerID == pid else { return }
                state.error = .queueFailed(error.localizedDescription)
            }
            guard queueTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isLoadingQueue = false
        })
    }

    func loadMoreQueue() {
        guard !isLoadingMore, !isLoadingQueue, hasMore else { return }
        guard let pid = state.selectedPlayerID else { return }
        let requestID = queueTracker.next()
        isLoadingMore = true
        let offset = currentOffset
        Task {
            do {
                let items = try await fetchQueue(pid, offset...(offset + pageSize - 1))
                guard queueTracker.isCurrent(requestID), !Task.isCancelled, state.selectedPlayerID == pid else { return }
                if !items.isEmpty {
                    state.playback.queue.append(contentsOf: items)
                    currentOffset = state.queue.count
                    hasMore = items.count == pageSize
                } else {
                    hasMore = false
                }
            } catch {
                // Silently fail on load more
            }
            guard queueTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isLoadingMore = false
        }
    }

    func playItem(_ item: QueueItem) {
        guard let pid = state.selectedPlayerID else { return }
        Task {
            do {
                try await service.playQueueItem(pid: pid, qid: item.qid)
            } catch {
                state.error = .queueFailed(error.localizedDescription)
            }
        }
    }

    func removeItem(_ item: QueueItem) {
        guard let pid = state.selectedPlayerID else { return }
        // Optimistic removal
        let previousQueue = state.queue
        state.playback.queue.removeAll { $0.qid == item.qid }
        currentOffset = state.playback.queue.count
        Task {
            do {
                try await service.removeFromQueue(pid: pid, qids: [item.qid])
            } catch {
                guard state.selectedPlayerID == pid else { return }
                state.playback.queue = previousQueue
                currentOffset = previousQueue.count
                state.error = .queueFailed(error.localizedDescription)
            }
        }
    }

    func clearQueue() {
        guard let pid = state.selectedPlayerID else { return }
        isClearing = true
        // Optimistic
        let previousQueue = state.queue
        let previousHasMore = hasMore
        state.playback.queue = []
        currentOffset = 0
        hasMore = false
        Task {
            do {
                try await service.clearQueue(pid: pid)
            } catch {
                guard state.selectedPlayerID == pid else { return }
                state.playback.queue = previousQueue
                currentOffset = previousQueue.count
                hasMore = previousHasMore
                state.error = .queueFailed(error.localizedDescription)
            }
            isClearing = false
        }
    }
}
