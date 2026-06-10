import Foundation
import NeosDomain

/// Offset-based pagination tracker with item deduplication.
///
/// Mutations on this struct trigger `@Observable` tracking when stored
/// as a property on an `@Observable` class (value-type semantics).
@MainActor
struct PaginationState {
    private(set) var totalCount: Int?
    private(set) var currentOffset: Int = 0
    let pageSize: Int
    private var seenIDs: Set<String> = []

    init(pageSize: Int = 50) {
        self.pageSize = pageSize
    }

    /// Range for the next page fetch.
    var nextRange: ClosedRange<Int> {
        currentOffset...(currentOffset + pageSize - 1)
    }

    /// Range for the first page fetch.
    var firstRange: ClosedRange<Int> {
        0...(pageSize - 1)
    }

    /// Record a page of items, filtering duplicates. Returns only new (unseen) items.
    mutating func recordPage(_ items: [BrowseItem], serverCount: Int?) -> [BrowseItem] {
        let effectiveCount = (serverCount ?? 0) > 0 ? serverCount : nil
        if !items.isEmpty {
            let newItems = items.filter { seenIDs.insert($0.id).inserted }
            currentOffset += items.count
            if totalCount == nil || totalCount == 0 {
                totalCount = effectiveCount
            }
            // Fewer items than page size means we've reached the end.
            if totalCount == nil || totalCount == 0, items.count < pageSize {
                totalCount = currentOffset
            }
            return newItems
        } else {
            totalCount = currentOffset
            return []
        }
    }

    /// Record the initial page of items and seed the seen-IDs set.
    mutating func recordInitialPage(_ items: [BrowseItem], serverCount: Int?) {
        for item in items {
            seenIDs.insert(item.id)
        }
        // Some HEOS services report count=0 meaning "unknown", not "zero items".
        // Treat 0 as nil so the pageSize heuristic below can handle it.
        let effectiveCount = (serverCount ?? 0) > 0 ? serverCount : nil
        if let effectiveCount {
            totalCount = effectiveCount
        } else if items.count < pageSize {
            totalCount = items.count
        }
        currentOffset = items.count
    }

    /// Reset all pagination state for a fresh fetch.
    mutating func reset() {
        totalCount = nil
        currentOffset = 0
        seenIDs = []
    }

    /// Restore pagination state from a cache snapshot.
    mutating func restore(totalCount: Int?, currentOffset: Int, items: [BrowseItem]) {
        self.totalCount = totalCount
        self.currentOffset = currentOffset
        seenIDs = Set(items.map(\.id))
    }

    /// Pin totalCount to currentOffset so hasMore returns false.
    mutating func markComplete() {
        totalCount = currentOffset
    }

    /// Whether the user has scrolled close enough to the end to trigger a load-more.
    func shouldLoadMore(at index: Int, itemCount: Int) -> Bool {
        index >= itemCount - 5
    }
}
