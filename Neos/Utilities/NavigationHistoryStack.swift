import Foundation

/// Generic browser-style history stack with back/forward navigation.
///
/// Mutations on this struct trigger `@Observable` tracking when stored
/// as a property on an `@Observable` class (value-type semantics).
@MainActor
struct NavigationHistoryStack<Entry: Equatable> {
    private var entries: [Entry]
    private var tokens: [Int]
    private var nextToken = 1
    private(set) var currentIndex: Int

    init(root: Entry) {
        entries = [root]
        tokens = [0]
        currentIndex = 0
    }

    /// Identity of the current entry. A pushed entry never reuses a token, so a token
    /// that survives points at the same entry even after forward history is truncated.
    var currentToken: Int { tokens[currentIndex] }

    var previousToken: Int? { currentIndex > 0 ? tokens[currentIndex - 1] : nil }

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
            tokens.removeSubrange((currentIndex + 1)...)
        }
        entries.append(entry)
        tokens.append(nextToken)
        nextToken += 1
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
