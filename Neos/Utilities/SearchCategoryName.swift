/// HEOS names its search categories in the singular, "Track" or "Artist"; a section of results reads in the plural.
enum SearchCategoryName {
    private static let plurals = [
        "Album": "Albums", "Artist": "Artists", "Episode": "Episodes", "Genre": "Genres", "Host": "Hosts",
        "Playlist": "Playlists", "Podcast": "Podcasts", "Show": "Shows", "Song": "Songs", "Station": "Stations",
        "Track": "Tracks", "Video": "Videos",
    ]

    static func plural(_ name: String) -> String {
        plurals[name] ?? name
    }
}
