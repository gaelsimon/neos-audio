import Foundation
import NeosDomain

/// Realistic mock data sourced from a real HEOS device (Marantz MODEL 40n).
/// Used by MockAudioService defaults and available directly in tests.
enum MockData {

    // MARK: - Music Sources (real SIDs from device)

    static let musicSources: [MusicSource] = [
        MusicSource(sid: 3, name: "TuneIn", type: "music_service"),
        MusicSource(sid: 5, name: "Deezer", type: "music_service"),
        MusicSource(sid: 10, name: "Tidal", type: "music_service"),
        MusicSource(sid: 9, name: "SoundCloud", type: "music_service"),
        MusicSource(sid: 13, name: "Amazon", type: "music_service", available: false),
        MusicSource(sid: 30, name: "Qobuz", type: "music_service", available: false),
        MusicSource(sid: 1024, name: "Local Music", type: "heos_server"),
        MusicSource(sid: 1025, name: "Playlists", type: "heos_service"),
        MusicSource(sid: 1026, name: "History", type: "heos_service"),
        MusicSource(sid: 1027, name: "AUX Input", type: "heos_service"),
        MusicSource(sid: 1028, name: "Favorites", type: "heos_service"),
    ]

    // MARK: - Browse: Deezer Root

    static let deezerRoot = BrowseResult(items: [
        BrowseItem(name: "Flow", type: .container, cid: "Flow", browsable: true),
        BrowseItem(name: "Deezer Picks", type: .container, cid: "Deezer Picks", browsable: true),
        BrowseItem(name: "What's Hot", type: .container, cid: "What's Hot", browsable: true),
        BrowseItem(name: "Radio Channels", type: .container, cid: "Radio Channels", browsable: true),
        BrowseItem(name: "Recommendations", type: .container, cid: "Recommendations", browsable: true),
        BrowseItem(name: "My Playlists", type: .container, cid: "My Playlists", browsable: true),
        BrowseItem(name: "My Albums", type: .container, cid: "My Albums", browsable: true),
        BrowseItem(name: "Favorite Artists", type: .container, cid: "Favorite Artists", browsable: true),
    ])

    // MARK: - Browse: Favorites

    static let favorites = BrowseResult(items: [
        BrowseItem(name: "FIP Hifi", type: .station, mid: "https://icecast.radiofrance.fr/fip-hifi.aac", playable: true),
        BrowseItem(name: "BBC Radio 6 Music", type: .station, mid: "s44491", playable: true),
        BrowseItem(name: "BBC Radio 4", type: .station, mid: "s25419", playable: true),
        BrowseItem(name: "Rebel Spinner PM", type: .station, mid: "s220854", playable: true),
        BrowseItem(name: "101.5 | Radio Nova (House)", type: .station, mid: "s17696", playable: true),
        BrowseItem(name: "Radio Choco", type: .station, mid: "s50262", playable: true),
        BrowseItem(name: "KEXP", type: .station, mid: "s32537", playable: true),
        BrowseItem(
            name: "WEFUNK Radio (Classic Hip Hop)",
            imageURL: "http://cdn-radiotime-logos.tunein.com/s17439q.png",
            type: .station, mid: "s17439", playable: true
        ),
    ])

    // MARK: - Browse: History Root

    static let historyRoot = BrowseResult(items: [
        BrowseItem(name: "TRACKS", type: .container, cid: "TRACKS", playable: true, browsable: true),
        BrowseItem(name: "STATIONS", type: .container, cid: "STATIONS", browsable: true),
    ])

    // MARK: - Queue Items

    static let queueItems: [QueueItem] = [
        QueueItem(
            qid: 1,
            song: "Sister Nancy - Bam Bam (Gregory House Bootleg)",
            artist: "Gregory House",
            imageURL: "https://i1.sndcdn.com/artworks-BPE9dYs5hfaDy1zs-3jeTLA-t500x500.jpg",
            mid: "soundcloud:tracks:1350748969"
        ),
        QueueItem(
            qid: 2,
            song: "EUPHORIA - Rhino Soulsystem | Mixtape",
            artist: "RHINO SOULSYSTEM",
            imageURL: "https://i1.sndcdn.com/artworks-NbSrsjGmETtLoK1g-FVA00Q-t500x500.jpg",
            mid: "soundcloud:tracks:1969502487"
        ),
    ]

    // MARK: - Search: Artists (Deezer "radiohead")

    static let searchArtists = BrowseResult(items: [
        BrowseItem(
            name: "Radiohead",
            imageURL: "http://api.deezer.com/2.0/artist/399/image?size=small",
            type: .artist, cid: "Artists-399", browsable: true
        ),
        BrowseItem(
            name: "Gigamesh",
            imageURL: "http://api.deezer.com/2.0/artist/1431492/image?size=small",
            type: .artist, cid: "Artists-1431492", browsable: true
        ),
        BrowseItem(
            name: "NTO",
            imageURL: "http://api.deezer.com/2.0/artist/171883/image?size=small",
            type: .artist, cid: "Artists-171883", browsable: true
        ),
        BrowseItem(
            name: "DJ Radiohead",
            imageURL: "http://api.deezer.com/2.0/artist/53477202/image?size=small",
            type: .artist, cid: "Artists-53477202", browsable: true
        ),
    ], count: 11)

    // MARK: - Search: Tracks (Deezer "creep")

    static let searchTracks = BrowseResult(items: [
        BrowseItem(
            name: "Creep",
            imageURL: "http://api.deezer.com/2.0/album/14880711/image?size=big",
            mid: "138547415", playable: true,
            artist: "Radiohead", album: "Pablo Honey"
        ),
        BrowseItem(
            name: "Creep (Acoustic)",
            imageURL: "http://api.deezer.com/2.0/album/423524437/image?size=big",
            mid: "2215315187", playable: true,
            artist: "Radiohead", album: "Creep EP"
        ),
        BrowseItem(
            name: "Creepin'",
            imageURL: "http://api.deezer.com/2.0/album/382760377/image?size=big",
            mid: "2047662477", playable: true,
            artist: "Metro Boomin", album: "HEROES & VILLAINS"
        ),
        BrowseItem(
            name: "Creep",
            imageURL: "http://api.deezer.com/2.0/album/6453025/image?size=big",
            mid: "65823405", playable: true,
            artist: "Daniela Andrade", album: "Covers, Vol. 1"
        ),
        BrowseItem(
            name: "Bling-Bang-Bang-Born",
            imageURL: "http://api.deezer.com/2.0/album/522318972/image?size=big",
            mid: "2580253682", playable: true,
            artist: "Creepy Nuts", album: "Bling-Bang-Bang-Born"
        ),
    ], count: 238)

    // MARK: - Search Criteria (Deezer)

    static let searchCriteria: [SearchCriteria] = [
        SearchCriteria(scid: 1, name: "Artist"),
        SearchCriteria(scid: 2, name: "Album"),
        SearchCriteria(scid: 3, name: "Track"),
    ]

    // MARK: - Discovery

    static let discoveredDevice = DiscoveredDevice(
        host: "192.168.8.219",
        friendlyName: "Marantz MODEL 40n",
        modelName: "Marantz MODEL 40n",
        serialNumber: "MBQB092301773",
        firmwareVersion: "3.88.532"
    )
}
