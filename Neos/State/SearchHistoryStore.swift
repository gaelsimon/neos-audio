import Foundation

enum SearchHistoryStore {
    private static let key = "recentSearchQueries"

    static func recentQueries() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func addQuery(_ query: String) {
        var queries = recentQueries()
        queries.removeAll { $0.caseInsensitiveCompare(query) == .orderedSame }
        queries.insert(query, at: 0)
        let capped = Array(queries.prefix(10))
        UserDefaults.standard.set(capped, forKey: key)
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
