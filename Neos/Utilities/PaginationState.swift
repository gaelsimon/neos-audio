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
        let newItems = items.filter { seenIDs.insert($0.id).inserted }
        currentOffset += items.count
        if let total = serverCount, total > 0 {
            if totalCount == nil || totalCount == 0 { totalCount = total }
        } else if newItems.isEmpty {
            // Unknown total and this page added nothing new -- empty, or a count=0
            // service re-serving seen items past the end (SoundCloud ignores the
            // offset on finite containers). Either way, end of unique content.
            totalCount = currentOffset
        }
        return newItems
    }

    /// Record the initial page, seed the seen-IDs set, and return the page with
    /// intra-page duplicates removed -- SoundCloud can repeat items within one page,
    /// and the UI keys rows by item id, which must be unique.
    @discardableResult
    mutating func recordInitialPage(_ items: [BrowseItem], serverCount: Int?) -> [BrowseItem] {
        let newItems = items.filter { seenIDs.insert($0.id).inserted }
        currentOffset = items.count
        if let total = serverCount, total > 0 {
            totalCount = total
        } else if items.isEmpty {
            totalCount = 0
        }
        // A short, non-empty page with no usable total (count=0) does NOT mean
        // end-of-list: SoundCloud pages in ~44/50-item chunks mid-feed. recordPage
        // ends pagination when a later fetch yields no new items.
        return newItems
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
