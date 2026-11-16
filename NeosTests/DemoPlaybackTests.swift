import Foundation
import Testing
import NeosDomain
@testable import Neos

#if DEBUG
struct DemoPlaybackTests {
    private static let trackLength = 200_000

    private static func track(_ name: String) -> DemoTrack {
        DemoTrack(song: name, mid: "m-\(name)", sid: 2).lasting(trackLength)
    }

    private static let tracks = ["A", "B", "C", "D"].map(track)
    private let station = NowPlayingMedia(type: .station, mid: "s/1", qid: 1, sid: 3, station: "Pulse FM")

    /// Playing "B", the second of four, unless told otherwise.
    private func playback(at index: Int? = 1, _ state: PlayState = .play, position: Int = 0) -> DemoPlayback {
        DemoPlayback(tracks: Self.tracks, current: index, playState: state, position: position)
    }

    private func onTheStation() -> DemoPlayback {
        var playback = playback()
        playback.play(stream: station)
        return playback
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

    @Test func nothingPlaysWithoutAQueue() {
        #expect(DemoPlayback().nowPlaying == NowPlayingMedia())
    }

    @Test func aStoppedQueueIsOnItsFirstTrack() {
        #expect(playback(at: 2, .stop).nowPlaying.song == "A")
    }

    @Test func aStreamHasNoLength() {
        #expect(onTheStation().duration == 0)
    }

    // MARK: - Transport

    @Test func nextStartsTheFollowingTrack() throws {
        var playback = playback(position: 30_000)
        try playback.skip(by: 1)
        #expect(playback.nowPlaying.song == "C")
        #expect(playback.position == 0)
    }

    @Test func nextOnTheLastTrackChangesNothing() throws {
        var playback = playback(at: 3, position: 30_000)
        try playback.skip(by: 1)
        #expect(playback.nowPlaying.song == "D")
        #expect(playback.position == 30_000)
    }

    @Test func nextOnTheLastTrackWrapsWhenTheQueueRepeats() throws {
        var playback = playback(at: 3)
        playback.repeatMode = .onAll
        try playback.skip(by: 1)
        #expect(playback.nowPlaying.song == "A")
    }

    @Test func nextMovesOnEvenWhenTheTrackRepeats() throws {
        var playback = playback()
        playback.repeatMode = .onOne
        try playback.skip(by: 1)
        #expect(playback.nowPlaying.song == "C")
    }

    @Test func nextGoesToAnotherTrackWhenShuffling() throws {
        var playback = playback()
        playback.shuffleMode = .on
        try playback.skip(by: 1)
        #expect(playback.nowPlaying.song != "B")
    }

    @Test func previousEarlyInATrackGoesBackOne() throws {
        var playback = playback(position: DemoPlayback.restartAfter - 1)
        try playback.skip(by: -1)
        #expect(playback.nowPlaying.song == "A")
    }

    @Test func previousLaterInATrackStartsItAgain() throws {
        var playback = playback(position: DemoPlayback.restartAfter)
        try playback.skip(by: -1)
        #expect(playback.nowPlaying.song == "B")
        #expect(playback.position == 0)
    }

    @Test func previousEarlyInTheFirstTrackChangesNothing() throws {
        var playback = playback(at: 0, position: 2_000)
        try playback.skip(by: -1)
        #expect(playback.nowPlaying.song == "A")
        #expect(playback.position == 2_000)
    }

    @Test func previousOnTheFirstTrackWrapsWhenTheQueueRepeats() throws {
        var playback = playback(at: 0)
        playback.repeatMode = .onAll
        try playback.skip(by: -1)
        #expect(playback.nowPlaying.song == "D")
    }

    @Test func skippingWhilePausedStartsPlaying() throws {
        var playback = playback(.pause)
        try playback.skip(by: 1)
        #expect(playback.playState == .play)
    }

    @Test(arguments: [1, -1])
    func aStreamRefusesToSkip(step: Int) {
        var playback = onTheStation()
        #expect(throws: DemoPlayback.SkipLimit.self) { try playback.skip(by: step) }
        #expect(playback.nowPlaying == station)
    }

    @Test func theRefusalReadsAsASpeakerWordsIt() {
        #expect(DemoPlayback.SkipLimit().localizedDescription == "Reached skip limit")
    }

    @Test func playingAQueueItemEndsTheStream() {
        var playback = onTheStation()
        playback.play(qid: 4)
        #expect(playback.nowPlaying.song == "D")
    }

    @Test func playingAQueueItemThatIsNotThereChangesNothing() {
        var playback = playback()
        playback.play(qid: 9)
        #expect(playback.nowPlaying.song == "B")
    }

    @Test func playWithNothingQueuedStaysStopped() {
        var playback = DemoPlayback()
        playback.set(.play)
        #expect(playback.playState == .stop)
    }

    @Test func resumingCarriesOnWhereItPaused() {
        var playback = playback(.pause, position: 30_000)
        playback.set(.play)
        #expect(playback.playState == .play)
        #expect(playback.position == 30_000)
    }

    @Test func stoppingGoesBackToTheFirstTrack() {
        var playback = playback(at: 2, position: 30_000)
        playback.set(.stop)
        #expect(playback.nowPlaying.song == "A")
        #expect(playback.position == 0)
    }

    @Test func playAfterAStopStartsTheFirstTrack() {
        var playback = playback(at: 2)
        playback.set(.stop)
        playback.set(.play)
        #expect(playback.playState == .play)
        #expect(playback.nowPlaying.song == "A")
    }

    @Test func pausingAStreamStopsIt() {
        var playback = onTheStation()
        playback.set(.pause)
        #expect(playback.playState == .stop)
    }

    @Test func aStoppedStreamStaysWhatIsOn() {
        var playback = onTheStation()
        playback.set(.pause)
        #expect(playback.nowPlaying == station)
    }

    @Test func playStartsAStoppedStreamAgain() {
        var playback = onTheStation()
        playback.set(.pause)
        playback.set(.play)
        #expect(playback.playState == .play)
    }

    @Test func aStreamLeavesTheQueueWithoutAPosition() {
        var playback = onTheStation()
        playback.add([Self.track("X")], .playNow)
        #expect(songs(playback) == ["X", "A", "B", "C", "D"])
    }

    // MARK: - Time

    @Test func timeOnlyPassesWhilePlaying() {
        var playback = playback(.pause, position: 30_000)
        playback.elapse(10_000)
        #expect(playback.position == 30_000)
    }

    @Test func aTrackThatEndsHandsOverToTheNext() {
        var playback = playback()
        playback.elapse(Self.trackLength + 3_000)
        #expect(playback.nowPlaying.song == "C")
        #expect(playback.position == 3_000)
        #expect(playback.playState == .play)
    }

    @Test func theQueueStopsOnItsFirstTrackAfterTheLast() {
        var playback = playback(at: 3)
        playback.elapse(Self.trackLength)
        #expect(playback.playState == .stop)
        #expect(playback.nowPlaying.song == "A")
    }

    @Test func theLastTrackHandsOverToTheFirstWhenTheQueueRepeats() {
        var playback = playback(at: 3)
        playback.repeatMode = .onAll
        playback.elapse(Self.trackLength)
        #expect(playback.playState == .play)
        #expect(playback.nowPlaying.song == "A")
    }

    @Test func aRepeatedTrackStartsAgainWhenItEnds() {
        var playback = playback()
        playback.repeatMode = .onOne
        playback.elapse(Self.trackLength + 1_000)
        #expect(playback.nowPlaying.song == "B")
        #expect(playback.position == 1_000)
    }

    @Test func aLongAbsenceRunsThroughSeveralTracks() {
        var playback = playback(at: 0)
        playback.elapse(Self.trackLength * 2 + 5_000)
        #expect(playback.nowPlaying.song == "C")
        #expect(playback.position == 5_000)
    }

    @Test func aStreamNeverEnds() {
        var playback = onTheStation()
        playback.elapse(3_600_000)
        #expect(playback.playState == .play)
        #expect(playback.position == 3_600_000)
    }

    @Test func aURLNeverEnds() {
        var playback = playback()
        playback.playURL()
        playback.elapse(3_600_000)
        #expect(playback.nowPlaying.song == "Url Stream")
    }

    @Test func seekingMovesThePosition() {
        var playback = playback()
        playback.seek(to: 90_000)
        #expect(playback.position == 90_000)
    }

    @Test(arguments: [(target: -5, lands: 0), (target: 999_000, lands: 200_000)])
    func seekingStaysInsideTheTrack(target: Int, lands: Int) {
        var playback = playback()
        playback.seek(to: target)
        #expect(playback.position == lands)
    }

    @Test func aStreamCannotBeSought() {
        var playback = onTheStation()
        playback.seek(to: 90_000)
        #expect(playback.position == 0)
    }

    // MARK: - Queue

    @Test func removingAnEarlierTrackKeepsTheSameTrackPlaying() {
        var playback = playback(at: 2, position: 30_000)
        playback.remove(qids: [1])
        #expect(playback.nowPlaying == NowPlayingMedia(type: .song, song: "C", mid: "m-C", qid: 2, sid: 2))
        #expect(playback.position == 30_000)
    }

    @Test func removingALaterTrackLeavesThePositionAlone() {
        var playback = playback()
        playback.remove(qids: [4])
        #expect(playback.nowPlaying.qid == 2)
    }

    @Test func removingThePlayingTrackStartsTheOneThatTakesItsPlace() {
        var playback = playback(position: 30_000)
        playback.remove(qids: [2])
        #expect(playback.nowPlaying.song == "C")
        #expect(playback.position == 0)
        #expect(playback.playState == .play)
    }

    @Test func removingThePlayingLastTrackStartsTheFirst() {
        var playback = playback(at: 3)
        playback.remove(qids: [4])
        #expect(playback.nowPlaying.song == "A")
        #expect(playback.playState == .play)
    }

    @Test func removingThePausedTrackStopsOnTheFirst() {
        var playback = playback(at: 2, .pause)
        playback.remove(qids: [3])
        #expect(playback.playState == .stop)
        #expect(playback.nowPlaying.song == "A")
    }

    @Test func removingEveryTrackStops() {
        var playback = playback()
        playback.remove(qids: [1, 2, 3, 4])
        #expect(playback.playState == .stop)
        #expect(playback.nowPlaying == NowPlayingMedia())
    }

    @Test func removingAQueueIDThatIsNotThereChangesNothing() {
        var playback = playback()
        playback.remove(qids: [0, 7])
        #expect(songs(playback) == ["A", "B", "C", "D"])
    }

    @Test func removingATrackLeavesAStreamPlaying() {
        var playback = onTheStation()
        playback.remove(qids: [2])
        #expect(playback.nowPlaying == station)
        #expect(songs(playback) == ["A", "C", "D"])
    }

    @Test func clearingStopsAndLeavesNothingPlaying() {
        var playback = playback()
        playback.clear()
        #expect(playback.playState == .stop)
        #expect(playback.queue.isEmpty)
        #expect(playback.nowPlaying == NowPlayingMedia())
    }

    @Test func clearingLeavesAStreamPlaying() {
        var playback = onTheStation()
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
        var playback = playback(position: 30_000)
        playback.add([Self.track("X")], .addToEnd)
        #expect(songs(playback) == ["A", "B", "C", "D", "X"])
        #expect(playback.nowPlaying.song == "B")
        #expect(playback.position == 30_000)
    }

    @Test func playingNextInsertsAfterTheCurrentTrack() {
        var playback = playback()
        playback.add([Self.track("X")], .playNext)
        #expect(songs(playback) == ["A", "B", "X", "C", "D"])
        #expect(playback.nowPlaying.song == "B")
    }

    @Test func playingNowInsertsAfterTheCurrentTrackAndStartsIt() {
        var playback = playback(.pause, position: 30_000)
        playback.add([Self.track("X")], .playNow)
        #expect(songs(playback) == ["A", "B", "X", "C", "D"])
        #expect(playback.nowPlaying.qid == 3)
        #expect(playback.playState == .play)
        #expect(playback.position == 0)
    }

    @Test func replacingTheQueueStartsItsFirstTrack() {
        var playback = playback()
        playback.add([Self.track("X"), Self.track("Y")], .replaceAndPlay)
        #expect(songs(playback) == ["X", "Y"])
        #expect(playback.nowPlaying.song == "X")
    }

    @Test func addingNothingChangesNothing() {
        var playback = playback()
        playback.add([], .replaceAndPlay)
        #expect(songs(playback) == ["A", "B", "C", "D"])
    }

    @Test func aTrackPlayedNowEndsTheStream() {
        var playback = onTheStation()
        playback.add([Self.track("X")], .playNow)
        #expect(playback.nowPlaying.song == "X")
    }

    @Test func aTrackAddedWhileAStreamPlaysLeavesItPlaying() {
        var playback = onTheStation()
        playback.add([Self.track("X")], .addToEnd)
        #expect(playback.nowPlaying == station)
    }

    @Test func theFirstTrackOfAnEmptyQueueShowsWithoutPlaying() {
        var playback = DemoPlayback()
        playback.add([Self.track("X")], .addToEnd)
        #expect(playback.nowPlaying.song == "X")
        #expect(playback.playState == .stop)
    }

    @Test func aURLPlaysAsAQueueEntryAfterTheCurrentTrack() {
        var playback = playback()
        playback.playURL()
        #expect(songs(playback) == ["A", "B", "Url Stream", "C", "D"])
        #expect(playback.nowPlaying == NowPlayingMedia(
            type: .song, song: "Url Stream", album: "Url Stream", artist: "Url Stream",
            albumID: "1", mid: "1", qid: 3, sid: 1024
        ))
    }

    @Test func theQueueListsAURLEntryWithoutAnID() {
        var playback = playback()
        playback.playURL()
        #expect(playback.queue[2].mid.isEmpty)
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
        #expect(DemoTrack(song: "x", mid: "dz-12345", sid: 2).lasting(1_000).duration == 1_000)
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
