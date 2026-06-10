import Foundation

public struct BrowseItem: Identifiable, Equatable, Sendable {
    public let name: String
    public let imageURL: String
    public let type: MediaType
    public let cid: String?
    public let mid: String?
    public let sid: Int?
    public let playable: Bool
    public let browsable: Bool
    public let artist: String?
    public let album: String?

    public var id: String {
        mid ?? cid ?? name
    }

    /// True when this item is a sub-source (DLNA server, HEOS service) that should
    /// be browsed via browseSource(sid:) rather than browseContainer(sid:cid:).
    public var isSubSource: Bool {
        sid != nil && cid == nil && (type == .dlnaServer || type == .heosServer || type == .heosService)
    }

    public init(
        name: String,
        imageURL: String = "",
        type: MediaType = .song,
        cid: String? = nil,
        mid: String? = nil,
        sid: Int? = nil,
        playable: Bool = false,
        browsable: Bool = false,
        artist: String? = nil,
        album: String? = nil
    ) {
        self.name = name
        self.imageURL = imageURL
        self.type = type
        self.cid = cid
        self.mid = mid
        self.sid = sid
        self.playable = playable
        self.browsable = browsable
        self.artist = artist
        self.album = album
    }
}
