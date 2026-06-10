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
            getQueue: { pid, range in
                try await backend.getQueue(pid: pid, range: range)
            }
        )

        state.selectedPlayerID = 11
        viewModel.loadQueue()

        await waitUntil(timeoutSeconds: 1.0) {
            await backend.hasPendingRequest(for: 11)
        }

        state.selectedPlayerID = 22
        viewModel.loadQueue()

        await waitUntil(timeoutSeconds: 1.0) {
            await backend.hasPendingRequest(for: 22)
        }

        await backend.resume(pid: 22, with: [QueueItem(qid: 2201, song: "Current")])
        await waitUntil(timeoutSeconds: 1.0) {
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
    func testLoadQueueSetsLoadingFlag() async {
        let state = AppState()
        let mock = MockAudioService()
        let backend = MockQueueBackend()
        let vm = QueueViewModel(service: mock, state: state, getQueue: { pid, range in
            try await backend.getQueue(pid: pid, range: range)
        })

        state.selectedPlayerID = 42
        vm.loadQueue()
        await Task.yield()

        XCTAssertTrue(vm.isLoadingQueue)

        await backend.resume(pid: 42, with: [])
        await yieldForTask()

        XCTAssertFalse(vm.isLoadingQueue)
    }

    // MARK: - loadMoreQueue

    @MainActor
    func testLoadMoreQueueAppendsItems() async {
        let state = AppState()
        let mock = MockAudioService()
        // Simulate first page of exactly 100 items (hasMore = true)
        let firstPage = (0..<100).map { QueueItem(qid: $0, song: "S\($0)") }
        mock.queueItems = firstPage
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        vm.loadQueue()
        await yieldForTask()

        XCTAssertEqual(state.queue.count, 100)
        XCTAssertTrue(vm.hasMore)

        // Enqueue second page
        mock.queueItems = [QueueItem(qid: 200, song: "Extra")]
        vm.loadMoreQueue()
        await yieldForTask()

        XCTAssertEqual(state.queue.count, 101)
        XCTAssertEqual(state.queue.last?.song, "Extra")
    }

    @MainActor
    func testLoadMoreQueueGuardsWhenNotHasMore() async {
        let state = AppState()
        let mock = MockAudioService()
        mock.queueItems = [QueueItem(qid: 1)]
        let vm = QueueViewModel(service: mock, state: state)

        state.selectedPlayerID = 42
        vm.loadQueue()
        await yieldForTask()

        // hasMore is false since we got < pageSize items
        XCTAssertFalse(vm.hasMore)

        let callsBefore = mock.calls.count
        vm.loadMoreQueue()
        await Task.yield()

        XCTAssertEqual(mock.calls.count, callsBefore)
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

    // MARK: - Helpers

    @MainActor
    private func waitUntil(timeoutSeconds: TimeInterval, condition: @escaping () async -> Bool) async {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while Date() < deadline {
            if await condition() {
                return
            }
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Condition not met within timeout")
    }
}

private actor MockQueueBackend {
    private var continuations: [Int: CheckedContinuation<[QueueItem], Error>] = [:]

    func getQueue(pid: Int, range: ClosedRange<Int>?) async throws -> [QueueItem] {
        _ = range
        return try await withCheckedThrowingContinuation { continuation in
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
