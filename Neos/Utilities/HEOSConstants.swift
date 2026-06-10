import Foundation

/// Well-known HEOS music source IDs used as library sections.
enum HEOSConstants {
    /// SIDs for built-in library sources (Playlists, History, Favorites).
    static let librarySIDs: Set<Int> = [1025, 1026, 1028]

    /// HEOS History source ID.
    static let historySID = 1026

    /// HEOS Favorites source ID.
    static let favoritesSID = 1028

    /// TuneIn source ID; used for adding custom URL stations to favorites.
    static let tuneInSID = 3
}
