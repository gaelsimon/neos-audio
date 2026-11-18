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

    private let pageSize = CGSize(width: 900, height: 600)

    /// With no speaker the page asks for nothing, so an empty queue stays the empty page.
    private func host(queueLength: Int, wrappedBy wrap: (QueueView) -> AnyView = { AnyView($0) }) -> NSView {
        let state = AppState()
        let mock = MockAudioService()
        state.selectedPlayerID = queueLength > 0 ? 42 : nil
        state.setQueue((0..<queueLength).map { QueueItem(qid: $0 + 1, song: "Song \($0 + 1)", mid: "m\($0 + 1)") })
        let page = QueueView(
            state: state,
            viewModel: QueueViewModel(service: mock, state: state),
            browseVM: BrowseViewModel(service: mock, state: state)
        )
        let host = NSHostingView(rootView: wrap(page).frame(width: pageSize.width, height: pageSize.height))
        host.frame = CGRect(origin: .zero, size: pageSize)
        let window = NSWindow(contentRect: host.frame, styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        self.window = window
        return host
    }

    /// Each row the page builds brings one AppKit pop-up button, its "…" menu.
    private func rowsBuilt(queueLength: Int) -> Int {
        host(queueLength: queueLength).descendants().filter { $0 is NSPopUpButton }.count
    }

    func testAnEmptyQueueStillFillsThePageSoItsTitleStaysAtTheTop() async {
        let measured = Measured()
        _ = host(queueLength: 0) { page in
            AnyView(page.onGeometryChange(for: CGSize.self) { $0.size } action: { measured.size = $0 })
        }

        await waitUntil(timeout: 1.0) { measured.size != .zero }

        XCTAssertEqual(measured.size, pageSize)
    }

    func testAShortQueueBuildsEveryRow() {
        XCTAssertEqual(rowsBuilt(queueLength: 5), 5)
    }

    func testALongQueueBuildsOnlyTheRowsNearTheWindow() {
        XCTAssertLessThan(rowsBuilt(queueLength: 300), 60)
    }
}

@MainActor
private final class Measured {
    var size = CGSize.zero
}

private extension NSView {
    func descendants() -> [NSView] {
        subviews.flatMap { [$0] + $0.descendants() }
    }
}
