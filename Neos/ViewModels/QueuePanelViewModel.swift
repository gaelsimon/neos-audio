import Foundation
import SwiftUI
import NeosDomain

enum RecentItem: Identifiable {
    case queue(QueueItem)
    case history(BrowseItem)

    var id: String {
        switch self {
        case .queue(let q): return "q-\(q.qid)"
        case .history(let b): return "h-\(b.mid ?? b.name)"
        }
    }

    var name: String {
        switch self {
        case .queue(let q): return q.song
        case .history(let b): return b.name
        }
    }

    var artist: String {
        switch self {
        case .queue(let q): return q.artist
        case .history(let b): return b.artist ?? ""
        }
    }

    var imageURL: String {
        switch self {
        case .queue(let q): return q.imageURL
        case .history(let b): return b.imageURL
        }
    }
}

@Observable
@MainActor
final class QueuePanelViewModel {
    private let service: any AudioService
    private let state: AppState

    // MARK: - Properties

    var historyTracks: [BrowseItem] = []
    var historyStations: [BrowseItem] = []
    var isLoadingHistory = false
    /// Increments each time history data finishes loading; view uses this to scroll.
    private(set) var historyVersion: Int = 0
    private let historyTask = CancellableTaskHandle()
    private let historyPageSize = 10

    // Cached display data; updated explicitly to avoid re-computing on every state change
    private(set) var nowPlayingQueueItem: QueueItem?
    private(set) var upNextItems: [QueueItem] = []
    private(set) var recentSongs: [RecentItem] = []
    private(set) var recentStations: [BrowseItem] = []
    private(set) var isEmpty: Bool = true

    init(service: any AudioService, state: AppState) {
        self.service = service
        self.state = state
    }

    // MARK: - Cache Refresh

    /// Recompute cached display data. Call when queue, nowPlaying, or history changes.
    func refreshDisplayData() {
        let nowMid = state.nowPlaying.mid
        let nowQid = state.nowPlaying.qid
        let isStation = state.nowPlaying.station != nil

        // nowPlayingQueueItem
        if !isStation, let qid = nowQid {
            nowPlayingQueueItem = state.queue.first { $0.qid == qid }
        } else {
            nowPlayingQueueItem = nil
        }

        // upNextItems
        if let qid = nowQid,
           let idx = state.queue.firstIndex(where: { $0.qid == qid }) {
            upNextItems = Array(state.queue.suffix(from: idx + 1))
        } else {
            upNextItems = []
        }

        // recentSongs
        let maxRecent = 10
        var played: [RecentItem] = []
        if let qid = nowQid,
           let idx = state.queue.firstIndex(where: { $0.qid == qid }) {
            played = state.queue.prefix(upTo: idx).suffix(maxRecent).map { .queue($0) }
        }
        let remaining = maxRecent - played.count
        if remaining > 0 {
            let playedMids = Set(state.queue.map(\.mid).filter { !$0.isEmpty })
            let filtered = historyTracks.filter { item in
                guard let mid = item.mid else { return true }
                return mid != nowMid && !playedMids.contains(mid)
            }.reversed().suffix(remaining)
            played = Array(filtered.map { .history($0) }) + played
        }
        recentSongs = played

        // recentStations
        recentStations = historyStations.filter { item in
            guard let mid = item.mid else { return true }
            return mid != nowMid
        }.reversed().suffix(10).reversed()

        // isEmpty
        isEmpty = recentSongs.isEmpty
            && recentStations.isEmpty
            && nowPlayingQueueItem == nil
            && nowMid.isEmpty
            && upNextItems.isEmpty
    }

    // MARK: - History Loading

    func loadHistory() {
        // Only show loading spinner on first fetch; keep stale data visible on refresh
        let hasExistingData = !historyTracks.isEmpty || !historyStations.isEmpty
        if !hasExistingData {
            isLoadingHistory = true
        }
        historyTask.replace(with: Task {
            defer {
                if isLoadingHistory {
                    withAnimation(.easeIn(duration: 0.3)) {
                        isLoadingHistory = false
                    }
                }
            }
            do {
                let history = try await HistoryLoader.load(
                    service: service, trackLimit: historyPageSize, stationLimit: historyPageSize
                )
                guard !Task.isCancelled else { return }

                // Batch-assign both arrays together to prevent intermediate view updates
                historyTracks = history.tracks
                historyStations = history.stations
                historyVersion += 1
                refreshDisplayData()
            } catch {
                state.reportNonFatal(source: "QueuePanelViewModel", message: "Failed to load history: \(error.localizedDescription)")
            }
        })
    }

    // MARK: - Track Change Refresh

    func onTrackChanged() {
        refreshDisplayData()
        loadHistory()
    }

    // MARK: - Actions

    func playRecentItem(_ item: RecentItem) {
        switch item {
        case .queue(let q):
            playQueueItem(q)
        case .history(let b):
            let sid = b.sid ?? 1026
            let cid = b.cid ?? ""
            Task {
                do {
                    try await PlaybackRouter.play(
                        b, sid: sid, cid: cid,
                        service: service, state: state
                    )
                } catch {
                    state.showToast(
                        error.localizedDescription,
                        icon: DS.Icons.warning,
                        style: .error
                    )
                }
            }
        }
    }

    func playQueueItem(_ item: QueueItem) {
        guard let pid = state.selectedPlayerID else { return }
        Task {
            do {
                try await service.playQueueItem(pid: pid, qid: item.qid)
            } catch {
                state.error = .queueFailed(error.localizedDescription)
            }
        }
    }

    func playHistoryStation(_ item: BrowseItem) {
        let sid = item.sid ?? 1026
        let cid = item.cid ?? ""
        Task {
            do {
                try await PlaybackRouter.play(
                    item, sid: sid, cid: cid,
                    service: service, state: state
                )
            } catch {
                state.showToast(
                    error.localizedDescription,
                    icon: DS.Icons.warning,
                    style: .error
                )
            }
        }
    }

    func removeQueueItem(_ item: QueueItem) {
        guard let pid = state.selectedPlayerID else { return }
        // Optimistic removal
        let previousQueue = state.queue
        state.playback.queue.removeAll { $0.qid == item.qid }
        refreshDisplayData()
        Task {
            do {
                try await service.removeFromQueue(pid: pid, qids: [item.qid])
            } catch {
                guard state.selectedPlayerID == pid else { return }
                state.playback.queue = previousQueue
                refreshDisplayData()
                state.error = .queueFailed(error.localizedDescription)
            }
        }
    }

    /// Loads history only if it hasn't been fetched yet. Called when switching to the
    /// "Recently Played" tab; avoids redundant fetches if data is already present.
    func loadHistoryIfNeeded() {
        guard historyTracks.isEmpty, historyStations.isEmpty, !isLoadingHistory else { return }
        loadHistory()
    }

    func onPanelOpen() {
        refreshDisplayData()
    }
}
