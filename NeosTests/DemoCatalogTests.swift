import XCTest
@testable import Neos
import NeosDomain

#if DEBUG
final class DemoCatalogTests: XCTestCase {
    func testALongListArrivesPageByPage() {
        let all = DemoCatalog.container(sid: DemoCatalog.deezerSID, cid: DemoCatalog.longPlaylistCID) ?? []

        let first = DemoCatalog.page(all, 0...49)
        let last = DemoCatalog.page(all, 100...149)

        XCTAssertEqual(first.items.count, 50)
        XCTAssertEqual(first.count, DemoCatalog.longPlaylistCount)
        XCTAssertEqual(last.items.count, 20)
        XCTAssertEqual(last.items.last?.name, "Mile 120")
    }

    func testEverySourceOfTheDemoOpensOnSomething() {
        for sid in [DemoCatalog.tuneInSID, DemoCatalog.playlistsSID, DemoCatalog.auxSID, DemoCatalog.localMusicSID, DemoCatalog.nasSID] {
            XCTAssertFalse(DemoCatalog.root(of: sid)?.isEmpty ?? true, "sid \(sid)")
        }
    }

    func testAnEmptyServerAndAnEmptyFolderStayEmpty() {
        XCTAssertEqual(DemoCatalog.root(of: DemoCatalog.emptyServerSID)?.count, 0)
        XCTAssertEqual(DemoCatalog.container(sid: DemoCatalog.tuneInSID, cid: "ti-podcasts")?.count, 0)
    }

    func testTheAmpListsItsInputsUnderItsOwnSource() {
        let amp = DemoCatalog.root(of: DemoCatalog.auxSID)?.first
        XCTAssertEqual(amp?.isSubSource, true)
        XCTAssertEqual(DemoCatalog.root(of: DemoCatalog.ampInputsSID)?.count, 9)
    }

    func testASearchAnswersEachCriterionWithItsOwnKind() {
        XCTAssertEqual(DemoCatalog.search(sid: DemoCatalog.deezerSID, scid: 1, query: "night").first?.type, .artist)
        XCTAssertEqual(DemoCatalog.search(sid: DemoCatalog.deezerSID, scid: 2, query: "night").first?.type, .album)
        XCTAssertEqual(DemoCatalog.search(sid: DemoCatalog.deezerSID, scid: 3, query: "night").first?.type, .song)
        XCTAssertEqual(DemoCatalog.search(sid: DemoCatalog.deezerSID, scid: 4, query: "night").first?.type, .playlist)
        XCTAssertEqual(DemoCatalog.search(sid: DemoCatalog.tuneInSID, scid: 1, query: "night").first?.type, .station)
        XCTAssertEqual(DemoCatalog.criteria(for: DemoCatalog.tuneInSID).map(\.name), ["Station"])
    }

    func testAQueryWithNoMatchFindsNothing() {
        XCTAssertTrue(DemoCatalog.search(sid: DemoCatalog.deezerSID, scid: 3, query: "zzz").isEmpty)
    }

    func testOnlyTuneInAnswersASearchForRadio() {
        XCTAssertFalse(DemoCatalog.search(sid: DemoCatalog.tuneInSID, scid: 1, query: "Radio").isEmpty)
        XCTAssertTrue(DemoCatalog.search(sid: DemoCatalog.deezerSID, scid: 3, query: "Radio").isEmpty)
        XCTAssertTrue(DemoCatalog.search(sid: DemoCatalog.tidalSID, scid: 2, query: "Radio").isEmpty)
    }

    @MainActor
    func testTheBrokenFolderFailsAndTheOthersAnswer() async throws {
        let service = DemoAudioService()

        let albums = try await service.browseContainer(sid: DemoCatalog.deezerSID, cid: "cat-albums", range: nil)
        XCTAssertEqual(albums.items.count, 2)

        do {
            _ = try await service.browseContainer(sid: DemoCatalog.tuneInSID, cid: DemoCatalog.brokenCID, range: nil)
            XCTFail("The broken folder should not answer")
        } catch {
            XCTAssertEqual(error.localizedDescription, "The demo source did not answer.")
        }
    }
}
#endif
