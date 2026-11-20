import XCTest
@testable import Neos
import NeosDomain

final class QueueViewModelTests: XCTestCase {

    // MARK: - Existing Race Condition Test

    @MainActor
    func testLoadQueueIgnoresStaleResponseWhenSelectedPlayerChanges() async {
        let state = AppState()
        let mock = MockAudioService()
        let backend = MockQueueBackend()

        let viewModel = QueueViewModel(
            service: mock,
            state: state,
            getQueue: { pid in
                try await backend.getQueue(pid: pid)
            }
        )

        state.selectedPlayerID = 11
        viewModel.loadQueue()

        await waitUntil(timeout: 1.0) {
            await backend.hasPendingRequest(for: 11)
        }

        state.selectedPlayerID = 22
        viewModel.loadQueue()

        await waitUntil(timeout: 1.0) {
            await backend.hasPendingRequest(for: 22)
        }

        await backend.resume(pid: 22, with: [QueueItem(qid: 2201, song: "Current")])
        await waitUntil(timeout: 1.0) {
            state.queue.map(\.qid) == [2201]
        }

        XCTAssertEqual(state.queue.map(\.qid), [2201])

        await backend.resume(pid: 11, with: [QueueItem(qid: 1101, song: "Stale")])
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(state.queue.map(\.qid), [2201])
        XCTAssertFalse(viewModel.isLoadingQueue)
    }

    // MARK: - loadQueue

    @MainActor
    func testLoadQueuePopulatesStateQueue() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.queueItems = [QueueItem(qid: 1, song: "A"), QueueItem(qid: 2, song: "B")]
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        vm.loadQueue()
        await yieldForTask()

