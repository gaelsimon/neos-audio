import AppKit
import SwiftUI
import XCTest
@testable import Neos
import NeosDomain

/// The Mac's inspector builds the panel once with its window, before the speaker has answered.
@MainActor
final class QueuePanelViewTests: XCTestCase {
    private var window: NSWindow?
    /// SwiftUI delivers a change a run-loop turn or more later, and a loaded machine takes longer.
    private let patience: TimeInterval = 5

    private let queue = [
        QueueItem(qid: 1, song: "A", mid: "m1"),
        QueueItem(qid: 2, song: "B", mid: "m2"),
        QueueItem(qid: 3, song: "C", mid: "m3"),
    ]

    override func tearDown() async throws {
        await MainActor.run {
            window?.close()
            window = nil
        }
    }

    /// Returns once the panel's first task has refetched the queue, so what follows reaches a panel already built.
    private func buildPanel(state: AppState, mock: MockAudioService, queueAtLaunch: [QueueItem]) async -> QueuePanelViewModel {
        let viewModel = QueuePanelViewModel(service: mock, state: state)
        mock.queueItems = queueAtLaunch
        state.selectedPlayerID = 42
        state.noteQueueEdit()
        let size = CGSize(width: 380, height: 600)
        let host = NSHostingView(
            rootView: QueuePanelView(state: state, viewModel: viewModel).frame(width: size.width, height: size.height)
        )
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        self.window = window
        await waitUntil(timeout: patience) { !state.playback.queueNeedsReload }
        return viewModel
    }

    func testThePanelFillsWhenTheSpeakerAnswersAfterTheWindowOpened() async {
        let state = AppState()
        let viewModel = await buildPanel(state: state, mock: MockAudioService(), queueAtLaunch: [])

        state.setNowPlaying(NowPlayingMedia(mid: "m1", qid: 1))
        state.setQueue(queue)

        await waitUntil(timeout: patience) { !viewModel.isEmpty }
        XCTAssertEqual(viewModel.upNextItems.map(\.qid), [2, 3])
    }

    func testAClosedPanelFollowsTheTrack() async {
        let state = AppState()
        state.setNowPlaying(NowPlayingMedia(mid: "m1", qid: 1))
        let viewModel = await buildPanel(state: state, mock: MockAudioService(), queueAtLaunch: queue)
        await waitUntil(timeout: patience) { viewModel.nowPlayingQueueItem?.qid == 1 }

        state.setNowPlaying(NowPlayingMedia(mid: "m2", qid: 2))

        await waitUntil(timeout: patience) { viewModel.nowPlayingQueueItem?.qid == 2 }
        XCTAssertEqual(viewModel.upNextItems.map(\.qid), [3])
    }

    func testOpeningRefetchesAQueueWhoseEditWasLost() async {
        let state = AppState()
        let mock = MockAudioService()
        _ = await buildPanel(state: state, mock: mock, queueAtLaunch: queue)
        mock.calls.removeAll()
        state.noteQueueEdit()

        state.isQueuePanelOpen = true

        await waitUntil(timeout: patience) { mock.calls.contains("getQueue:42") }
        XCTAssertEqual(mock.calls.filter { $0 == "getQueue:42" }.count, 1)
    }
}
