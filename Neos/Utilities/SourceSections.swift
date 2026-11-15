import NeosDomain

/// The sources the Mac sidebar and the iPhone library list, section by section.
struct SourceSections {
    struct LibraryEntry: Identifiable {
        let source: MusicSource
        let title: String
        let symbol: String

        var id: Int { source.sid }
    }

    let services: [MusicSource]
    let local: [MusicSource]
    let library: [LibraryEntry]

    private static let libraryOrder = [
        (sid: HEOSConstants.favoritesSID, title: "Favorites", symbol: DS.Icons.radio),
        (sid: HEOSConstants.playlistsSID, title: "Playlists", symbol: DS.Icons.playlists),
        (sid: HEOSConstants.historySID, title: "History", symbol: DS.Icons.historyUnfilled),
    ]

    init(sources: [MusicSource], signedIn: Bool, hidden: Set<Int>) {
        let others = sources.filter { !HEOSConstants.librarySIDs.contains($0.sid) }
        // Hidden after listing: hiding the one linked service must not bring back the unlinked ones.
        services = MusicSource.listed(others, signedIn: signedIn).filter { !hidden.contains($0.sid) }
        local = others.filter { $0.type != "music_service" && !hidden.contains($0.sid) }
        library = Self.libraryOrder.map { entry in
            LibraryEntry(
                source: sources.first { $0.sid == entry.sid } ?? MusicSource(sid: entry.sid, name: entry.title),
                title: entry.title,
                symbol: entry.symbol
            )
        }
    }
}
