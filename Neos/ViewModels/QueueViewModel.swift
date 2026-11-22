import Foundation
import NeosDomain

@Observable
@MainActor
final class QueueViewModel {
    private let service: any AudioService
    private let state: AppState
    private let fetchQueue: (_ pid: Int) async throws -> [QueueItem]
    private(set) var isLoadingQueue = false
    private(set) var isClearing = false

    private let queueLoadTask = CancellableTaskHandle()
    private let leftoverStreamsTask = CancellableTaskHandle()
    private let queueTracker = RequestTracker()

    init(
        service: any AudioService,
        state: AppState,
        getQueue: ((_ pid: Int) async throws -> [QueueItem])? = nil
    ) {
        self.service = service
        self.state = state
        self.fetchQueue = getQueue ?? { pid in
            try await service.getQueue(pid: pid, range: nil)
        }
    }

    func loadQueue() {
        guard let pid = state.selectedPlayerID else { return }
        let requestID = queueTracker.next()
        isLoadingQueue = true
        queueLoadTask.replace(with: Task {
            do {
                let items = try await fetchQueue(pid)
                guard queueTracker.isCurrent(requestID), !Task.isCancelled, state.selectedPlayerID == pid else { return }
                state.setQueue(items)
            } catch {
                guard queueTracker.isCurrent(requestID), !Task.isCancelled, state.selectedPlayerID == pid else { return }
                state.setError(.queueFailed(error.localizedDescription))
            }
            guard queueTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isLoadingQueue = false
        })
    }

    /// A radio played by its address leaves a queue entry that the speaker never removes or names.
    @discardableResult
    func removeLeftoverStreams() -> Task<Void, Never>? {
        guard let pid = state.selectedPlayerID else { return nil }
        let sweep = Task {
            guard let queue = try? await fetchQueue(pid), !Task.isCancelled, state.selectedPlayerID == pid else { return }
            // Another play is on its way and moves the entries, so their places are no longer these.
            guard !state.isLoadingTrack, !state.playback.awaitsRadioStart else { return }
            let playing = state.nowPlaying
            let kept = playing.playsFromQueue ? playing.qid : nil
            if playing.isUnnamedStream, queue.first(where: { $0.qid == kept })?.isLeftByAStream != true { return }
            let leftovers = queue.filter { $0.isLeftByAStream && $0.qid != kept }.map(\.qid)
            guard !leftovers.isEmpty else { return }
            try? await service.removeFromQueue(pid: pid, qids: leftovers)
        }
        leftoverStreamsTask.replace(with: sweep)
        return sweep
    }

    func playItem(_ item: QueueItem) {
        guard let pid = state.selectedPlayerID else { return }
        Task {
            do {
                try await service.playQueueItem(pid: pid, qid: item.qid)
            } catch {
                state.setError(.queueFailed(error.localizedDescription))
            }
        }
    }

    func removeItem(_ item: QueueItem) {
        guard let pid = state.selectedPlayerID else { return }
        guard let index = state.queue.firstIndex(where: { $0.qid == item.qid }) else { return }
        state.playback.queue.remove(at: index)
        Task {
            do {
                try await service.removeFromQueue(pid: pid, qids: [item.qid])
            } catch {
                guard state.selectedPlayerID == pid else { return }
                QueueRollback.reinsert(item, into: &state.playback.queue)
                state.setError(.queueFailed(error.localizedDescription))
            }
        }
    }

    func clearQueue() {
        guard let pid = state.selectedPlayerID else { return }
        isClearing = true
        // Optimistic
        let previousQueue = state.queue
        state.playback.queue = []
        Task {
            do {
                try await service.clearQueue(pid: pid)
            } catch {
                guard state.selectedPlayerID == pid else { return }
                state.playback.queue = previousQueue
                state.setError(.queueFailed(error.localizedDescription))
            }
            isClearing = false
        }
    }
}
