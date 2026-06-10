import XCTest
@testable import Neos
import NeosDomain

final class PaginationStateTests: XCTestCase {

    @MainActor
    func testInitialState() {
        let pagination = PaginationState(pageSize: 50)

        XCTAssertNil(pagination.totalCount)
        XCTAssertEqual(pagination.currentOffset, 0)
        XCTAssertEqual(pagination.pageSize, 50)
    }

    @MainActor
    func testFirstRange() {
        let pagination = PaginationState(pageSize: 25)

        XCTAssertEqual(pagination.firstRange, 0...24)
    }

    @MainActor
    func testNextRangeStartsAtCurrentOffset() {
        var pagination = PaginationState(pageSize: 10)

        XCTAssertEqual(pagination.nextRange, 0...9)

        let items = (0..<10).map { BrowseItem(name: "Item\($0)", cid: "c\($0)") }
        _ = pagination.recordPage(items, serverCount: 50)

        XCTAssertEqual(pagination.nextRange, 10...19)
    }

    @MainActor
    func testRecordPageAdvancesOffset() {
        var pagination = PaginationState(pageSize: 10)
        let items = (0..<10).map { BrowseItem(name: "Item\($0)", cid: "c\($0)") }

        let newItems = pagination.recordPage(items, serverCount: 100)

        XCTAssertEqual(newItems.count, 10)
        XCTAssertEqual(pagination.currentOffset, 10)
        XCTAssertEqual(pagination.totalCount, 100)
    }

    @MainActor
    func testRecordPageDeduplicates() {
        var pagination = PaginationState(pageSize: 10)

        let first = [BrowseItem(name: "A", cid: "c1"), BrowseItem(name: "B", cid: "c2")]
        _ = pagination.recordPage(first, serverCount: 10)

        // Second page has one duplicate (cid "c2" -> id "c2")
        let second = [BrowseItem(name: "B", cid: "c2"), BrowseItem(name: "C", cid: "c3")]
        let newItems = pagination.recordPage(second, serverCount: 10)

        XCTAssertEqual(newItems.count, 1)
        XCTAssertEqual(newItems.first?.name, "C")
    }

    @MainActor
    func testRecordInitialPageSeedsIDs() {
        var pagination = PaginationState(pageSize: 10)
        let items = [BrowseItem(name: "A", cid: "c1"), BrowseItem(name: "B", cid: "c2")]

        pagination.recordInitialPage(items, serverCount: 50)

        XCTAssertEqual(pagination.currentOffset, 2)
        XCTAssertEqual(pagination.totalCount, 50)

        // Recording same items again should produce no new items
        let dupes = pagination.recordPage(items, serverCount: 50)
        XCTAssertTrue(dupes.isEmpty)
    }

    @MainActor
    func testRecordInitialPageWithNilServerCount() {
        var pagination = PaginationState(pageSize: 10)
        let items = [BrowseItem(name: "A", cid: "c1")]

        pagination.recordInitialPage(items, serverCount: nil)

        XCTAssertEqual(pagination.currentOffset, 1)
        // Fewer items than pageSize → infers end-of-list
        XCTAssertEqual(pagination.totalCount, 1)
    }

    @MainActor
    func testEmptyPageCapsTotalCount() {
        var pagination = PaginationState(pageSize: 10)
        let items = (0..<5).map { BrowseItem(name: "Item\($0)", cid: "c\($0)") }
        _ = pagination.recordPage(items, serverCount: 100)

        XCTAssertEqual(pagination.currentOffset, 5)

        // Empty page signals end of data
        let empty = pagination.recordPage([], serverCount: nil)

        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(pagination.totalCount, 5)
    }

    @MainActor
    func testReset() {
        var pagination = PaginationState(pageSize: 10)
        let items = (0..<5).map { BrowseItem(name: "Item\($0)", cid: "c\($0)") }
        _ = pagination.recordPage(items, serverCount: 20)

        pagination.reset()

        XCTAssertNil(pagination.totalCount)
        XCTAssertEqual(pagination.currentOffset, 0)
        XCTAssertEqual(pagination.nextRange, 0...9)
    }

    @MainActor
    func testShouldLoadMoreNearEnd() {
        let pagination = PaginationState(pageSize: 10)

        XCTAssertTrue(pagination.shouldLoadMore(at: 15, itemCount: 20))
        XCTAssertTrue(pagination.shouldLoadMore(at: 16, itemCount: 20))
        XCTAssertFalse(pagination.shouldLoadMore(at: 10, itemCount: 20))
        XCTAssertFalse(pagination.shouldLoadMore(at: 0, itemCount: 20))
    }

    @MainActor
    func testCustomPageSize() {
        let pagination = PaginationState(pageSize: 25)

        XCTAssertEqual(pagination.firstRange, 0...24)
        XCTAssertEqual(pagination.nextRange, 0...24)
    }

    @MainActor
    func testRecordPageAllDuplicatesStillAdvancesOffset() {
        var pagination = PaginationState(pageSize: 10)
        let items = [BrowseItem(name: "A", cid: "c1"), BrowseItem(name: "B", cid: "c2")]
        _ = pagination.recordPage(items, serverCount: 20)

        XCTAssertEqual(pagination.currentOffset, 2)

        // All duplicates; no new items, but offset still advances
        let dupes = pagination.recordPage(items, serverCount: 20)

        XCTAssertTrue(dupes.isEmpty)
        XCTAssertEqual(pagination.currentOffset, 4)
    }

