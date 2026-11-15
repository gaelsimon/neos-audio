import NeosDomain

enum TrackListPresentation {
    /// Albums and playlists by their type; other containers when at least half their rows are tracks.
    static func isTrackList(target: BrowseTarget?, items: [BrowseItem]) -> Bool {
        switch target?.mediaType {
        case .album, .playlist:
            return true
        case .artist, .genre:
            return false
        default:
            let tracks = items.filter { $0.playable && !$0.browsable }
            return !tracks.isEmpty && tracks.count >= items.count / 2
        }
    }

    /// A page about one thing opens on its artwork: an album, a playlist, or anything with a picture of its own.
    /// A folder of albums or stations would only borrow its first row's cover, so it opens on its list.
    static func opensOnArtwork(target: BrowseTarget, items: [BrowseItem]) -> Bool {
        if !target.imageURL.isEmpty { return true }
        let onlyStations = !items.isEmpty && items.allSatisfy { $0.type == .station }
        return isTrackList(target: target, items: items) && !onlyStations
    }

    /// The order is the album's or the playlist's own. A list of stations or of past plays has none worth a number.
    static func numbersRows(target: BrowseTarget?) -> Bool {
        switch target?.mediaType {
        case .album, .playlist: true
        default: false
        }
    }

    static func sharedAlbum(in items: [BrowseItem]) -> String? {
        sharedValue(in: items, of: \.album)
    }

    static func sharedArtist(in items: [BrowseItem]) -> String? {
        sharedValue(in: items, of: \.artist)
    }

    private static func sharedValue(in items: [BrowseItem], of field: KeyPath<BrowseItem, String?>) -> String? {
        let values = items.map { ($0[keyPath: field] ?? "").trimmingCharacters(in: .whitespaces) }
        guard let first = values.first, !first.isEmpty, values.allSatisfy({ $0 == first }) else { return nil }
        return first
    }
}
