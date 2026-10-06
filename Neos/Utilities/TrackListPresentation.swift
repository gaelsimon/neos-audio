import NeosDomain

enum TrackListPresentation {
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
