import Foundation

public struct ServiceOption: Sendable, Equatable, Identifiable {
    public enum Context: String, Sendable {
        case play
        case browse
    }

    public let context: Context
    public let id: Int
    public let name: String

    public init(context: Context, id: Int, name: String) {
        self.context = context
        self.id = id
        self.name = name
    }

    // MARK: - Known Option IDs

    public static let thumbsUpID = 11
    public static let thumbsDownID = 12
    public static let addToFavoritesID = 19
    public static let removeFromFavoritesID = 20
    public static let addTrackToLibraryID = 1
    public static let addAlbumToLibraryID = 2
    public static let addStationToLibraryID = 3
}
