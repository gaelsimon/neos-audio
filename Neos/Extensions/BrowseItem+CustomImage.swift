import NeosDomain

extension BrowseItem {
    /// Stable key for custom artwork: prefer mid (tracks/stations), fall back to cid (containers).
    var imageKey: String? { mid ?? cid }

    /// Image URL resolved through custom artwork → cached browse URL → original.
    var resolvedImageURL: String {
        if let key = imageKey {
            if let custom = StationImageStore.imageURL(forMID: key), !custom.isEmpty {
                return custom
            }
            if imageURL.isEmpty, let cached = ImageURLCache.imageURL(forMID: key), !cached.isEmpty {
                return cached
            }
        }
        return imageURL
    }
}

extension NowPlayingMedia {
    /// Image URL resolved through custom artwork → cached browse URL → original.
    var resolvedImageURL: String {
        if !mid.isEmpty {
            if let custom = StationImageStore.imageURL(forMID: mid), !custom.isEmpty {
                return custom
            }
            if imageURL.isEmpty, let cached = ImageURLCache.imageURL(forMID: mid), !cached.isEmpty {
                return cached
            }
        }
        return imageURL
    }
}
