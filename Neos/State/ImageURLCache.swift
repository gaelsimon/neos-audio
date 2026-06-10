import Foundation

/// Auto-discovered mapping of media ID → image URL, persisted to disk.
/// Populated whenever browse results contain items with both `mid` and `image_url`.
/// Used as fallback when a source (like HEOS Favorites) omits image URLs.
enum ImageURLCache {
    private static let fileURL: URL = {
        let dir = URL.applicationSupportDirectory.appendingPathComponent("Neos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("image-url-cache.json")
    }()

    private static let maxEntries = 5000

    private struct Entry: Codable {
        let url: String
        var lastAccess: Date
    }

    private static var inMemoryCache: [String: Entry]?

    private static func ensureLoaded() -> [String: Entry] {
        if let cache = inMemoryCache { return cache }
        let loaded = loadFromDisk()
        inMemoryCache = loaded
        return loaded
    }

    /// Returns the full mapping of mid → imageURL.
    static func all() -> [String: String] {
        ensureLoaded().mapValues(\.url)
    }

    /// Look up a cached image URL by media ID. Touches the entry's lastAccess.
    static func imageURL(forMID mid: String) -> String? {
        var map = ensureLoaded()
        guard var entry = map[mid] else { return nil }
        entry.lastAccess = Date()
        map[mid] = entry
        inMemoryCache = map
        return entry.url
    }

    /// Batch-update cache with new mid → imageURL entries.
    /// Only stores entries where both mid and imageURL are non-empty.
    /// Returns true if any new entries were added.
    @discardableResult
    static func cacheEntries(_ entries: [(mid: String, imageURL: String)]) -> Bool {
        let filtered = entries.filter { !$0.mid.isEmpty && !$0.imageURL.isEmpty }
        guard !filtered.isEmpty else { return false }

        var map = ensureLoaded()
        var changed = false
        let now = Date()
        for entry in filtered {
            if map[entry.mid]?.url != entry.imageURL {
                map[entry.mid] = Entry(url: entry.imageURL, lastAccess: now)
                changed = true
            }
        }
        if changed {
            // Evict by oldest lastAccess when over cap
            if map.count > maxEntries {
                let excess = map.count - maxEntries
                let oldest = map
                    .sorted { $0.value.lastAccess < $1.value.lastAccess }
                    .prefix(excess)
                for (key, _) in oldest {
                    map.removeValue(forKey: key)
                }
            }
            inMemoryCache = map
            saveToDisk(map)
        }
        return changed
    }

    /// Reset the in-memory cache, forcing the next access to reload from disk.
    /// Intended for tests that manipulate the JSON file directly.
    static func resetCache() {
        inMemoryCache = nil
    }

    // MARK: - File I/O

    private static func loadFromDisk() -> [String: Entry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        if let map = try? JSONDecoder().decode([String: Entry].self, from: data) {
            return map
        }
        // Migrate from legacy [String: String] format
        if let legacy = try? JSONDecoder().decode([String: String].self, from: data) {
            let now = Date()
            return legacy.mapValues { Entry(url: $0, lastAccess: now) }
        }
        return [:]
    }

    private static func saveToDisk(_ map: [String: Entry]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
