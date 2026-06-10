import Foundation
import NeosDomain

@Observable
@MainActor
final class ImageCacheState {

    // MARK: - Properties

    /// Custom station images set by the user (mid → image URL)
    var customStationImages: [String: String] = StationImageStore.all()

    /// Auto-discovered image URLs from browse responses (mid → imageURL)
    var cachedImageURLs: [String: String] = ImageURLCache.all()

    /// Stream URL → browse MID alias for URL streams whose device MID differs from browse MID
    private(set) var streamMIDAlias: [String: String] = [:]

    // MARK: - Image Resolution

    /// Resolve image URL: custom artwork → cached browse URL → original.
    /// Also checks stream MID alias for URL streams whose browse MID differs from device MID.
    func resolvedImageURL(forMID mid: String?, originalURL: String) -> String {
        guard let mid, !mid.isEmpty else { return originalURL }
        let aliasedMID = streamMIDAlias[mid]

        // 1. User-set custom artwork (highest priority)
        if let custom = customStationImages[mid], !custom.isEmpty {
            return custom
        }
        if let alias = aliasedMID, let custom = customStationImages[alias], !custom.isEmpty {
            return custom
        }

        // 2. Auto-discovered URL from a previous browse
        if originalURL.isEmpty {
            if let cached = cachedImageURLs[mid], !cached.isEmpty {
                return cached
            }
            if let alias = aliasedMID, let cached = cachedImageURLs[alias], !cached.isEmpty {
                return cached
            }
        }

        return originalURL
    }

    // MARK: - Custom Station Images

    func setCustomStationImage(url: String, forMID mid: String) {
        StationImageStore.setImageURL(url, forMID: mid)
        customStationImages[mid] = url
    }

    func removeCustomStationImage(forMID mid: String) {
        StationImageStore.removeImage(forMID: mid)
        customStationImages.removeValue(forKey: mid)
    }

    func hasCustomStationImage(forMID mid: String?) -> Bool {
        guard let mid, !mid.isEmpty else { return false }
        return customStationImages[mid] != nil
    }

    // MARK: - Browse Image Cache

    /// Cache mid → imageURL associations from browse results for later lookup.
    func cacheImageURLs(from items: [BrowseItem]) {
        let entries = items.compactMap { item -> (mid: String, imageURL: String)? in
            guard let mid = item.mid, !mid.isEmpty, !item.imageURL.isEmpty else { return nil }
            return (mid: mid, imageURL: item.imageURL)
        }
        guard !entries.isEmpty else { return }
        if ImageURLCache.cacheEntries(entries) {
            // Merge into in-memory dict for reactivity
            for entry in entries {
                if cachedImageURLs[entry.mid] != entry.imageURL {
                    cachedImageURLs[entry.mid] = entry.imageURL
                }
            }
        }
    }

    /// Cache individual mid → imageURL entries (used by setNowPlaying enrichment).
    func cacheImageEntries(_ entries: [(mid: String, imageURL: String)]) {
        guard !entries.isEmpty else { return }
        if ImageURLCache.cacheEntries(entries) {
            for entry in entries {
                if cachedImageURLs[entry.mid] != entry.imageURL {
                    cachedImageURLs[entry.mid] = entry.imageURL
                }
            }
        }
    }

    // MARK: - Stream MID Aliases

    /// Register an alias so resolvedImageURL can find custom artwork via browse MID.
    func registerStreamAlias(deviceMID: String, browseMID: String) {
        streamMIDAlias[deviceMID] = browseMID
    }

    /// Clear all stream aliases (called on disconnect/reset).
    func resetAliases() {
        streamMIDAlias = [:]
    }
}
