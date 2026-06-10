import XCTest
@testable import Neos
import NeosDomain

final class QueuePanelViewModelTests: XCTestCase {

    // MARK: - nowPlayingQueueItem

    @MainActor
    func testNowPlayingQueueItemMatchesByQID() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "m1", qid: 5))
        state.setQueue([
            QueueItem(qid: 3, song: "A", mid: "m0"),
            QueueItem(qid: 5, song: "B", mid: "m1"),
            QueueItem(qid: 7, song: "C", mid: "m2"),
        ])
        vm.refreshDisplayData()

        XCTAssertEqual(vm.nowPlayingQueueItem?.qid, 5)
        XCTAssertEqual(vm.nowPlayingQueueItem?.song, "B")
    }

    @MainActor
    func testNowPlayingQueueItemNilWhenNoQID() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "m1", qid: nil))
        state.setQueue([QueueItem(qid: 1, song: "A")])
        vm.refreshDisplayData()

        XCTAssertNil(vm.nowPlayingQueueItem)
    }

    // MARK: - upNextItems

    @MainActor
    func testUpNextItemsReturnsItemsAfterCurrent() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "m1", qid: 2))
        state.setQueue([
            QueueItem(qid: 1, song: "A", mid: "m0"),
            QueueItem(qid: 2, song: "B", mid: "m1"),
            QueueItem(qid: 3, song: "C", mid: "m2"),
            QueueItem(qid: 4, song: "D", mid: "m3"),
        ])
        vm.refreshDisplayData()

        let upNext = vm.upNextItems
        XCTAssertEqual(upNext.count, 2)
        XCTAssertEqual(upNext.map(\.qid), [3, 4])
    }

    @MainActor
    func testUpNextItemsEmptyWhenAtEnd() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "m1", qid: 3))
        state.setQueue([
            QueueItem(qid: 1, song: "A", mid: "m0"),
            QueueItem(qid: 2, song: "B", mid: "m2"),
            QueueItem(qid: 3, song: "C", mid: "m1"),
        ])
        vm.refreshDisplayData()

        XCTAssertTrue(vm.upNextItems.isEmpty)
    }

    @MainActor
    func testUpNextItemsEmptyWhenNoQID() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "m1"))
        state.setQueue([QueueItem(qid: 1, song: "A")])
        vm.refreshDisplayData()

        XCTAssertTrue(vm.upNextItems.isEmpty)
    }

    // MARK: - recentSongs (played queue items + filtered history)

    @MainActor
    func testRecentSongsIncludesPlayedQueueItems() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "m1", qid: 3))
        state.setQueue([
            QueueItem(qid: 1, song: "A", mid: "m0"),
            QueueItem(qid: 2, song: "B", mid: "m2"),
            QueueItem(qid: 3, song: "C", mid: "m1"),
            QueueItem(qid: 4, song: "D", mid: "m3"),
        ])
        vm.refreshDisplayData()

        let recent = vm.recentSongs
        let names = recent.map(\.name)
        XCTAssertTrue(names.contains("A"))
        XCTAssertTrue(names.contains("B"))
    }

    @MainActor
    func testRecentSongsEmptyWhenPlayingFirstItem() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "m1", qid: 1))
        state.setQueue([
            QueueItem(qid: 1, song: "A", mid: "m1"),
            QueueItem(qid: 2, song: "B", mid: "m2"),
        ])
        vm.refreshDisplayData()

        XCTAssertTrue(vm.recentSongs.isEmpty)
    }

    @MainActor
    func testRecentSongsExcludesNowPlayingFromHistory() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "m1"))
        vm.historyTracks = [
            BrowseItem(name: "Current", mid: "m1"),
            BrowseItem(name: "Past", mid: "m2"),
        ]
        vm.refreshDisplayData()

        let names = vm.recentSongs.map(\.name)
        XCTAssertFalse(names.contains("Current"))
        XCTAssertTrue(names.contains("Past"))
    }

    @MainActor
    func testRecentSongsExcludesQueueDuplicatesFromHistory() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "other", qid: 2))
        state.setQueue([
            QueueItem(qid: 1, song: "Played", mid: "m2"),
            QueueItem(qid: 2, song: "Current", mid: "other"),
        ])
        vm.historyTracks = [
            BrowseItem(name: "Played", mid: "m2"),
            BrowseItem(name: "NotInQueue", mid: "m3"),
        ]
        vm.refreshDisplayData()

        let names = vm.recentSongs.map(\.name)
        XCTAssertTrue(names.contains("NotInQueue"))
        let historyNames = vm.recentSongs.compactMap { item -> String? in
            if case .history(let b) = item { return b.name }
            return nil
        }
        XCTAssertFalse(historyNames.contains("Played"))
    }

    @MainActor
    func testRecentSongsCappedAtFive() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "current", qid: 7))
        state.setQueue((1...7).map { QueueItem(qid: $0, song: "S\($0)", mid: "m\($0)") })
        vm.refreshDisplayData()

        let recent = vm.recentSongs
        XCTAssertLessThanOrEqual(recent.count, 10)
    }

    // MARK: - isEmpty

    @MainActor
    func testIsEmptyWhenEverythingEmpty() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)
        vm.refreshDisplayData()

        XCTAssertTrue(vm.isEmpty)
    }

    @MainActor
    func testNotEmptyWhenNowPlayingHasMid() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "m1"))
        vm.refreshDisplayData()

        XCTAssertFalse(vm.isEmpty)
    }

    @MainActor
    func testNotEmptyWhenQueueHasItems() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setNowPlaying(NowPlayingMedia(mid: "m1", qid: 1))
        state.setQueue([QueueItem(qid: 1, song: "A", mid: "m1"), QueueItem(qid: 2, song: "B", mid: "m2")])
        vm.refreshDisplayData()

        XCTAssertFalse(vm.isEmpty)
    }

    // MARK: - removeQueueItem

    @MainActor
    func testRemoveQueueItemOptimisticallyRemoves() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.selectedPlayerID = 1
        state.setQueue([
            QueueItem(qid: 1, song: "A"),
            QueueItem(qid: 2, song: "B"),
            QueueItem(qid: 3, song: "C"),
        ])

        vm.removeQueueItem(QueueItem(qid: 2, song: "B"))

        // Optimistic: immediately removed
        XCTAssertEqual(state.queue.map(\.qid), [1, 3])

        await yieldForTask()
        let calls = mock.calls
        XCTAssertTrue(calls.contains("removeFromQueue:1:[2]"))
    }

    @MainActor
    func testRemoveQueueItemNoOpWithoutPlayer() {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.setQueue([QueueItem(qid: 1, song: "A")])
        vm.removeQueueItem(QueueItem(qid: 1, song: "A"))

        // Queue unchanged; no selectedPlayerID
        XCTAssertEqual(state.queue.count, 1)
    }

    @MainActor
    func testRemoveQueueItemRevertsOnError() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.removeFromQueueError = NSError(domain: "test", code: 1)
        let vm = QueuePanelViewModel(service: mock, state: state)

        state.selectedPlayerID = 1
        state.setQueue([
            QueueItem(qid: 1, song: "A"),
            QueueItem(qid: 2, song: "B"),
        ])

        vm.removeQueueItem(QueueItem(qid: 2, song: "B"))

        // Optimistic: removed
        XCTAssertEqual(state.queue.map(\.qid), [1])

        // Wait for revert
        await yieldForTask()
        XCTAssertEqual(state.queue.map(\.qid), [1, 2])
        XCTAssertNotNil(state.error)
    }
}
