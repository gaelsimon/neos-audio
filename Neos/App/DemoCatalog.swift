import Foundation
import NeosDomain

#if DEBUG
/// What the demo's sources hold beyond the home page: every kind of page, plus the odd cases a real library has.
enum DemoCatalog {
    static let deezerSID = 2
    static let tuneInSID = 3
    static let tidalSID = 10
    static let localMusicSID = 1024
    static let playlistsSID = 1025
    static let auxSID = 1027
    /// Sub-sources, browsed by their own sid like a DLNA server or the amp's inputs.
    static let nasSID = 60_001
    static let emptyServerSID = 60_002
    static let ampInputsSID = 60_003

    /// A folder whose listing fails, for the error page and its retry.
    static let brokenCID = "demo-broken"
    /// A playlist long enough to arrive in several pages.
    static let longPlaylistCID = "pl-road"
    static let longPlaylistCount = 120

    struct Failure: LocalizedError {
        var errorDescription: String? { "The demo source did not answer." }
    }

    // MARK: - Pages

    static func page(_ items: [BrowseItem], _ range: ClosedRange<Int>?) -> BrowseResult {
        guard let range else {
            return BrowseResult(items: items, returned: items.count, count: items.count)
        }
        let slice = Array(items.dropFirst(range.lowerBound).prefix(range.count))
        return BrowseResult(items: slice, returned: slice.count, count: items.count)
    }

    // MARK: - Roots

    static func root(of sid: Int) -> [BrowseItem]? {
        switch sid {
        case tuneInSID:
            [
                folder("Local Radio", "ti-local", sid: sid),
                folder("Music", "ti-music", sid: sid),
                folder("Talk", brokenCID, sid: sid),
                folder("Podcasts", "ti-podcasts", sid: sid),
            ]
        case playlistsSID:
            [
                playlist("Dinner", "hp-dinner", sid: sid, art: "opera"),
                playlist("Workout", "hp-workout", sid: sid),
            ]
        case auxSID:
            [BrowseItem(name: "Living Room", type: .heosServer, sid: ampInputsSID)]
        case ampInputsSID:
            ["AUX In", "Optical In", "Coaxial In", "CD", "Phono", "TV Audio", "HDMI ARC", "Bluetooth", "USB"].map { input in
                BrowseItem(
                    name: "Living Room - \(input)", type: .station,
                    mid: "inputs/\(input.lowercased().replacingOccurrences(of: " ", with: "_"))", sid: sid, playable: true
                )
            }
        case localMusicSID:
            [
                BrowseItem(name: "Attic NAS", type: .dlnaServer, sid: nasSID),
                BrowseItem(name: "Studio Mac", type: .dlnaServer, sid: emptyServerSID),
            ]
        case nasSID:
            [folder("Music", "nas-music", sid: sid), folder("Playlists", "nas-playlists", sid: sid)]
        case emptyServerSID:
            []
        default:
            nil
        }
    }

    // MARK: - Containers

    static func container(sid: Int, cid: String) -> [BrowseItem]? {
        switch cid {
        case "cat-albums": DemoDataProvider.deezerAlbums
        case "album-opera": DemoDataProvider.deezerAlbumTracks
        case "td-albums": DemoDataProvider.tidalAlbums
        case "td-album-blue": DemoDataProvider.tidalAlbumTracks
        case "ti-local": stations
        case "ti-music": [folder("Jazz", "ti-jazz", sid: sid)]
        case "ti-jazz": Array(stations.prefix(2))
        case "ti-podcasts", "nas-playlists", "pl-empty": []
        case "cat-artists", "td-artists": artists(sid: sid)
        case "artist-velvet": Array(DemoDataProvider.deezerAlbums.prefix(1))
        case "artist-neon": Array(DemoDataProvider.deezerAlbums.suffix(1))
        case "cat-playlists":
            [playlist("Road Trip", longPlaylistCID, sid: sid), playlist("Nothing Yet", "pl-empty", sid: sid)]
        case "td-playlists": [playlist("Sunday Morning", "td-pl", sid: sid)]
        case longPlaylistCID: longPlaylist
        case "album-ram", "dz-album-1234":
            tracks(["Tape Hiss", "Signal Path", "Warm Circuit"], artist: "Neon Harbor", album: "Analog Dreams", sid: sid)
        case "dz-album-7890": tracks(["Night Drive", "Underpass", "Amber Signal"], artist: "Neon Harbor", album: "Night Drive", sid: sid)
        case "dz-playlist-555": tracks(["Soft Landing", "Slow Tide"], artist: "Mila Rae", album: nil, sid: sid)
        case "td-album-coast": tracks(["Savanna Light", "Harbour Mouth"], artist: "Coastline", album: "Coastline IV", sid: sid)
        case "td-pl", "hp-dinner": tracks(["Low Sun", "Second Cup", "Open Window"], artist: "June Avery", album: nil, sid: sid)
        case "hp-workout": tracks(["Sprint", "Climb"], artist: nil, album: nil, sid: sid)
        case "nas-music": [folder("Albums", "nas-albums", sid: sid)]
        case "nas-albums":
            [BrowseItem(name: "Field Recordings", type: .container, cid: "nas-album-1", sid: sid, playable: true, browsable: true)]
        case "nas-album-1":
            tracks(["Harbour at Dawn", "Rain on Tin", "Night Train"], artist: "Unknown Artist", album: "Field Recordings", sid: sid)
        default: nil
        }
    }

    // MARK: - Playing

