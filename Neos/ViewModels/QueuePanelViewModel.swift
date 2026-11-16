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

    /// History mixes services under one source, so the link is derived from the item itself.
    var externalLink: ExternalLinkMenu? {
        switch self {
        case .queue(let q): return ExternalLinkMenu.make(for: q, sourceName: nil)
        case .history(let b): return ExternalLinkMenu.make(for: b, sourceName: nil)
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
        let isStation = state.nowPlaying.type == .station
        // A speaker gives a station the queue id 1, which is no place in the queue.
        let nowIndex = isStation ? nil : state.nowPlaying.qid.flatMap { qid in
            state.queue.firstIndex { $0.qid == qid }
        }

        nowPlayingQueueItem = state.nowPlaying.station == nil ? nowIndex.map { state.queue[$0] } : nil

        if let nowIndex {
            upNextItems = Array(state.queue.suffix(from: nowIndex + 1))
        } else {
            upNextItems = isStation ? state.queue : []
        }

        let maxRecent = 10
        var played: [RecentItem] = []
        if let nowIndex {
            played = state.queue.prefix(upTo: nowIndex).suffix(maxRecent).map { .queue($0) }
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

        recentStations = historyStations.filter { item in
            guard let mid = item.mid else { return true }
            return mid != nowMid
        }.reversed().suffix(10).reversed()

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

    /// The history is refetched only while the panel shows it.
    func onTrackChanged() {
        refreshDisplayData()
        guard state.isQueuePanelOpen else { return }
        loadHistory()
    }

    // MARK: - Actions

    func playRecentItem(_ item: RecentItem) {
        switch item {
        case .queue(let q): playQueueItem(q)
        case .history(let b): playHistoryItem(b)
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

    func playHistoryItem(_ item: BrowseItem) {
        let sid = item.sid ?? HEOSConstants.historySID
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
        guard let index = state.queue.firstIndex(where: { $0.qid == item.qid }) else { return }
        state.playback.queue.remove(at: index)
        refreshDisplayData()
        Task {
            do {
                try await service.removeFromQueue(pid: pid, qids: [item.qid])
            } catch {
                guard state.selectedPlayerID == pid else { return }
                QueueRollback.reinsert(item, into: &state.playback.queue)
                refreshDisplayData()
                state.error = .queueFailed(error.localizedDescription)
            }
        }
    }

    func loadHistoryIfNeeded() {
        guard historyTracks.isEmpty, historyStations.isEmpty, !isLoadingHistory else { return }
        loadHistory()
    }

    func onPanelOpen() {
        refreshDisplayData()
        reloadQueueIfNeeded()
    }

    /// Same fallback as the queue page: an edit whose change event was lost is refetched on open.
    private func reloadQueueIfNeeded() {
        guard state.playback.queueNeedsReload, let pid = state.selectedPlayerID else { return }
        Task {
            guard let items = try? await service.getQueue(pid: pid, range: nil),
                  state.selectedPlayerID == pid else { return }
            state.setQueue(items)
        }
    }
}