        XCTAssertEqual(state.queue.count, 2)
        XCTAssertEqual(state.queue[0].song, "A")
        XCTAssertTrue(mock.calls.contains("getQueue:42"))
    }

    @MainActor
    func testLoadQueueNoPlayerDoesNothing() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = nil
        vm.loadQueue()
        await Task.yield()

        XCTAssertTrue(mock.calls.isEmpty)
        XCTAssertTrue(state.queue.isEmpty)
    }

    @MainActor
    func testLoadQueueErrorSetsErrorMessage() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.getQueueError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Queue failed"])
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        vm.loadQueue()
        await yieldForTask()

        XCTAssertEqual(state.error, .queueFailed("Queue failed"))
    }

    @MainActor
    func testLoadQueueClearsThePendingEdit() async {
        let state = AppState()
        let vm = QueueViewModel(service: MockAudioService(), state: state)
        state.selectedPlayerID = 42
        state.noteQueueEdit()

        vm.loadQueue()
        await waitUntil { !vm.isLoadingQueue }

        XCTAssertFalse(state.playback.queueNeedsReload)
    }

    @MainActor
    func testLoadQueueSetsLoadingFlag() async {
        let state = AppState()
        let mock = MockAudioService()
        let backend = MockQueueBackend()
        let vm = QueueViewModel(service: mock, state: state, getQueue: { pid in
            try await backend.getQueue(pid: pid)
        })

        state.selectedPlayerID = 42
        vm.loadQueue()
        await Task.yield()

        XCTAssertTrue(vm.isLoadingQueue)

        await backend.resume(pid: 42, with: [])
        await waitUntil { !vm.isLoadingQueue }

        XCTAssertFalse(vm.isLoadingQueue)
    }

    @MainActor
    func testLoadQueueAsksForTheWholeQueue() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        vm.loadQueue()
        await waitUntil { !vm.isLoadingQueue }

        XCTAssertEqual(mock.queueRangesAsked, [nil])
    }

    // MARK: - Stream entries left behind

    private static let stream = "Url Stream"

    @MainActor
    private func sweeping(
        _ queue: [QueueItem], playing: NowPlayingMedia, before answer: (AppState) -> Void = { _ in }
    ) async -> [String] {
        let state = AppState()
        let mock = MockAudioService()
        let backend = MockQueueBackend()
        let vm = QueueViewModel(service: mock, state: state, getQueue: { try await backend.getQueue(pid: $0) })
        state.selectedPlayerID = 42
        state.setNowPlaying(playing)

        let sweep = vm.removeLeftoverStreams()
        await waitUntil(timeout: 1.0) { await backend.hasPendingRequest(for: 42) }
        answer(state)
        await backend.resume(pid: 42, with: queue)
        await sweep?.value

        return mock.calls.filter { $0.hasPrefix("removeFromQueue") }
    }

    private func streamEntry(_ qid: Int) -> QueueItem {
        QueueItem(qid: qid, song: Self.stream, album: Self.stream, artist: Self.stream)
    }

    private func playingStream(qid: Int) -> NowPlayingMedia {
        NowPlayingMedia(song: Self.stream, albumID: "1", mid: "1", qid: qid, sid: 1024)
    }

    @MainActor
    func testTheStreamsLeftByEarlierRadiosAreRemoved() async {
        let queue = [streamEntry(1), QueueItem(qid: 2, song: "A", mid: "m2"), streamEntry(3), streamEntry(4)]

        let removals = await sweeping(queue, playing: playingStream(qid: 3))

        XCTAssertEqual(removals, ["removeFromQueue:42:[1, 4]"])
    }

    @MainActor
    func testTheStreamThatPlaysKeepsItsEntry() async {
        let removals = await sweeping([streamEntry(1), QueueItem(qid: 2, song: "A", mid: "m2")], playing: playingStream(qid: 1))

        XCTAssertEqual(removals, [])
    }

    @MainActor
    func testAStationPlayingLeavesNoStreamEntry() async {
        let station = NowPlayingMedia(type: .station, song: "Amen", albumID: "s17439", mid: "http://example.com/live", qid: 1, sid: 3, station: "Funk")

        let removals = await sweeping([streamEntry(1), QueueItem(qid: 2, song: "A", mid: "m2")], playing: station)

        XCTAssertEqual(removals, ["removeFromQueue:42:[1]"])
    }

    @MainActor
    func testAQueueOfTracksIsLeftAlone() async {
        let queue = [QueueItem(qid: 1, song: "A", mid: "m1"), QueueItem(qid: 2, song: "B", mid: "m2")]

        let removals = await sweeping(queue, playing: NowPlayingMedia(song: "A", mid: "m1", qid: 1, sid: 10))

        XCTAssertEqual(removals, [])
    }

    @MainActor
    func testATrackNamedLikeTheSpeakersPlaceholderIsKept() async {
        let queue = [QueueItem(qid: 1, song: Self.stream, mid: "m1"), QueueItem(qid: 2, song: "B", mid: "m2")]

        let removals = await sweeping(queue, playing: NowPlayingMedia(song: "B", mid: "m2", qid: 2, sid: 10))

        XCTAssertEqual(removals, [])
    }

    @MainActor
    func testNothingIsRemovedWhenTheQueueDoesNotHoldTheStreamThatPlays() async {
        let queue = [streamEntry(1), QueueItem(qid: 2, song: "A", mid: "m2")]

        let removals = await sweeping(queue, playing: playingStream(qid: 2))

        XCTAssertEqual(removals, [])
    }

    @MainActor
    func testNothingIsRemovedOnceAnotherPlayHasStarted() async {
        let removals = await sweeping([streamEntry(1), streamEntry(2)], playing: playingStream(qid: 2)) { state in
            _ = state.beginTrackLoad()
        }

        XCTAssertEqual(removals, [])
    }

    @MainActor
    func testNothingIsRemovedOnceAnotherRadioWasAskedFor() async {
        let removals = await sweeping([streamEntry(1), streamEntry(2)], playing: playingStream(qid: 2)) { state in
            state.playback.awaitsRadioStart = true
        }

        XCTAssertEqual(removals, [])
    }

    // MARK: - playItem

    @MainActor
    func testPlayItemCallsService() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        let item = QueueItem(qid: 5, song: "Track")
        vm.playItem(item)
        await yieldForTask()

        XCTAssertTrue(mock.calls.contains("playQueueItem:42:5"))
    }

    @MainActor
    func testPlayItemNoPlayerDoesNothing() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = nil
        vm.playItem(QueueItem(qid: 1))
        await Task.yield()

        XCTAssertTrue(mock.calls.isEmpty)
    }

    @MainActor
    func testPlayItemErrorSetsMessage() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.playQueueItemError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Play failed"])
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        vm.playItem(QueueItem(qid: 1))
        await yieldForTask()

        XCTAssertEqual(state.error, .queueFailed("Play failed"))
    }

    // MARK: - removeItem

    @MainActor
    func testRemoveItemOptimisticallyRemoves() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        state.setQueue([QueueItem(qid: 1, song: "A"), QueueItem(qid: 2, song: "B"), QueueItem(qid: 3, song: "C")])

        vm.removeItem(QueueItem(qid: 2, song: "B"))
        // Optimistic: should be removed immediately
        XCTAssertEqual(state.queue.count, 2)
        XCTAssertFalse(state.queue.contains { $0.qid == 2 })

        await yieldForTask()
        XCTAssertTrue(mock.calls.contains("removeFromQueue:42:[2]"))
    }

    @MainActor
    func testRemoveItemRevertsOnError() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.removeFromQueueError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Remove failed"])
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        let original = [QueueItem(qid: 1, song: "A"), QueueItem(qid: 2, song: "B")]
        state.setQueue(original)

        vm.removeItem(QueueItem(qid: 2, song: "B"))
        // Optimistic removal
        XCTAssertEqual(state.queue.count, 1)

        await yieldForTask()

        // Should revert
        XCTAssertEqual(state.queue.count, 2)
        XCTAssertEqual(state.error, .queueFailed("Remove failed"))
    }

    @MainActor
    func testRemoveItemNoPlayerDoesNothing() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = nil
        state.setQueue([QueueItem(qid: 1)])
        vm.removeItem(QueueItem(qid: 1))
        await Task.yield()

        XCTAssertTrue(mock.calls.isEmpty)
        XCTAssertEqual(state.queue.count, 1)
    }

    // MARK: - clearQueue

    @MainActor
    func testClearQueueOptimisticallyClearsAndSetsFlag() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        state.setQueue([QueueItem(qid: 1), QueueItem(qid: 2)])

        vm.clearQueue()
        // Optimistic: queue cleared immediately
        XCTAssertTrue(state.queue.isEmpty)
        XCTAssertTrue(vm.isClearing)

        await yieldForTask()
        XCTAssertFalse(vm.isClearing)
        XCTAssertTrue(mock.calls.contains("clearQueue:42"))
    }

    @MainActor
    func testClearQueueRevertsOnError() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.clearQueueError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Clear failed"])
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        let original = [QueueItem(qid: 1), QueueItem(qid: 2)]
        state.setQueue(original)

        vm.clearQueue()
        // Optimistic
        XCTAssertTrue(state.queue.isEmpty)

        await yieldForTask()

        // Should revert
        XCTAssertEqual(state.queue.count, 2)
        XCTAssertEqual(state.error, .queueFailed("Clear failed"))
    }

    @MainActor
    func testClearQueueNoPlayerDoesNothing() async {
        let state = AppState()
        let mock = MockAudioService()
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = nil
        state.setQueue([QueueItem(qid: 1)])
        vm.clearQueue()
        await Task.yield()

        XCTAssertTrue(mock.calls.isEmpty)
        XCTAssertEqual(state.queue.count, 1)
    }

}

private actor MockQueueBackend {
    private var continuations: [Int: CheckedContinuation<[QueueItem], Error>] = [:]

    func getQueue(pid: Int) async throws -> [QueueItem] {
        try await withCheckedThrowingContinuation { continuation in
            continuations[pid] = continuation
        }
    }

    func hasPendingRequest(for pid: Int) -> Bool {
        continuations[pid] != nil
    }

    func resume(pid: Int, with items: [QueueItem]) {
        guard let continuation = continuations.removeValue(forKey: pid) else {
            return
        }
        continuation.resume(returning: items)
    }
}
