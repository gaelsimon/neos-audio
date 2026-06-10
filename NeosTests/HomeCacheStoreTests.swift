import XCTest
@testable import Neos
import NeosDomain

final class HomeCacheStoreTests: XCTestCase {

    override func tearDown() {
        HomeCacheStore.clearAll()
        super.tearDown()
    }

    // MARK: - Recents

    func testSaveAndLoadRecents() {
        let items = [
            BrowseItem(name: "Song A", mid: "m1", playable: true),
            BrowseItem(name: "Song B", mid: "m2", playable: true),
        ]

        HomeCacheStore.saveRecents(items)
        let loaded = HomeCacheStore.loadRecents()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].name, "Song A")
        XCTAssertEqual(loaded[1].name, "Song B")
    }

    func testLoadRecentsEmptyByDefault() {
        HomeCacheStore.clearAll()
        XCTAssertTrue(HomeCacheStore.loadRecents().isEmpty)
    }

    // MARK: - Favorites

    func testSaveAndLoadFavorites() {
        let items = [BrowseItem(name: "Fav 1", mid: "f1", playable: true)]

        HomeCacheStore.saveFavorites(items)
        let loaded = HomeCacheStore.loadFavorites()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].name, "Fav 1")
    }

    func testLoadFavoritesEmptyByDefault() {
        HomeCacheStore.clearAll()
        XCTAssertTrue(HomeCacheStore.loadFavorites().isEmpty)
    }

    // MARK: - Service Categories

    func testSaveAndLoadServiceCategory() {
        let items = [BrowseItem(name: "Playlist", cid: "c1", browsable: true)]

        HomeCacheStore.saveServiceCategory(sid: 5, categoryIndex: 0, name: "Playlists", items: items)
        let loaded = HomeCacheStore.loadServiceCategory(sid: 5, categoryIndex: 0)

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.name, "Playlists")
        XCTAssertEqual(loaded?.items.count, 1)
        XCTAssertEqual(loaded?.items[0].name, "Playlist")
    }

    func testLoadServiceCategoryReturnsNilWhenMissing() {
        HomeCacheStore.clearAll()
        XCTAssertNil(HomeCacheStore.loadServiceCategory(sid: 999, categoryIndex: 0))
    }

    func testClearServiceCategories() {
        HomeCacheStore.saveServiceCategory(sid: 5, categoryIndex: 0, name: "Cat", items: [])
        HomeCacheStore.saveServiceCategory(sid: 5, categoryIndex: 1, name: "Cat2", items: [])

        HomeCacheStore.clearServiceCategories(for: 5)

        XCTAssertNil(HomeCacheStore.loadServiceCategory(sid: 5, categoryIndex: 0))
        XCTAssertNil(HomeCacheStore.loadServiceCategory(sid: 5, categoryIndex: 1))
    }

    // MARK: - Timestamp / Staleness

    func testIsStaleReturnsTrueByDefault() {
        HomeCacheStore.clearAll()
        XCTAssertTrue(HomeCacheStore.isStale())
    }

    func testMarkUpdatedMakesNotStale() {
        HomeCacheStore.markUpdated()
        XCTAssertFalse(HomeCacheStore.isStale())
    }

    // MARK: - Clear All

    func testClearAllRemovesEverything() {
        HomeCacheStore.saveRecents([BrowseItem(name: "A")])
        HomeCacheStore.saveFavorites([BrowseItem(name: "B")])
        HomeCacheStore.saveServiceCategory(sid: 5, categoryIndex: 0, name: "C", items: [])
        HomeCacheStore.markUpdated()

        HomeCacheStore.clearAll()

        XCTAssertTrue(HomeCacheStore.loadRecents().isEmpty)
        XCTAssertTrue(HomeCacheStore.loadFavorites().isEmpty)
        XCTAssertNil(HomeCacheStore.loadServiceCategory(sid: 5, categoryIndex: 0))
        XCTAssertTrue(HomeCacheStore.isStale())
    }

    // MARK: - Roundtrip preserves fields

    func testRoundtripPreservesAllBrowseItemFields() {
        let item = BrowseItem(
            name: "My Song",
            imageURL: "https://example.com/img.jpg",
            type: .station,
            cid: "c123",
            mid: "m456",
            sid: 7,
            playable: true,
            browsable: false,
            artist: "Artist",
            album: "Album"
        )

        HomeCacheStore.saveRecents([item])
        let loaded = HomeCacheStore.loadRecents()

        XCTAssertEqual(loaded.count, 1)
        let out = loaded[0]
        XCTAssertEqual(out.name, "My Song")
        XCTAssertEqual(out.imageURL, "https://example.com/img.jpg")
        XCTAssertEqual(out.type, .station)
        XCTAssertEqual(out.cid, "c123")
        XCTAssertEqual(out.mid, "m456")
        XCTAssertEqual(out.sid, 7)
        XCTAssertTrue(out.playable)
        XCTAssertFalse(out.browsable)
        XCTAssertEqual(out.artist, "Artist")
        XCTAssertEqual(out.album, "Album")
    }
}
