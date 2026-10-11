import Foundation
import NeosDomain

#if DEBUG
/// Populates AppState with realistic sample data for UI tests and demo mode.
/// Driven by the `--demo-mode` launch argument; no network required.
@MainActor
enum DemoDataProvider {

    // Multi-player demo: AVR main zone, AVR Zone 2, standalone Home 150 pair.
    // Mirrors a real setup (Denon x2800h + HEOS Home 150 stereo pair).
    static let avrMainZonePID = 1_845_498_270
    static let avrZone2PID = 1_845_498_271
    static let home150PID = 927_361_084

    // Kitchen stereo pair (collapses to one row) + Den/Bath multi-room group (stays expanded).
    static let kitchenLeftPID = 5_001
    static let kitchenRightPID = 5_002
    static let denPID = 5_003
    static let bathPID = 5_004

    /// Per-speaker demo volume so the group volume sliders show distinct values.
    static func volume(for pid: Int) -> Int {
        switch pid {
        case kitchenLeftPID: return 42
        case kitchenRightPID: return 38
        case denPID: return 55
        case bathPID: return 30
        default: return 45
        }
    }

    /// The player that should be auto-selected (standalone speaker, lineout == 0).
    static let playerID = home150PID

    /// Demo groups: a stereo pair (Kitchen) and a multi-room group (Den + Bathroom).
    static let groups: [SpeakerGroup] = [
        SpeakerGroup(gid: kitchenLeftPID, name: "Kitchen", players: [
            GroupPlayer(name: "Kitchen Left", pid: kitchenLeftPID, role: .leader),
            GroupPlayer(name: "Kitchen Right", pid: kitchenRightPID, role: .member)
        ]),
        SpeakerGroup(gid: denPID, name: "Den + Bathroom", players: [
            GroupPlayer(name: "Den", pid: denPID, role: .leader),
            GroupPlayer(name: "Bathroom", pid: bathPID, role: .member)
        ])
    ]

