import Foundation

/// Persistent store for custom station artwork URLs, keyed by media/container ID.
/// Stores a JSON file at ~/Library/Application Support/Neos/custom-artwork.json.
enum StationImageStore {
    private static let fileURL: URL = {
        let dir = URL.applicationSupportDirectory.appendingPathComponent("Neos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("custom-artwork.json")
    }()

    private static let legacyKey = "customStationImages"
    private static var inMemoryCache: [String: String]?

    private static func ensureLoaded() -> [String: String] {
        if let cache = inMemoryCache { return cache }
        // Migrate from UserDefaults on first access
        if let legacy = UserDefaults.standard.dictionary(forKey: legacyKey) as? [String: String], !legacy.isEmpty {
            saveToDisk(legacy)
            UserDefaults.standard.removeObject(forKey: legacyKey)
            inMemoryCache = legacy
            return legacy
        }
        let loaded = loadFromDisk()
        inMemoryCache = loaded
        return loaded
    }

    /// Returns the full mapping of id → custom image URL.
    static func all() -> [String: String] {
        ensureLoaded()
    }

    /// Returns the custom image URL for an item, or nil if none is set.
    static func imageURL(forMID mid: String) -> String? {
        ensureLoaded()[mid]
    }

    /// Resolve the display image: custom override wins, then original.
    static func resolvedImageURL(forMID mid: String?, originalURL: String?) -> String? {
        if let mid, let custom = imageURL(forMID: mid) {
            return custom
        }
        return originalURL
    }

    /// Set a custom image URL for an item.
    static func setImageURL(_ url: String, forMID mid: String) {
        var map = ensureLoaded()
        map[mid] = url
        inMemoryCache = map
        saveToDisk(map)
    }

    /// Remove the custom image for an item.
    static func removeImage(forMID mid: String) {
        var map = ensureLoaded()
        map.removeValue(forKey: mid)
        inMemoryCache = map
        saveToDisk(map)
    }

    /// Check if an item has a custom image.
    static func hasCustomImage(forMID mid: String) -> Bool {
        ensureLoaded()[mid] != nil
    }

    /// Reset the in-memory cache, forcing the next access to reload from disk.
    /// Intended for tests that manipulate the JSON file directly.
    static func resetCache() {
        inMemoryCache = nil
    }

    // MARK: - File I/O

    private static func loadFromDisk() -> [String: String] {
        guard let data = try? Data(contentsOf: fileURL),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return map
    }

    private static func saveToDisk(_ map: [String: String]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