    /// What an add to the queue names: the track with that mid, else every track the container lists.
    static func tracks(sid: Int, cid: String, mid: String?) -> [DemoTrack] {
        let listed = container(sid: sid, cid: cid) ?? []
        let cover = albums.first { $0.cid == cid }?.imageURL ?? ""
        let loose = DemoDataProvider.searchTracks + DemoDataProvider.history
        if let mid, let item = (listed + loose).first(where: { $0.mid == mid && $0.type == .song }) {
            return [track(item, sid: sid, cover: cover)]
        }
        return listed.filter { $0.type == .song }.map { track($0, sid: sid, cover: cover) }
    }

    /// A track of the opening queue stays the same track wherever it is listed.
    private static func track(_ item: BrowseItem, sid: Int, cover: String) -> DemoTrack {
        DemoDataProvider.openingTracks.first { $0.mid == item.mid } ?? DemoTrack(item, sid: sid, cover: cover)
    }

    /// A station as a speaker reports it: no track title, the name in `station`.
    static func station(sid: Int, mid: String, name: String) -> NowPlayingMedia {
        let known = (stations + DemoDataProvider.favorites + DemoDataProvider.history).first { $0.mid == mid }
        return NowPlayingMedia(
            type: .station, imageURL: known?.imageURL ?? "",
            albumID: mid.replacingOccurrences(of: "/", with: ""), mid: mid, sid: sid, station: name
        )
    }

    static let addFavorite = ServiceOption(context: .play, id: ServiceOption.addToFavoritesID, name: "Add to HEOS Favorites")
    static let removeFavorite = ServiceOption(
        context: .browse, id: ServiceOption.removeFromFavoritesID, name: "Remove from HEOS Favorites"
    )

    static func favorite(named name: String, mid: String, sid: Int) -> BrowseItem {
        BrowseItem(
            name: name, imageURL: stations.first { $0.mid == mid }?.imageURL ?? "", type: .station,
            cid: String(HEOSConstants.favoritesSID), mid: mid, sid: sid, playable: true
        )
    }

    static func input(_ mid: String) -> NowPlayingMedia {
        let name = root(of: ampInputsSID)?.first { $0.mid == mid }?.name ?? mid
        return NowPlayingMedia(type: .station, song: name, mid: mid, sid: auxSID)
    }

    private static var albums: [BrowseItem] {
        DemoDataProvider.deezerAlbums + DemoDataProvider.tidalAlbums + DemoDataProvider.history
    }

    // MARK: - Search

    static func criteria(for sid: Int) -> [SearchCriteria] {
        if sid == tuneInSID {
            return [SearchCriteria(scid: 1, name: "Station")]
        }
        return [
            SearchCriteria(scid: 1, name: "Artist"),
            SearchCriteria(scid: 2, name: "Album"),
            SearchCriteria(scid: 3, name: "Track"),
            SearchCriteria(scid: 4, name: "Playlist"),
        ]
    }

    /// One kind of item per criterion, and nothing at all for a query with "zzz" in it.
    static func search(sid: Int, scid: Int, query: String) -> [BrowseItem] {
        if query.lowercased().contains("zzz") { return [] }
        if sid == tuneInSID { return stations }
        switch scid {
        case 1: return artists(sid: sid)
        case 2: return sid == tidalSID ? DemoDataProvider.tidalAlbums : DemoDataProvider.deezerAlbums
        case 4: return [playlist("Road Trip", longPlaylistCID, sid: sid)]
        default: return DemoDataProvider.searchTracks
        }
    }

    // MARK: - Items

    private static let stations: [BrowseItem] = [
        station("Pulse FM", "s/24939", art: "s24939"),
        station("Eclectic FM", "s/15200", art: "s15200"),
        station("Radio Without a Cover", "s/30001", art: nil),
        station("The Community Station That Broadcasts All Night Long From The Old Harbour 101.5", "s/30002", art: nil),
    ]

    private static let longPlaylist: [BrowseItem] = (1...longPlaylistCount).map { number in
        BrowseItem(
            name: number == 3 ? "A Title Long Enough To Run Past The Edge Of Any Row It Is Shown In (Extended Live Version)" : "Mile \(number)",
            type: .song, mid: "road-\(number)", sid: deezerSID, playable: true,
            artist: number.isMultiple(of: 7) ? nil : (number.isMultiple(of: 2) ? "The Velvet Hours" : "Neon Harbor"),
            album: "Road Trip"
        )
    }

    private static func artists(sid: Int) -> [BrowseItem] {
        [
            BrowseItem(name: "The Velvet Hours", imageURL: DemoArtwork.url("abc123"), type: .artist, cid: "artist-velvet", sid: sid, browsable: true),
            BrowseItem(name: "Neon Harbor", type: .artist, cid: "artist-neon", sid: sid, browsable: true),
        ]
    }

    private static func folder(_ name: String, _ cid: String, sid: Int) -> BrowseItem {
        BrowseItem(name: name, type: .container, cid: cid, sid: sid, browsable: true)
    }

    private static func playlist(_ name: String, _ cid: String, sid: Int, art: String? = nil) -> BrowseItem {
        BrowseItem(
            name: name, imageURL: art.map(DemoArtwork.url) ?? "", type: .playlist,
            cid: cid, sid: sid, playable: true, browsable: true
        )
    }

    private static func station(_ name: String, _ mid: String, art: String?) -> BrowseItem {
        BrowseItem(name: name, imageURL: art.map(DemoArtwork.url) ?? "", type: .station, mid: mid, sid: tuneInSID, playable: true)
    }

    private static func tracks(_ names: [String], artist: String?, album: String?, sid: Int) -> [BrowseItem] {
        names.enumerated().map { index, name in
            BrowseItem(name: name, type: .song, mid: "demo-\(sid)-\(name)-\(index)", sid: sid, playable: true, artist: artist, album: album)
        }
    }
}
#endif
