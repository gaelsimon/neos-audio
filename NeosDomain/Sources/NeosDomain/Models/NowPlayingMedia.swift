import Foundation

public struct NowPlayingMedia: Equatable, Sendable {
    public let type: MediaType
    public let song: String
    public let album: String
    public let artist: String
    public let imageURL: String
    public let albumID: String
    public let mid: String
    public let qid: Int?
    public let sid: Int?
    public let station: String?

    public init(
        type: MediaType = .song,
        song: String = "",
        album: String = "",
        artist: String = "",
        imageURL: String = "",
        albumID: String = "",
        mid: String = "",
        qid: Int? = nil,
        sid: Int? = nil,
        station: String? = nil
    ) {
        self.type = type
        self.song = song
        self.album = album
        self.artist = artist
        self.imageURL = imageURL
        self.albumID = albumID
        self.mid = mid
        self.qid = qid
        self.sid = sid
        self.station = station
    }
}
