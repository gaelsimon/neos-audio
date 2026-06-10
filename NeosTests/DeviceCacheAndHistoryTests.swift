import XCTest
@testable import Neos
import NeosDomain

final class DeviceCacheTests: XCTestCase {

    override func tearDown() {
        DeviceCache.clear()
        super.tearDown()
    }

    func testSaveAndLoadRoundtrip() {
        let device = DiscoveredDevice(host: "192.168.1.10", friendlyName: "Living Room")

        DeviceCache.save(device: device, selectedPlayerID: 42)

        let loaded = DeviceCache.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.device.host, "192.168.1.10")
        XCTAssertEqual(loaded?.device.friendlyName, "Living Room")
        XCTAssertEqual(loaded?.selectedPlayerID, 42)
    }

    func testLoadReturnsNilWhenEmpty() {
        DeviceCache.clear()

        XCTAssertNil(DeviceCache.load())
    }

    func testClearRemovesData() {
        let device = DiscoveredDevice(host: "192.168.1.10")
        DeviceCache.save(device: device, selectedPlayerID: 1)

        DeviceCache.clear()

        XCTAssertNil(DeviceCache.load())
    }

    func testSaveWithNilPlayerID() {
        let device = DiscoveredDevice(host: "192.168.1.10")

        DeviceCache.save(device: device, selectedPlayerID: nil)

        let loaded = DeviceCache.load()
        XCTAssertNotNil(loaded)
        XCTAssertNil(loaded?.selectedPlayerID)
    }
}

final class SearchHistoryStoreTests: XCTestCase {

    override func tearDown() {
        SearchHistoryStore.clearAll()
        super.tearDown()
    }

    func testAddQueryStoresAtFront() {
        SearchHistoryStore.clearAll()

        SearchHistoryStore.addQuery("rock")
        SearchHistoryStore.addQuery("jazz")

        let queries = SearchHistoryStore.recentQueries()
        XCTAssertEqual(queries.first, "jazz")
        XCTAssertEqual(queries.last, "rock")
    }

    func testAddQueryDeduplicatesCaseInsensitive() {
        SearchHistoryStore.clearAll()

        SearchHistoryStore.addQuery("Rock")
        SearchHistoryStore.addQuery("rock")

        let queries = SearchHistoryStore.recentQueries()
        XCTAssertEqual(queries.count, 1)
        XCTAssertEqual(queries[0], "rock")
    }

    func testAddQueryCapsAt10() {
        SearchHistoryStore.clearAll()

        for i in 0..<15 {
            SearchHistoryStore.addQuery("query\(i)")
        }

        let queries = SearchHistoryStore.recentQueries()
        XCTAssertEqual(queries.count, 10)
        XCTAssertEqual(queries[0], "query14")
    }

    func testClearAllRemovesEverything() {
        SearchHistoryStore.addQuery("test")

        SearchHistoryStore.clearAll()

        XCTAssertTrue(SearchHistoryStore.recentQueries().isEmpty)
    }

    func testRecentQueriesEmptyByDefault() {
        SearchHistoryStore.clearAll()

        XCTAssertTrue(SearchHistoryStore.recentQueries().isEmpty)
    }
}
