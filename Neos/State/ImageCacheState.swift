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

        // 2. Auto-discovered URL from a previous browse; the URL streams' placeholder names no media.
        if originalURL.isEmpty {
            if mid != HEOSConstants.urlStreamPlaceholderID, let cached = cachedImageURLs[mid], !cached.isEmpty {
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
            for entry in entries where cachedImageURLs[entry.mid] != entry.imageURL {
                cachedImageURLs[entry.mid] = entry.imageURL
            }
        }
    }

    /// Cache individual mid → imageURL entries (used by setNowPlaying enrichment).
    func cacheImageEntries(_ entries: [(mid: String, imageURL: String)]) {
        guard !entries.isEmpty else { return }
        if ImageURLCache.cacheEntries(entries) {
            for entry in entries where cachedImageURLs[entry.mid] != entry.imageURL {
                cachedImageURLs[entry.mid] = entry.imageURL
            }
        }
    }

    // MARK: - Stream MID Aliases

    /// Register an alias so resolvedImageURL can find custom artwork via browse MID.
    func registerStreamAlias(deviceMID: String, browseMID: String) {
        streamMIDAlias[deviceMID] = browseMID
    }

    func removeStreamAlias(deviceMID: String) {
        streamMIDAlias[deviceMID] = nil
    }

    // MARK: - Stations Saved By Address

    struct StreamStation: Equatable {
        /// Nil when the station was saved under its address alone.
        let name: String?
        let browseMID: String
        let imageURL: String
    }

    private(set) var stationsByStream: [String: StreamStation] = [:]
    private(set) var stationNames: [String: String] = [:]

    /// By the station id a speaker echoes as the album id, by the row it was played from, or by its stream.
    func stationName(for media: NowPlayingMedia) -> String? {
        let ids = [media.albumID, streamMIDAlias[media.mid] ?? "", media.mid]
        return ids.lazy.compactMap { self.stationNames[$0] }.first ?? station(forStream: media.mid)?.name
    }

    func rememberStations(from items: [BrowseItem]) {
        for item in items where item.type == .station {
            guard let mid = item.mid, !mid.isEmpty else { continue }
            if !StreamAddress.isAddress(item.name), stationNames[mid] != item.name { stationNames[mid] = item.name }
            guard let address = [mid, item.name].first(where: StreamAddress.isAddress) else { continue }
            let station = StreamStation(
                name: StreamAddress.isAddress(item.name) ? nil : item.name,
                browseMID: mid,
                imageURL: item.imageURL
            )
            let key = StreamAddress.withoutScheme(address)
            if stationsByStream[key] != station { stationsByStream[key] = station }
        }
    }

    func rememberStation(_ station: StreamStation, forStream address: String) {
        stationsByStream[StreamAddress.withoutScheme(address)] = station
    }

    func station(forStream address: String) -> StreamStation? {
        stationsByStream[StreamAddress.withoutScheme(address)]
    }

    /// Clear all stream aliases (called on disconnect/reset).
    func resetAliases() {
        streamMIDAlias = [:]
    }
}