    @MainActor
    func testRecordInitialPageWithEmptyArray() {
        var pagination = PaginationState(pageSize: 10)

        pagination.recordInitialPage([], serverCount: 0)

        XCTAssertEqual(pagination.currentOffset, 0)
        XCTAssertEqual(pagination.totalCount, 0)
    }

    @MainActor
    func testResetClearsSeenIDsAndPreservesPageSize() {
        var pagination = PaginationState(pageSize: 15)
        let items = [BrowseItem(name: "A", cid: "c1")]
        pagination.recordInitialPage(items, serverCount: 10)

        pagination.reset()

        XCTAssertEqual(pagination.pageSize, 15)
        XCTAssertEqual(pagination.firstRange, 0...14)

        // Same items should be treated as new after reset
        let newItems = pagination.recordPage(items, serverCount: 10)
        XCTAssertEqual(newItems.count, 1)
    }

    @MainActor
    func testServerCountNilDoesNotOverrideExistingTotalCount() {
        var pagination = PaginationState(pageSize: 10)
        let first = (0..<5).map { BrowseItem(name: "Item\($0)", cid: "c\($0)") }
        _ = pagination.recordPage(first, serverCount: 100)

        XCTAssertEqual(pagination.totalCount, 100)

        // Subsequent page with nil serverCount should not clear totalCount
        let second = (5..<10).map { BrowseItem(name: "Item\($0)", cid: "c\($0)") }
        _ = pagination.recordPage(second, serverCount: nil)

        XCTAssertEqual(pagination.totalCount, 100)
    }

    @MainActor
    func testShouldLoadMoreWithSmallItemCount() {
        let pagination = PaginationState(pageSize: 10)

        // itemCount < 5: threshold goes negative, any index triggers load
        XCTAssertTrue(pagination.shouldLoadMore(at: 0, itemCount: 3))
        XCTAssertTrue(pagination.shouldLoadMore(at: 0, itemCount: 1))

        // Exact boundary: index == itemCount - 5
        XCTAssertTrue(pagination.shouldLoadMore(at: 5, itemCount: 10))
        XCTAssertFalse(pagination.shouldLoadMore(at: 4, itemCount: 10))
    }

    @MainActor
    func testMultipleRecordPageCallsTrackOffset() {
        var pagination = PaginationState(pageSize: 5)

        for page in 0..<3 {
            let items = (0..<5).map { BrowseItem(name: "P\(page)I\($0)", cid: "p\(page)c\($0)") }
            _ = pagination.recordPage(items, serverCount: 50)
        }

        XCTAssertEqual(pagination.currentOffset, 15)
        XCTAssertEqual(pagination.nextRange, 15...19)
    }

    @MainActor
    func testMarkCompletePreventsFurtherLoading() {
        var pagination = PaginationState(pageSize: 10)

        // Simulate a server that didn't report total count but returned a full page
        let items = (0..<10).map { BrowseItem(name: "I\($0)", cid: "c\($0)") }
        _ = pagination.recordPage(items, serverCount: nil)
        XCTAssertNil(pagination.totalCount)

        // Restore from cache
        pagination.restore(totalCount: nil, currentOffset: 10, items: items)
        XCTAssertNil(pagination.totalCount)

        // markComplete pins totalCount = currentOffset
        pagination.markComplete()
        XCTAssertEqual(pagination.totalCount, 10)
        XCTAssertEqual(pagination.currentOffset, 10)
    }

    @MainActor
    func testInitialPageFewerThanPageSizeSetsTotalCount() {
        var pagination = PaginationState(pageSize: 50)

        // Server returns 3 items with no count; fewer than page size
        let items = (0..<3).map { BrowseItem(name: "I\($0)", cid: "c\($0)") }
        pagination.recordInitialPage(items, serverCount: nil)

        // Should infer end-of-list from under-sized page
        XCTAssertEqual(pagination.totalCount, 3)
        XCTAssertEqual(pagination.currentOffset, 3)
    }

    @MainActor
    func testInitialPageFullPageKeepsTotalCountNil() {
        var pagination = PaginationState(pageSize: 10)

        // Server returns exactly page-size items with no count
        let items = (0..<10).map { BrowseItem(name: "I\($0)", cid: "c\($0)") }
        pagination.recordInitialPage(items, serverCount: nil)

        // Can't infer end; might be more pages
        XCTAssertNil(pagination.totalCount)
        XCTAssertEqual(pagination.currentOffset, 10)
    }

    @MainActor
    func testRecordPageFewerThanPageSizeSetsTotalCount() {
        var pagination = PaginationState(pageSize: 10)

        // First page: full
        let page1 = (0..<10).map { BrowseItem(name: "P1\($0)", cid: "p1c\($0)") }
        _ = pagination.recordPage(page1, serverCount: nil)
        XCTAssertNil(pagination.totalCount)

        // Second page: partial (3 items); end of list
        let page2 = (0..<3).map { BrowseItem(name: "P2\($0)", cid: "p2c\($0)") }
        _ = pagination.recordPage(page2, serverCount: nil)
        XCTAssertEqual(pagination.totalCount, 13)
    }
}
