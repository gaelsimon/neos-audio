import XCTest
@testable import Neos
import NeosDomain

/// The cache and diagnostics actions, with the image cache and clipboard replaced so the developer's own stay untouched.
@MainActor
final class SettingsViewModelCacheTests: XCTestCase {
    private var copied: [String] = []
    private var imageClears = 0

    private func makeViewModel(state: AppState, imageBytes: Int = 0) -> SettingsViewModel {
        SettingsViewModel(
            state: state,
            imageCacheBytes: { imageBytes },
            clearImageCache: { self.imageClears += 1 },
            copyText: { self.copied.append($0) }
        )
    }

    private func event(_ message: String) -> AppState.DiagnosticEvent {
        AppState.DiagnosticEvent(source: "HEOS", message: message)
    }

    func testAnEmptyCacheSaysSo() {
        XCTAssertEqual(makeViewModel(state: AppState()).estimatedCacheSize, "Empty")
    }

    func testTheCacheNamesWhatItHolds() {
        let state = AppState()
        state.diagnostics = [event("Connected")]

        XCTAssertEqual(makeViewModel(state: state).estimatedCacheSize, "1 diagnostic events")
    }

    func testImagesOnDiskCountInTheCacheSize() {
        let size = makeViewModel(state: AppState(), imageBytes: 2048).estimatedCacheSize

        XCTAssertTrue(size.hasSuffix("images"), size)
    }

    func testClearingTheCacheEmptiesTheStateAndTheImages() {
        let state = AppState()
        state.diagnostics = [event("Connected")]
        let viewModel = makeViewModel(state: state)

        viewModel.clearCache()

        XCTAssertTrue(state.diagnostics.isEmpty)
        XCTAssertEqual(imageClears, 1)
    }

    func testCopiedDiagnosticsHaveOneLinePerEvent() {
        let state = AppState()
        state.diagnostics = [event("Connected"), event("Pair found")]

        makeViewModel(state: state).copyDiagnostics()

        XCTAssertEqual(copied.first?.split(separator: "\n").count, 2)
    }

    func testCopyingWithoutDiagnosticsSaysThereAreNone() {
        makeViewModel(state: AppState()).copyDiagnostics()

        XCTAssertEqual(copied, ["No diagnostic events"])
    }
}
