import Foundation
import NeosDomain

// MARK: - Image Cache Forwarding

extension AppState {
    func resolvedImageURL(forMID mid: String?, originalURL: String) -> String {
        // App Transport Security blocks plaintext http, so artwork served that way never loads.
        ImageURLUpscaler.httpsURL(imageCache.resolvedImageURL(forMID: mid, originalURL: originalURL))
    }

    func setCustomStationImage(url: String, forMID mid: String) {
        imageCache.setCustomStationImage(url: url, forMID: mid)
    }

    func removeCustomStationImage(forMID mid: String) {
        imageCache.removeCustomStationImage(forMID: mid)
    }

    func hasCustomStationImage(forMID mid: String?) -> Bool {
        imageCache.hasCustomStationImage(forMID: mid)
    }

    func browseMID(forDeviceMID mid: String?) -> String? {
        guard let mid, !mid.isEmpty else { return nil }
        return imageCache.streamMIDAlias[mid]
    }

    func cacheImageURLs(from items: [BrowseItem]) {
        imageCache.cacheImageURLs(from: items)
    }

    // MARK: - Now Playing Matching

    /// True when `item` is the track or station currently playing.
    /// Stations need more than mid equality: the device reports the resolved stream URL,
    /// while browse rows carry the TuneIn id (echoed in albumID) or the play-time alias.
    func isNowPlaying(_ item: BrowseItem) -> Bool {
        guard let mid = item.mid, !mid.isEmpty else { return false }
        if nowPlaying.mid == mid || AppState.sameStream(nowPlaying.mid, mid) { return true }
        if browseMID(forDeviceMID: nowPlaying.mid) == mid { return true }
        guard item.type == .station else { return false }
        // Custom-URL stations are named after the stream the device then reports as its mid,
        // which matches without needing the alias this app only has after playing it itself.
        if item.name == nowPlaying.mid || AppState.sameStream(item.name, nowPlaying.mid) { return true }
        // TuneIn stations report the station id in albumID. The station name is not a usable
        // signal here: the device often sends it empty.
        return !nowPlaying.albumID.isEmpty && nowPlaying.albumID == mid
    }

    /// The artwork to show and the higher resolution variant of that same image.
    /// Deriving the upgrade from the original URL lets the progressive fetch overwrite a
    /// custom image with the artwork it was chosen to replace.
    func artwork(forMID mid: String?, originalURL: String) -> (base: URL?, highRes: URL?) {
        let resolved = resolvedImageURL(forMID: mid, originalURL: originalURL)
        return (URL(string: resolved), ImageURLUpscaler.highResURL(from: resolved).flatMap(URL.init(string:)))
    }
}
