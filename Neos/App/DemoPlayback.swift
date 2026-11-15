import Foundation
import NeosDomain

#if DEBUG
/// A track in the demo's queue, with the source it came from.
struct DemoTrack: Equatable {
    let song: String
    let album: String
    let artist: String
    let imageURL: String
    let mid: String
    let albumID: String
    let sid: Int
    /// In milliseconds.
    let duration: Int

    init(
        song: String, album: String = "", artist: String = "", imageURL: String = "",
        mid: String, albumID: String = "", sid: Int, duration: Int? = nil
    ) {
        self.song = song
        self.album = album
        self.artist = artist
        self.imageURL = imageURL
        self.mid = mid
        self.albumID = albumID
        self.sid = sid
        self.duration = duration ?? Self.length(of: mid)
    }

    /// `cover` stands in for a track listed without artwork, as an album's tracks are.
    init(_ item: BrowseItem, sid: Int, cover: String = "") {
        self.init(
            song: item.name, album: item.album ?? "", artist: item.artist ?? "",
            imageURL: item.imageURL.isEmpty ? cover : item.imageURL,
            mid: item.mid ?? item.name, sid: item.sid ?? sid
        )
    }

    /// The same for a given track on every launch, between about three and six minutes.
    private static func length(of mid: String) -> Int {
        (170 + mid.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 185 }) * 1000
    }

    func queueItem(qid: Int) -> QueueItem {
        QueueItem(qid: qid, song: song, album: album, artist: artist, imageURL: imageURL, mid: mid, albumID: albumID)
    }

    func media(qid: Int) -> NowPlayingMedia {
        NowPlayingMedia(
            type: .song, song: song, album: album, artist: artist, imageURL: imageURL,
            albumID: albumID, mid: mid, qid: qid, sid: sid
        )
    }
}

/// What the demo's speakers play: one queue and one transport for all of them.
struct DemoPlayback {
    private(set) var tracks: [DemoTrack]
    /// The queue position that plays, or that played last once a stream took over.
    private(set) var current: Int?
    /// A station, an input or a URL playing in place of the queue.
    private(set) var stream: NowPlayingMedia?
    private(set) var playState: PlayState
    var repeatMode = RepeatMode.off
    var shuffleMode = ShuffleMode.off

    init(tracks: [DemoTrack] = [], current: Int? = nil, playState: PlayState = .stop) {
        self.tracks = tracks
        self.current = current
        self.playState = playState
    }

    // MARK: - What the app reads

    /// Queue ids are positions, as on a speaker: they shift when the queue changes.
    var queue: [QueueItem] {
        tracks.enumerated().map { index, track in track.queueItem(qid: index + 1) }
    }

    var nowPlaying: NowPlayingMedia {
        if let stream { return stream }
        guard let current else { return NowPlayingMedia() }
        return tracks[current].media(qid: current + 1)
    }

    /// Zero for a stream, which has no end.
    var duration: Int {
        guard stream == nil, let current else { return 0 }
        return tracks[current].duration
    }

    private var hasSomethingToPlay: Bool {
        stream != nil || current != nil
    }

    // MARK: - Transport

    // Every change returns true when a track starts from its beginning.

    @discardableResult
    mutating func set(_ state: PlayState) -> Bool {
        let startsTheQueue = state == .play && !hasSomethingToPlay && !tracks.isEmpty
        if startsTheQueue { current = 0 }
        playState = hasSomethingToPlay ? state : .stop
        return startsTheQueue
    }

    /// A stream has no neighbours, and the end of the queue has no next unless it repeats.
    @discardableResult
    mutating func skip(by step: Int) -> Bool {
        guard stream == nil, let current else { return false }
        var target = current + step
        if !tracks.indices.contains(target) {
            if repeatMode == .onAll {
                target = (target + tracks.count) % tracks.count
            } else if step > 0 {
                return false
            } else {
                target = 0
            }
        }
        self.current = target
        playState = .play
        return true
    }

    @discardableResult
    mutating func play(qid: Int) -> Bool {
        guard tracks.indices.contains(qid - 1) else { return false }
        current = qid - 1
        stream = nil
        playState = .play
        return true
    }

    mutating func play(stream media: NowPlayingMedia) {
        stream = media
        playState = .play
    }

    // MARK: - Queue

    /// The track after a removed playing one takes its place.
    @discardableResult
    mutating func remove(qids: [Int]) -> Bool {
        let removed = Set(qids.map { $0 - 1 }).intersection(tracks.indices)
        guard !removed.isEmpty else { return false }
        let losesThePlayingTrack = current.map(removed.contains) ?? false
        let removedBefore = current.map { index in removed.filter { $0 < index }.count } ?? 0
        tracks = tracks.indices.filter { !removed.contains($0) }.map { tracks[$0] }
        current = current.flatMap { tracks.isEmpty ? nil : min($0 - removedBefore, tracks.count - 1) }
        if !hasSomethingToPlay { playState = .stop }
        return losesThePlayingTrack && stream == nil && current != nil
    }

    mutating func clear() {
        tracks = []
        current = nil
        if stream == nil { playState = .stop }
    }

    /// The moved tracks end at `destination`, whichever way they travel.
    mutating func move(qids: [Int], to destination: Int) {
        let moving = qids.map { $0 - 1 }.filter(tracks.indices.contains)
        guard !moving.isEmpty else { return }
        var order = tracks.indices.filter { !moving.contains($0) }
        order.insert(contentsOf: moving, at: min(max(destination - 1, 0), order.count))
        current = current.flatMap(order.firstIndex(of:))
        tracks = order.map { tracks[$0] }
    }

    @discardableResult
    mutating func add(_ added: [DemoTrack], _ criteria: AddCriteria) -> Bool {
        guard !added.isEmpty else { return false }
        let afterCurrent = current.map { $0 + 1 } ?? 0
        switch criteria {
        case .addToEnd:
            tracks.append(contentsOf: added)
            return false
        case .playNext:
            tracks.insert(contentsOf: added, at: afterCurrent)
            return false
        case .playNow:
            tracks.insert(contentsOf: added, at: afterCurrent)
            current = afterCurrent
        case .replaceAndPlay:
            tracks = added
            current = 0
        }
        stream = nil
        playState = .play
        return true
    }
}
#endif
