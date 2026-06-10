import Foundation
import NeosDomain

/// Populates AppState with realistic sample data for UI tests and demo mode.
/// Driven by the `--demo-mode` launch argument; no network required.
@MainActor
enum DemoDataProvider {

    // Multi-player demo: AVR main zone, AVR Zone 2, standalone Home 150 pair.
    // Mirrors a real setup (Denon x2800h + HEOS Home 150 stereo pair).
    static let avrMainZonePID = 1_845_498_270
    static let avrZone2PID = 1_845_498_271
    static let home150PID = 927_361_084

    /// The player that should be auto-selected (standalone speaker, lineout == 0).
    static let playerID = home150PID

    // MARK: - Public Entry Point

    static func populate(_ state: AppState) {
        state.setConnectionState(.connected)

        state.connectedDevice = DiscoveredDevice(
            host: "192.0.2.10",
            port: 1255,
            friendlyName: "Denon AVR-X2800H",
            modelName: "Denon - AVR-X2800H",
            modelNumber: "AVR-X2800H",
            serialNumber: "ABC123456"
        )

        state.setPlayers([
            Player(
                pid: avrMainZonePID,
                name: "Denon AVR-X2800H",
                model: "Denon - AVR-X2800H",
                version: "3.34.510",
                ip: "192.0.2.10",
                network: .wired,
                lineout: 2,
                serial: "ABC123456"
            ),
            Player(
                pid: avrZone2PID,
                name: "Denon AVR-X2800H - Zone 2",
                model: "Denon - AVR-X2800H",
                version: "3.34.510",
                ip: "192.0.2.10",
                network: .wired,
                lineout: 2,
                serial: "ABC123456",
                control: 3
            ),
            Player(
                pid: home150PID,
                name: "Home 150 Pair",
                model: "HEOS Home 150",
                version: "3.34.510",
                ip: "192.0.2.20",
                network: .wifi,
                lineout: 0,
                serial: "H150PAIR01"
            )
        ])
        state.setSelectedPlayerID(playerID)

        setupPlayback(state)

        // Queue
        state.setQueue(queue)

        // Music sources
        state.setMusicSources(musicSources)

        // Search, capabilities, account
        setupSearchAndAccount(state)
    }

    private static func setupPlayback(_ state: AppState) {
        state.setPlayState(.play)
        state.setNowPlaying(NowPlayingMedia(
            type: .song,
            song: "Bohemian Rhapsody",
            album: "A Night at the Opera",
            artist: "Queen",
            imageURL: "https://e-cdns-images.dzcdn.net/images/cover/abc123/500x500.jpg",
            albumID: "alb-67890",
            mid: "dz-12345",
            qid: 3,
            sid: 2
        ))

        state.setTrackMetadata(TrackMetadata(
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            codec: "FLAC",
            genre: "Rock",
            trackNumber: 11
        ))

        state.setVolume(45)
        state.setMaxVolume(100)
        state.setMuted(false)
        state.setRepeatMode(.off)
        state.setShuffleMode(.off)
        state.setProgress(position: 92_000, duration: 354_000)
    }

    private static func setupSearchAndAccount(_ state: AppState) {
        let deezerCriteria = [
            SearchCriteria(scid: 1, name: "Artist"),
            SearchCriteria(scid: 2, name: "Album"),
            SearchCriteria(scid: 3, name: "Track"),
            SearchCriteria(scid: 4, name: "Playlist")
        ]
        state.browse.searchCriteria[2] = deezerCriteria
        state.setServiceCapabilities(sid: 2, capabilities: ServiceCapabilities(from: deezerCriteria))
        state.setSignedInUser("user@example.com")
    }

    // MARK: - Sample Data

    static let queue: [QueueItem] = [
        QueueItem(
            qid: 1,
            song: "Somebody to Love",
            album: "A Day at the Races",
            artist: "Queen",
            imageURL: "https://e-cdns-images.dzcdn.net/images/cover/races/250x250.jpg",
            mid: "dz-11111",
            albumID: "alb-aaaaa"
        ),
        QueueItem(
            qid: 2,
            song: "Don't Stop Me Now",
            album: "Jazz",
            artist: "Queen",
            imageURL: "https://e-cdns-images.dzcdn.net/images/cover/jazz/250x250.jpg",
            mid: "dz-22222",
            albumID: "alb-bbbbb"
        ),
        QueueItem(
            qid: 3,
            song: "Bohemian Rhapsody",
            album: "A Night at the Opera",
            artist: "Queen",
            imageURL: "https://e-cdns-images.dzcdn.net/images/cover/opera/250x250.jpg",
            mid: "dz-12345",
            albumID: "alb-67890"
        ),
        QueueItem(
            qid: 4,
            song: "Under Pressure",
            album: "Hot Space",
            artist: "Queen & David Bowie",
            imageURL: "https://e-cdns-images.dzcdn.net/images/cover/hot/250x250.jpg",
            mid: "dz-33333",
            albumID: "alb-ccccc"
        )
    ]

