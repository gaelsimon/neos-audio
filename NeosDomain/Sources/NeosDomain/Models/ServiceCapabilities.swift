import Foundation

public struct ServiceCapabilities: Equatable, Sendable {
    public let canBrowseAlbums: Bool
    public let canBrowseArtists: Bool

    public init(canBrowseAlbums: Bool = false, canBrowseArtists: Bool = false) {
        self.canBrowseAlbums = canBrowseAlbums
        self.canBrowseArtists = canBrowseArtists
    }

    public init(from criteria: [SearchCriteria]) {
        self.canBrowseAlbums = criteria.contains {
            $0.name.localizedCaseInsensitiveContains("Album")
        }
        self.canBrowseArtists = criteria.contains {
            $0.name.localizedCaseInsensitiveContains("Artist")
        }
    }
}
