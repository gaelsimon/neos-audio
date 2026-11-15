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
    /// In milliseconds. Zero for what has no end.
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

    /// What a speaker queues for a bare URL: it knows nothing of the stream but that it is one.
    static let urlStream = Self(
        song: "Url Stream", album: "Url Stream", artist: "Url Stream",
        mid: "1", albumID: "1", sid: DemoCatalog.localMusicSID, duration: 0
    )

    /// The same for a given track on every launch, between about three and six minutes.
    private static func length(of mid: String) -> Int {
        (170 + mid.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 185 }) * 1000
    }

    /// The queue lists a URL entry without the ids "now playing" gives it.
    func queueItem(qid: Int) -> QueueItem {
        let isURL = self == Self.urlStream
        return QueueItem(
            qid: qid, song: song, album: album, artist: artist, imageURL: imageURL,
            mid: isURL ? "" : mid, albumID: isURL ? "" : albumID
        )
    }

    func media(qid: Int) -> NowPlayingMedia {
        NowPlayingMedia(
            type: .song, song: song, album: album, artist: artist, imageURL: imageURL,
            albumID: albumID, mid: mid, qid: qid, sid: sid
        )
    }
}

/// What the demo's speakers play: one queue and one transport for all of them, behaving as a speaker does.
struct DemoPlayback {
    /// What a speaker answers when asked to skip on a station or an input.
    struct SkipLimit: LocalizedError {
        var errorDescription: String? { "Reached skip limit" }
    }

    /// Past this much of a track, previous starts it again.
    static let restartAfter = 5000

    private(set) var tracks: [DemoTrack]
    /// The queue position that plays. A stopped queue is on its first track, and a stream leaves the queue without one.
    private(set) var current: Int?
    /// A station or an input playing in place of the queue.
    private(set) var stream: NowPlayingMedia?
    private(set) var playState: PlayState
    /// Milliseconds played of the track or the stream.
    private(set) var position: Int
    var repeatMode = RepeatMode.off
    var shuffleMode = ShuffleMode.off

    init(tracks: [DemoTrack] = [], current: Int? = nil, playState: PlayState = .stop, position: Int = 0) {
        self.tracks = tracks
        self.current = current
        self.playState = playState
        self.position = position
        settle()
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

    /// Zero for what has no end.
    var duration: Int {
        guard stream == nil, let current else { return 0 }
        return tracks[current].duration
    }

    // MARK: - Transport

    /// A stream cannot be held: pausing it stops it. Play after a stop starts over, after a pause it carries on.
    mutating func set(_ state: PlayState) {
        switch state {
        case .play where stream != nil || current != nil:
            playState = .play
        case .pause where playState == .play:
            playState = stream == nil ? .pause : .stop
        case .stop:
            playState = .stop
        default:
            break
        }
        settle()
    }

    /// The ends of the queue have no neighbour unless it repeats, and previous first starts a track over.
    mutating func skip(by step: Int) throws {
        guard stream == nil else { throw SkipLimit() }
        guard let current else { return }
        if step < 0, position >= Self.restartAfter {
            start(current)
        } else if let neighbour = neighbour(of: current, by: step) {
            start(neighbour)
        }
    }

    mutating func play(qid: Int) {
        guard tracks.indices.contains(qid - 1) else { return }
        start(qid - 1)
    }

    mutating func play(stream media: NowPlayingMedia) {
        stream = media
        current = nil
        position = 0
        playState = .play
    }

    /// A bare URL plays as a queue entry of its own.
    mutating func playURL() {
        add([.urlStream], .playNow)
    }

    mutating func seek(to milliseconds: Int) {
        guard duration > 0 else { return }
        position = min(max(milliseconds, 0), duration)
    }

    /// Lets time pass: the queue moves on by itself at the end of a track, and stops after its last one.
    mutating func elapse(_ milliseconds: Int) {
        guard playState == .play, milliseconds > 0 else { return }
        position += milliseconds
        while let current, duration > 0, position >= duration {
            let overrun = position - duration
            if repeatMode == .onOne {
                position = overrun
            } else if let next = neighbour(of: current, by: 1) {
                self.current = next
                position = overrun
            } else {
                playState = .stop
                settle()
            }
        }
    }

    // MARK: - Queue

    /// The track that takes the place of a removed playing one starts, the first one when there is none. Removed
    /// while it was not playing, it leaves the speaker stopped.
    mutating func remove(qids: [Int]) {
        let removed = Set(qids.map { $0 - 1 }).intersection(tracks.indices)
        guard !removed.isEmpty else { return }
        let landing = current.map { index in index - removed.filter { $0 < index }.count }
        let losesTheCurrentTrack = current.map(removed.contains) ?? false
        tracks = tracks.indices.filter { !removed.contains($0) }.map { tracks[$0] }
        guard losesTheCurrentTrack, let landing else {
            current = landing
            return
        }
        if playState == .play, !tracks.isEmpty {
            start(landing < tracks.count ? landing : 0)
        } else {
            playState = .stop
            settle()
        }
    }

    mutating func clear() {
        tracks = []
        current = nil
        if stream == nil {
            playState = .stop
        }
        settle()
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

    mutating func add(_ added: [DemoTrack], _ criteria: AddCriteria) {
        guard !added.isEmpty else { return }
        let afterCurrent = current.map { $0 + 1 } ?? 0
        switch criteria {
        case .addToEnd:
            tracks.append(contentsOf: added)
        case .playNext:
            tracks.insert(contentsOf: added, at: afterCurrent)
        case .playNow:
            tracks.insert(contentsOf: added, at: afterCurrent)
            start(afterCurrent)
        case .replaceAndPlay:
            tracks = added
            start(0)
        }
        settle()
    }

    // MARK: - Rules

    private mutating func start(_ index: Int) {
        current = index
        stream = nil
        position = 0
        playState = .play
    }

    /// With shuffle on, next is any other track.
    private func neighbour(of index: Int, by step: Int) -> Int? {
        if shuffleMode == .on, step > 0 {
            return tracks.indices.filter { $0 != index }.randomElement()
        }
        let target = index + step
        if tracks.indices.contains(target) {
            return target
        }
        return repeatMode == .onAll ? (target + tracks.count) % tracks.count : nil
    }

    /// A stopped speaker is back at the head of its queue, with nothing played.
    private mutating func settle() {
        guard playState == .stop else { return }
        position = 0
        if stream == nil {
            current = tracks.isEmpty ? nil : 0
        }
    }
}
#endif
