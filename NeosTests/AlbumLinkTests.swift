import XCTest
import HEOSKit
import NeosDomain
@testable import Neos

@MainActor
final class AlbumLinkTests: XCTestCase {
    private func page(entering container: BrowseItem) async -> BrowseViewModel {
        let state = AppState()
        let viewModel = BrowseViewModel(
            service: HEOSService(stateUpdater: state),
            state: state,
            browseSource: { _ in BrowseResult(items: [container]) },
            browseContainer: { _, _, _ in BrowseResult(items: []) }
        )
        viewModel.selectSource(MusicSource(sid: 1, name: "TIDAL"))
        await yieldForTask()
        viewModel.browseItem(container)
        await yieldForTask()
        return viewModel
    }

    func testATrackOnItsAlbumsPageLinksNowhere() async {
        let viewModel = await page(entering: BrowseItem(name: "Midnight Opera", type: .album, cid: "a1", browsable: true))

        XCTAssertNil(viewModel.albumToOpen(from: BrowseItem(name: "Paper Lanterns", album: "Midnight Opera")))
    }

    func testATrackInAPlaylistLinksToItsAlbum() async {
        let viewModel = await page(entering: BrowseItem(name: "Road Trip", type: .playlist, cid: "p1", browsable: true))

        XCTAssertEqual(viewModel.albumToOpen(from: BrowseItem(name: "Mile 1", album: "Midnight Opera")), "Midnight Opera")
    }

    func testATrackOfAnotherAlbumLinksToIt() async {
        let viewModel = await page(entering: BrowseItem(name: "Analog Dreams", type: .album, cid: "a2", browsable: true))

        XCTAssertEqual(viewModel.albumToOpen(from: BrowseItem(name: "Paper Lanterns", album: "Midnight Opera")), "Midnight Opera")
    }

    func testATrackWithoutAnAlbumLinksNowhere() async {
        let viewModel = await page(entering: BrowseItem(name: "Road Trip", type: .playlist, cid: "p1", browsable: true))

        XCTAssertNil(viewModel.albumToOpen(from: BrowseItem(name: "Mile 1", album: "")))
    }
}
