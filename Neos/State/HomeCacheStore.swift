import Foundation
import NeosDomain
import os

private let cacheLogger = Logger(subsystem: "com.galela.neos", category: "cache")

/// Persistent cache for Home dashboard content.
/// Stores browse results in UserDefaults so the dashboard can show cached data
/// immediately on launch while fresh data loads in the background.
enum HomeCacheStore {
    private static let recentsKey = "homeCache_recents"
    private static let favoritesKey = "homeCache_favorites"
    private static let serviceCategoryPrefix = "homeCache_service_"
    private static let timestampKey = "homeCache_timestamp"

    /// Maximum age of cached data before it's considered stale (1 hour).
    private static let maxAge: TimeInterval = 3600

    // MARK: - Recents

    static func saveRecents(_ items: [BrowseItem]) {
        save(items: items, forKey: recentsKey)
    }

    static func loadRecents() -> [BrowseItem] {
        load(forKey: recentsKey)
    }

    // MARK: - Favorites

    static func saveFavorites(_ items: [BrowseItem]) {
        save(items: items, forKey: favoritesKey)
    }

    static func loadFavorites() -> [BrowseItem] {
        load(forKey: favoritesKey)
    }

    // MARK: - Service Categories

    static func saveServiceCategory(sid: Int, categoryIndex: Int, name: String, items: [BrowseItem]) {
        let key = "\(serviceCategoryPrefix)\(sid)_\(categoryIndex)"
        let entry = CachedCategory(name: name, items: items.map { CachedBrowseItem(from: $0) })
        do {
            let data = try JSONEncoder().encode(entry)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            cacheLogger.warning("Failed to encode service category \(sid)/\(categoryIndex): \(error.localizedDescription)")
        }
    }

    static func loadServiceCategory(sid: Int, categoryIndex: Int) -> (name: String, items: [BrowseItem])? {
        let key = "\(serviceCategoryPrefix)\(sid)_\(categoryIndex)"
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            let entry = try JSONDecoder().decode(CachedCategory.self, from: data)
            return (entry.name, entry.items.map { $0.toBrowseItem() })
        } catch {
            cacheLogger.warning("Failed to decode service category \(sid)/\(categoryIndex): \(error.localizedDescription)")
            return nil
        }
    }

    static func clearServiceCategories(for sid: Int) {
        for i in 0..<10 {
            clearServiceCategory(sid: sid, categoryIndex: i)
        }
    }

    static func clearServiceCategory(sid: Int, categoryIndex: Int) {
        let key = "\(serviceCategoryPrefix)\(sid)_\(categoryIndex)"
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Timestamp

    static func markUpdated() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: timestampKey)
    }

    static func isStale() -> Bool {
        let timestamp = UserDefaults.standard.double(forKey: timestampKey)
        guard timestamp > 0 else { return true }
        return Date().timeIntervalSince1970 - timestamp > maxAge
    }

    // MARK: - Clear All

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: recentsKey)
        UserDefaults.standard.removeObject(forKey: favoritesKey)
        UserDefaults.standard.removeObject(forKey: timestampKey)
        // Clear every persisted service-category entry regardless of SID
        for key in UserDefaults.standard.dictionaryRepresentation().keys
            where key.hasPrefix(serviceCategoryPrefix) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    // MARK: - Internal

    private static func save(items: [BrowseItem], forKey key: String) {
        let cached = items.map { CachedBrowseItem(from: $0) }
        do {
            let data = try JSONEncoder().encode(cached)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            cacheLogger.warning("Failed to encode \(key): \(error.localizedDescription)")
        }
    }

    private static func load(forKey key: String) -> [BrowseItem] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            let cached = try JSONDecoder().decode([CachedBrowseItem].self, from: data)
            return cached.map { $0.toBrowseItem() }
        } catch {
            cacheLogger.warning("Failed to decode \(key): \(error.localizedDescription)")
            return []
        }
    }
}

// MARK: - Codable Wrappers

/// Codable wrapper for BrowseItem since the domain model may not be Codable.
private struct CachedBrowseItem: Codable {
    let name: String
    let imageURL: String
    let typeRawValue: String
    let cid: String?
    let mid: String?
    let sid: Int?
    let playable: Bool
    let browsable: Bool
    let artist: String?
    let album: String?

    init(from item: BrowseItem) {
        self.name = item.name
        self.imageURL = item.imageURL
        self.typeRawValue = item.type.rawValue
        self.cid = item.cid
        self.mid = item.mid
        self.sid = item.sid
        self.playable = item.playable
        self.browsable = item.browsable
        self.artist = item.artist
        self.album = item.album
    }

    func toBrowseItem() -> BrowseItem {
        BrowseItem(
            name: name,
            imageURL: imageURL,
            type: MediaType(rawValue: typeRawValue) ?? .song,
            cid: cid,
            mid: mid,
            sid: sid,
            playable: playable,
            browsable: browsable,
            artist: artist,
            album: album
        )
    }
}

private struct CachedCategory: Codable {
    let name: String
    let items: [CachedBrowseItem]
}
