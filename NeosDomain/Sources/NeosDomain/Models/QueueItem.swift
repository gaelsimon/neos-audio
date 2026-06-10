import Foundation

public struct QueueItem: Identifiable, Equatable, Sendable {
    public let qid: Int
    public let song: String
    public let album: String
    public let artist: String
    public let imageURL: String
    public let mid: String
    public let albumID: String

    public var id: Int { qid }

    public init(
        qid: Int,
        song: String = "",
        album: String = "",
        artist: String = "",
        imageURL: String = "",
        mid: String = "",
        albumID: String = ""
    ) {
        self.qid = qid
        self.song = song
        self.album = album
        self.artist = artist
        self.imageURL = imageURL
        self.mid = mid
        self.albumID = albumID
    }
}
