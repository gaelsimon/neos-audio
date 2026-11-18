import AppKit
import SwiftUI
import XCTest
@testable import Neos
import NeosDomain

@MainActor
final class QueueViewTests: XCTestCase {
    private var window: NSWindow?

    override func tearDown() async throws {
        await MainActor.run {
            window?.close()
            window = nil
        }
    }

    /// Each row the page builds brings one AppKit pop-up button, its "…" menu.
    private func rowsBuilt(queueLength: Int) -> Int {
        let state = AppState()
        let mock = MockAudioService()
        state.selectedPlayerID = 42
        state.setQueue((1...queueLength).map { QueueItem(qid: $0, song: "Song \($0)", mid: "m\($0)") })
        let size = CGSize(width: 900, height: 600)
        let host = NSHostingView(
            rootView: QueueView(
                state: state,
                viewModel: QueueViewModel(service: mock, state: state),
                browseVM: BrowseViewModel(service: mock, state: state)
            )
            .frame(width: size.width, height: size.height)
        )
        host.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        self.window = window
        return host.descendants().filter { $0 is NSPopUpButton }.count
    }

    func testAShortQueueBuildsEveryRow() {
        XCTAssertEqual(rowsBuilt(queueLength: 5), 5)
    }

    func testALongQueueBuildsOnlyTheRowsNearTheWindow() {
        XCTAssertLessThan(rowsBuilt(queueLength: 300), 60)
    }
}

private extension NSView {
    func descendants() -> [NSView] {
        subviews.flatMap { [$0] + $0.descendants() }
    }
}