    // Demo sources omit imageURL; ServiceBranding falls back to bundled asset logos.
    static let musicSources: [MusicSource] = [
        MusicSource(
            sid: 2, name: "Deezer",
            type: "music_service", available: true, serviceUsername: "user@example.com"
        ),
        MusicSource(
            sid: 3, name: "TuneIn",
            type: "music_service", available: true
        ),
        MusicSource(
            sid: 9, name: "Spotify",
            type: "music_service", available: true, serviceUsername: "spotify_user"
        ),
        MusicSource(
            sid: 10, name: "TIDAL",
            type: "music_service", available: false
        ),
        MusicSource(
            sid: 13, name: "Amazon Music",
            type: "music_service", available: false
        ),
        MusicSource(sid: 1027, name: "AUX Input", type: "heos_server", available: true),
        MusicSource(sid: 1028, name: "Favorites", type: "heos_service", available: true),
        MusicSource(sid: 1025, name: "Playlists", type: "heos_service", available: true),
        MusicSource(sid: 1026, name: "History", type: "heos_service", available: true)
    ]

    static let favorites: [BrowseItem] = [
        BrowseItem(name: "BBC Radio 1", imageURL: "https://cdn-radiotime-logos.tunein.com/s24939.png", type: .station, cid: "1028", mid: "s/24939", sid: 3, playable: true),
        BrowseItem(name: "FIP", imageURL: "https://cdn-radiotime-logos.tunein.com/s15200.png", type: .station, cid: "1028", mid: "s/15200", sid: 3, playable: true),
        BrowseItem(name: "Flow", imageURL: "https://e-cdns-images.dzcdn.net/images/misc/flow.png", type: .station, cid: "1028", mid: "dz-flow", sid: 2, playable: true)
    ]

    static let history: [BrowseItem] = [
        BrowseItem(
            name: "Bohemian Rhapsody", imageURL: "https://e-cdns-images.dzcdn.net/images/cover/abc123/250x250.jpg",
            type: .song, mid: "dz-12345", sid: 2, playable: true, artist: "Queen", album: "A Night at the Opera"
        ),
        BrowseItem(name: "Jazz Radio", imageURL: "https://cdn-radiotime-logos.tunein.com/s12345.png",
                   type: .station, mid: "s/12345", sid: 3, playable: true),
        BrowseItem(
            name: "Discovery", imageURL: "https://e-cdns-images.dzcdn.net/images/cover/def456/250x250.jpg",
            type: .album, cid: "dz-album-7890", mid: "dz-album-7890", sid: 2,
            playable: true, browsable: true, artist: "Daft Punk"
        ),
        BrowseItem(
            name: "Chill Vibes", imageURL: "https://e-cdns-images.dzcdn.net/images/playlist/ghi789/250x250.jpg",
            type: .playlist, cid: "dz-playlist-555", mid: "dz-playlist-555", sid: 2, playable: true, browsable: true
        ),
        BrowseItem(name: "BBC Radio 6 Music", imageURL: "https://cdn-radiotime-logos.tunein.com/s44491.png",
                   type: .station, mid: "s/44491", sid: 3, playable: true),
        BrowseItem(
            name: "Random Access Memories", imageURL: "https://e-cdns-images.dzcdn.net/images/cover/jkl012/250x250.jpg",
            type: .album, cid: "dz-album-1234", mid: "dz-album-1234", sid: 2,
            playable: true, browsable: true, artist: "Daft Punk"
        ),
    ]

    static let searchTracks: [BrowseItem] = [
        BrowseItem(name: "Anti-Hero", imageURL: "https://e-cdns-images.dzcdn.net/images/cover/midnights/250x250.jpg", type: .song, mid: "dz-1896030", playable: true, artist: "Taylor Swift", album: "Midnights"),
        BrowseItem(name: "All of Me", imageURL: "https://e-cdns-images.dzcdn.net/images/cover/love/250x250.jpg", type: .song, mid: "dz-6848228", playable: true, artist: "John Legend", album: "Love in the Future"),
        BrowseItem(name: "As It Was", imageURL: "https://e-cdns-images.dzcdn.net/images/cover/harrys/250x250.jpg", type: .song, mid: "dz-1711080", playable: true, artist: "Harry Styles", album: "Harry's House"),
        BrowseItem(name: "Aint No Sunshine", imageURL: "https://e-cdns-images.dzcdn.net/images/cover/best/250x250.jpg", type: .song, mid: "dz-5324880", playable: true, artist: "Bill Withers", album: "Just As I Am"),
        BrowseItem(name: "Africa", imageURL: "https://e-cdns-images.dzcdn.net/images/cover/toto/250x250.jpg", type: .song, mid: "dz-668810", playable: true, artist: "Toto", album: "Toto IV")
    ]
}
