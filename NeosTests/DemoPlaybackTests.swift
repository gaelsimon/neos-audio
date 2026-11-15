import Foundation
import Testing
import NeosDomain
@testable import Neos

#if DEBUG
struct DemoPlaybackTests {
    private static func track(_ name: String) -> DemoTrack {
        DemoTrack(song: name, mid: "m-\(name)", sid: 2)
    }

    private static let tracks = ["A", "B", "C", "D"].map(track)
    private let station = NowPlayingMedia(type: .station, mid: "s/1", sid: 3, station: "Pulse FM")

    /// Playing "B", the second of four.
    private func playback(at index: Int? = 1, _ state: PlayState = .play) -> DemoPlayback {
        DemoPlayback(tracks: Self.tracks, current: index, playState: state)
    }

    private func songs(_ playback: DemoPlayback) -> [String] {
        playback.queue.map(\.song)
    }

    // MARK: - What the app reads

    @Test func theQueueNumbersItsTracksFromOne() {
        #expect(playback().queue.map(\.qid) == [1, 2, 3, 4])
    }

    @Test func theCurrentTrackPlaysWithItsPositionAsQueueID() {
        #expect(playback().nowPlaying == NowPlayingMedia(type: .song, song: "B", mid: "m-B", qid: 2, sid: 2))
    }

    @Test func nothingPlaysWithoutACurrentTrack() {
        #expect(DemoPlayback().nowPlaying == NowPlayingMedia())
    }

    @Test func aStreamHasNoLength() {
        var playback = playback()
        playback.play(stream: station)
        #expect(playback.duration == 0)
    }

    // MARK: - Transport

    @Test func nextMovesToTheFollowingTrack() {
        var playback = playback()
        let startsATrack = playback.skip(by: 1)
        #expect(startsATrack)
        #expect(playback.nowPlaying.song == "C")
    }

    @Test func nextOnTheLastTrackStaysThere() {
        var playback = playback(at: 3)
        let startsATrack = playback.skip(by: 1)
        #expect(!startsATrack)
        #expect(playback.nowPlaying.song == "D")
    }

    @Test func nextOnTheLastTrackWrapsWhenTheQueueRepeats() {
        var playback = playback(at: 3)
        playback.repeatMode = .onAll
        let startsATrack = playback.skip(by: 1)
        #expect(startsATrack)
        #expect(playback.nowPlaying.song == "A")
    }

    @Test func previousOnTheFirstTrackRestartsIt() {
        var playback = playback(at: 0)
        let startsATrack = playback.skip(by: -1)
        #expect(startsATrack)
        #expect(playback.nowPlaying.song == "A")
    }

    @Test func previousOnTheFirstTrackWrapsWhenTheQueueRepeats() {
        var playback = playback(at: 0)
        playback.repeatMode = .onAll
        playback.skip(by: -1)
        #expect(playback.nowPlaying.song == "D")
    }

    @Test func skippingWhilePausedStartsPlaying() {
        var playback = playback(.pause)
        playback.skip(by: 1)
        #expect(playback.playState == .play)
    }

    @Test func aStreamCannotBeSkipped() {
        var playback = playback()
        playback.play(stream: station)
        let startsATrack = playback.skip(by: 1)
        #expect(!startsATrack)
        #expect(playback.nowPlaying == station)
    }

    @Test func playingAQueueItemEndsTheStream() {
        var playback = playback()
        playback.play(stream: station)
        let startsATrack = playback.play(qid: 4)
        #expect(startsATrack)
        #expect(playback.nowPlaying.song == "D")
    }

    @Test func playingAQueueItemThatIsNotThereChangesNothing() {
        var playback = playback()
        let startsATrack = playback.play(qid: 9)
        #expect(!startsATrack)
        #expect(playback.nowPlaying.song == "B")
    }

