import Foundation

/// Generic browser-style history stack with back/forward navigation.
///
/// Mutations on this struct trigger `@Observable` tracking when stored
/// as a property on an `@Observable` class (value-type semantics).
@MainActor
struct NavigationHistoryStack<Entry: Equatable> {
    private var entries: [Entry]
    private(set) var currentIndex: Int

    init(root: Entry) {
        entries = [root]
        currentIndex = 0
    }

    var current: Entry {
        entries[currentIndex]
    }

    var canGoBack: Bool {
        currentIndex > 0
    }

    var canGoForward: Bool {
        currentIndex < entries.count - 1
    }

    /// Truncate any forward history and append a new entry.
    mutating func push(_ entry: Entry) {
        if currentIndex < entries.count - 1 {
            entries.removeSubrange((currentIndex + 1)...)
        }
        entries.append(entry)
        currentIndex = entries.count - 1
    }

    /// Move back one entry. Returns the new current entry, or `nil` if already at the start.
    @discardableResult
    mutating func goBack() -> Entry? {
        guard canGoBack else { return nil }
        currentIndex -= 1
        return entries[currentIndex]
    }

    /// Move forward one entry. Returns the new current entry, or `nil` if already at the end.
    @discardableResult
    mutating func goForward() -> Entry? {
        guard canGoForward else { return nil }
        currentIndex += 1
        return entries[currentIndex]
    }

    /// Mutate the current entry in-place (e.g. to cache items before navigating away).
    mutating func updateCurrent(_ transform: (inout Entry) -> Void) {
        transform(&entries[currentIndex])
    }
}