    /// Demo players: both AVR zones, the Home 150 pair, and the Kitchen/Den members.
    static let players: [Player] = [
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
            name: "Living Room",
            model: "HEOS Home 150",
            version: "3.34.510",
            ip: "192.0.2.20",
            network: .wifi,
            lineout: 0,
            serial: "H150PAIR01"
        ),
        Player(pid: kitchenLeftPID, name: "Kitchen Left", model: "HEOS Home 150",
               ip: "192.0.2.30", network: .wifi, lineout: 0, serial: "H150KITL"),
        Player(pid: kitchenRightPID, name: "Kitchen Right", model: "HEOS Home 150",
               ip: "192.0.2.31", network: .wifi, lineout: 0, serial: "H150KITR"),
        Player(pid: denPID, name: "Den", model: "HEOS Home 350",
               ip: "192.0.2.40", network: .wifi, lineout: 0, serial: "H350DEN"),
        Player(pid: bathPID, name: "Bathroom", model: "HEOS 1",
               ip: "192.0.2.41", network: .wifi, lineout: 0, serial: "H1BATH")
    ]

    /// The AVR the demo session is "connected" to.
    static let connectedDevice = DiscoveredDevice(
        host: "192.0.2.10",
        port: 1255,
        friendlyName: "Denon AVR-X2800H",
        modelName: "Denon - AVR-X2800H",
        modelNumber: "AVR-X2800H",
        serialNumber: "ABC123456"
    )

    // MARK: - Public Entry Point

    static func populate(_ state: AppState) {
        // Demo topology is fictional; keep it out of the persisted discovery caches.
        state.persistsDiscoveryCaches = false
        state.setConnectionState(.connected)

        state.connectedDevice = connectedDevice

        state.setPlayers(players)

        // Kitchen is a stereo pair (collapses to one row); Den + Bathroom is multi-room (expanded).
        state.setGroups(groups)
        state.setMultiRoomGroups([denPID])

        state.setSelectedPlayerID(playerID)

        setupPlayback(state)

        // Queue
        state.setQueue(queue)

        // Music sources; `--demo-services-unavailable` mimics a speaker that is signed in yet refuses every service.
        if CommandLine.arguments.contains("--demo-services-unavailable") {
            state.setMusicSources(musicSources.map { source in
                MusicSource(sid: source.sid, name: source.name, imageURL: source.imageURL, type: source.type,
                            available: source.type != "music_service", serviceUsername: source.serviceUsername)
            })
        } else {
            state.setMusicSources(musicSources)
        }

        // Search, capabilities, account
        setupSearchAndAccount(state)
    }

    private static func setupPlayback(_ state: AppState) {
        state.setPlayState(.play)
        state.setNowPlaying(NowPlayingMedia(
            type: .song,
            song: "Paper Lanterns",
            album: "Midnight Opera",
            artist: "The Velvet Hours",
            imageURL: DemoArtwork.url("abc123"),
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
        let criteria = [
            SearchCriteria(scid: 1, name: "Artist"),
            SearchCriteria(scid: 2, name: "Album"),
            SearchCriteria(scid: 3, name: "Track"),
            SearchCriteria(scid: 4, name: "Playlist")
        ]
        for sid in [2, 10] {
            state.browse.searchCriteria[sid] = criteria
            state.setServiceCapabilities(sid: sid, capabilities: ServiceCapabilities(from: criteria))
        }
        state.setSignedInUser("user@example.com")
    }

    // MARK: - Sample Data

    static let queue: [QueueItem] = [
        QueueItem(
            qid: 1,
            song: "Someone Like Summer",
            album: "Daylight Races",
            artist: "The Velvet Hours",
            imageURL: DemoArtwork.url("races"),
            mid: "dz-11111",
            albumID: "alb-aaaaa"
        ),
        QueueItem(
            qid: 2,
            song: "Keep the Lights On",
            album: "Jazz",
            artist: "The Velvet Hours",
            imageURL: DemoArtwork.url("jazz"),
            mid: "dz-22222",
            albumID: "alb-bbbbb"
        ),
        QueueItem(
            qid: 3,
            song: "Paper Lanterns",
            album: "Midnight Opera",
            artist: "The Velvet Hours",
            imageURL: DemoArtwork.url("opera"),
            mid: "dz-12345",
            albumID: "alb-67890"
        ),
        QueueItem(
            qid: 4,
            song: "Glass Weather",
            album: "Warm Rooms",
            artist: "The Velvet Hours & Nova Lane",
            imageURL: DemoArtwork.url("hot"),
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
            sid: 10, name: "TIDAL",
            type: "music_service", available: true, serviceUsername: "user@example.com"
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

    /// Deezer (sid 2) browse tree, so demo mode can be driven past a source root.
    static let deezerCategories: [BrowseItem] = [
        BrowseItem(name: "Albums", type: .container, cid: "cat-albums", sid: 2, browsable: true),
        BrowseItem(name: "Artists", type: .container, cid: "cat-artists", sid: 2, browsable: true),
        BrowseItem(name: "Playlists", type: .container, cid: "cat-playlists", sid: 2, browsable: true)
    ]

    static let deezerAlbums: [BrowseItem] = [
        BrowseItem(
            name: "Midnight Opera", imageURL: DemoArtwork.url("abc123"),
            type: .album, cid: "album-opera", sid: 2, browsable: true, artist: "The Velvet Hours"
        ),
        BrowseItem(
            name: "Analog Dreams", imageURL: DemoArtwork.url("def456"),
            type: .album, cid: "album-ram", sid: 2, browsable: true, artist: "Neon Harbor"
        )
    ]

    static let deezerAlbumTracks: [BrowseItem] = [
        BrowseItem(
            name: "Paper Lanterns", type: .song, mid: "dz-12345", sid: 2,
            playable: true, artist: "The Velvet Hours", album: "Midnight Opera"
        ),
        BrowseItem(
            name: "Slow Orbit", type: .song, mid: "dz-12346", sid: 2,
            playable: true, artist: "The Velvet Hours", album: "Midnight Opera"
        )
    ]

    /// TIDAL (sid 10) browse tree, a second signed-in service beside Deezer.
    static let tidalCategories: [BrowseItem] = [
        BrowseItem(name: "Albums", type: .container, cid: "td-albums", sid: 10, browsable: true),
        BrowseItem(name: "Artists", type: .container, cid: "td-artists", sid: 10, browsable: true),
        BrowseItem(name: "Playlists", type: .container, cid: "td-playlists", sid: 10, browsable: true)
    ]

    static let tidalAlbums: [BrowseItem] = [
        BrowseItem(
            name: "Blue Hour", imageURL: DemoArtwork.url("midnights"),
            type: .album, cid: "td-album-blue", sid: 10, browsable: true, artist: "Mila Rae"
        ),
        BrowseItem(
            name: "Coastline IV", imageURL: DemoArtwork.url("toto"),
            type: .album, cid: "td-album-coast", sid: 10, browsable: true, artist: "Coastline"
        )
    ]

    static let tidalAlbumTracks: [BrowseItem] = [
        BrowseItem(
            name: "Paper Hearts", type: .song, mid: "td-1896030", sid: 10,
            playable: true, artist: "Mila Rae", album: "Blue Hour"
        ),
        BrowseItem(
            name: "Harbour Lights", type: .song, mid: "td-1896031", sid: 10,
            playable: true, artist: "Mila Rae", album: "Blue Hour"
        )
    ]

    static let favorites: [BrowseItem] = [
        BrowseItem(name: "Pulse FM", imageURL: DemoArtwork.url("s24939"), type: .station, cid: "1028", mid: "s/24939", sid: 3, playable: true),
        BrowseItem(name: "Eclectic FM", imageURL: DemoArtwork.url("s15200"), type: .station, cid: "1028", mid: "s/15200", sid: 3, playable: true),
        BrowseItem(name: "Daily Mix", imageURL: DemoArtwork.url("flow"), type: .station, cid: "1028", mid: "dz-flow", sid: 2, playable: true)
    ]

    static let history: [BrowseItem] = [
        BrowseItem(
            name: "Paper Lanterns", imageURL: DemoArtwork.url("abc123"),
            type: .song, mid: "dz-12345", sid: 2, playable: true, artist: "The Velvet Hours", album: "Midnight Opera"
        ),
        BrowseItem(name: "Late Night Jazz", imageURL: DemoArtwork.url("s12345"),
                   type: .station, mid: "s/12345", sid: 3, playable: true),
        BrowseItem(
            name: "Night Drive", imageURL: DemoArtwork.url("def456"),
            type: .album, cid: "dz-album-7890", mid: "dz-album-7890", sid: 2,
            playable: true, browsable: true, artist: "Neon Harbor"
        ),
        BrowseItem(
            name: "Chill Vibes", imageURL: DemoArtwork.url("ghi789"),
            type: .playlist, cid: "dz-playlist-555", mid: "dz-playlist-555", sid: 2, playable: true, browsable: true
        ),
        BrowseItem(name: "Northern Sounds", imageURL: DemoArtwork.url("s44491"),
                   type: .station, mid: "s/44491", sid: 3, playable: true),
        BrowseItem(
            name: "Analog Dreams", imageURL: DemoArtwork.url("jkl012"),
            type: .album, cid: "dz-album-1234", mid: "dz-album-1234", sid: 2,
            playable: true, browsable: true, artist: "Neon Harbor"
        ),
    ]

    static let searchTracks: [BrowseItem] = [
        BrowseItem(name: "Paper Hearts", imageURL: DemoArtwork.url("midnights"),
            type: .song, mid: "dz-1896030", playable: true, artist: "Mila Rae", album: "Blue Hour"),
        BrowseItem(name: "All the Way", imageURL: DemoArtwork.url("love"),
            type: .song, mid: "dz-6848228", playable: true, artist: "Owen Marsh", album: "Tomorrow's Light"),
        BrowseItem(name: "As We Were", imageURL: DemoArtwork.url("harrys"),
            type: .song, mid: "dz-1711080", playable: true, artist: "June Avery", album: "June's Garden"),
        BrowseItem(name: "After the Rain", imageURL: DemoArtwork.url("best"),
            type: .song, mid: "dz-5324880", playable: true, artist: "Elias Grant", album: "Plain and Simple"),
        BrowseItem(name: "Savanna Light", imageURL: DemoArtwork.url("toto"),
            type: .song, mid: "dz-668810", playable: true, artist: "Coastline", album: "Coastline IV")
    ]
}

/// Covers drawn for the demo, so it shows artwork without borrowing anyone's.
enum DemoArtwork {
    static func url(_ name: String) -> String {
        Bundle.main.url(forResource: "demo-\(name)", withExtension: "jpg")?.absoluteString ?? ""
    }
}
#endif