    @Test func playStartsAnIdleQueueOnItsFirstTrack() {
        var playback = playback(at: nil, .stop)
        let startsATrack = playback.set(.play)
        #expect(startsATrack)
        #expect(playback.nowPlaying.song == "A")
    }

    @Test func playWithNothingQueuedStaysStopped() {
        var playback = DemoPlayback()
        let startsATrack = playback.set(.play)
        #expect(!startsATrack)
        #expect(playback.playState == .stop)
    }

    @Test func resumingDoesNotRestartTheTrack() {
        var playback = playback(.pause)
        let startsATrack = playback.set(.play)
        #expect(!startsATrack)
        #expect(playback.playState == .play)
    }

    // MARK: - Queue

    @Test func removingAnEarlierTrackKeepsTheSameTrackPlaying() {
        var playback = playback(at: 2)
        let startsATrack = playback.remove(qids: [1])
        #expect(!startsATrack)
        #expect(playback.nowPlaying == NowPlayingMedia(type: .song, song: "C", mid: "m-C", qid: 2, sid: 2))
    }

    @Test func removingALaterTrackLeavesThePositionAlone() {
        var playback = playback()
        playback.remove(qids: [4])
        #expect(playback.nowPlaying.qid == 2)
    }

    @Test func removingThePlayingTrackHandsOverToTheNext() {
        var playback = playback()
        let startsATrack = playback.remove(qids: [2])
        #expect(startsATrack)
        #expect(playback.nowPlaying.song == "C")
    }

    @Test func removingThePlayingLastTrackFallsBackOnTheNewLast() {
        var playback = playback(at: 3)
        playback.remove(qids: [4])
        #expect(playback.nowPlaying.song == "C")
    }

    @Test func removingEveryTrackStops() {
        var playback = playback()
        playback.remove(qids: [1, 2, 3, 4])
        #expect(playback.playState == .stop)
        #expect(playback.nowPlaying == NowPlayingMedia())
    }

    @Test func removingAQueueIDThatIsNotThereChangesNothing() {
        var playback = playback()
        let startsATrack = playback.remove(qids: [0, 7])
        #expect(!startsATrack)
        #expect(songs(playback) == ["A", "B", "C", "D"])
    }

    @Test func clearingStopsAndEmptiesTheQueue() {
        var playback = playback()
        playback.clear()
        #expect(playback.playState == .stop)
        #expect(playback.queue.isEmpty)
    }

    @Test func clearingLeavesAStreamPlaying() {
        var playback = playback()
        playback.play(stream: station)
        playback.clear()
        #expect(playback.playState == .play)
        #expect(playback.nowPlaying == station)
    }

    @Test(arguments: [
        (from: 1, to: 3, order: ["B", "C", "A", "D"]),
        (from: 3, to: 1, order: ["C", "A", "B", "D"]),
        (from: 2, to: 9, order: ["A", "C", "D", "B"]),
    ])
    func aMovedTrackEndsAtItsDestination(from: Int, to: Int, order: [String]) {
        var playback = playback()
        playback.move(qids: [from], to: to)
        #expect(songs(playback) == order)
    }

    @Test func severalMovedTracksTravelTogether() {
        var playback = playback()
        playback.move(qids: [1, 2], to: 3)
        #expect(songs(playback) == ["C", "D", "A", "B"])
    }

    @Test func movingKeepsTheSameTrackPlaying() {
        var playback = playback()
        playback.move(qids: [1], to: 4)
        #expect(playback.nowPlaying == NowPlayingMedia(type: .song, song: "B", mid: "m-B", qid: 1, sid: 2))
    }

    @Test func addingToTheEndAppendsWithoutStartingAnything() {
        var playback = playback()
        let startsATrack = playback.add([Self.track("X")], .addToEnd)
        #expect(!startsATrack)
        #expect(songs(playback) == ["A", "B", "C", "D", "X"])
        #expect(playback.nowPlaying.song == "B")
    }

    @Test func playingNextInsertsAfterTheCurrentTrack() {
        var playback = playback()
        let startsATrack = playback.add([Self.track("X")], .playNext)
        #expect(!startsATrack)
        #expect(songs(playback) == ["A", "B", "X", "C", "D"])
        #expect(playback.nowPlaying.song == "B")
    }

    @Test func playingNowInsertsAfterTheCurrentTrackAndStartsIt() {
        var playback = playback()
        let startsATrack = playback.add([Self.track("X")], .playNow)
        #expect(startsATrack)
        #expect(songs(playback) == ["A", "B", "X", "C", "D"])
        #expect(playback.nowPlaying.qid == 3)
    }

    @Test func replacingTheQueueStartsItsFirstTrack() {
        var playback = playback()
        let startsATrack = playback.add([Self.track("X"), Self.track("Y")], .replaceAndPlay)
        #expect(startsATrack)
        #expect(songs(playback) == ["X", "Y"])
        #expect(playback.nowPlaying.song == "X")
    }

    @Test func addingNothingChangesNothing() {
        var playback = playback()
        let startsATrack = playback.add([], .replaceAndPlay)
        #expect(!startsATrack)
        #expect(songs(playback) == ["A", "B", "C", "D"])
    }

    @Test func aTrackPlayedNowEndsTheStream() {
        var playback = playback()
        playback.play(stream: station)
        playback.add([Self.track("X")], .playNow)
        #expect(playback.nowPlaying.song == "X")
    }

    @Test func aTrackAddedWhileAStreamPlaysLeavesItPlaying() {
        var playback = playback()
        playback.play(stream: station)
        playback.add([Self.track("X")], .addToEnd)
        #expect(playback.nowPlaying == station)
    }
}

struct DemoTrackTests {
    private let listed = BrowseItem(name: "Tape Hiss", type: .song, mid: "t-1", artist: "Neon Harbor", album: "Analog Dreams")

    @Test func aTrackKeepsOneLengthFromLaunchToLaunch() {
        #expect(DemoTrack(song: "Paper Lanterns", mid: "dz-12345", sid: 2).duration == 322_000)
    }

    @Test(arguments: ["", "a", "dz-11111", "road-120", "demo-2-Tape Hiss-0"])
    func aTrackLastsBetweenThreeAndSixMinutes(mid: String) {
        #expect((170_000...354_000).contains(DemoTrack(song: "x", mid: mid, sid: 2).duration))
    }

    @Test func aLengthGivenWins() {
        #expect(DemoTrack(song: "x", mid: "dz-12345", sid: 2, duration: 1_000).duration == 1_000)
    }

    @Test func aListedTrackTakesTheCoverOfItsAlbum() {
        #expect(DemoTrack(listed, sid: 2, cover: "cover.jpg").imageURL == "cover.jpg")
    }

    @Test func aListedTrackKeepsItsOwnArtwork() {
        let item = BrowseItem(name: "Tape Hiss", imageURL: "own.jpg", type: .song, mid: "t-1")
        #expect(DemoTrack(item, sid: 2, cover: "cover.jpg").imageURL == "own.jpg")
    }

    @Test func aListedTrackKeepsTheSourceItNames() {
        let item = BrowseItem(name: "Tape Hiss", type: .song, mid: "t-1", sid: 10)
        #expect(DemoTrack(item, sid: 2).sid == 10)
    }

    @Test func aListedTrackWithoutASourceTakesTheOneItWasPlayedFrom() {
        #expect(DemoTrack(listed, sid: 2).sid == 2)
    }

    @Test func aListedTrackCarriesItsArtistAndAlbum() {
        let item = DemoTrack(listed, sid: 2).queueItem(qid: 5)
        #expect(item == QueueItem(qid: 5, song: "Tape Hiss", album: "Analog Dreams", artist: "Neon Harbor", mid: "t-1"))
    }
}
#endif
