import XCTest
@testable import Neos
import NeosDomain

/// A speaker calls every raw stream "Url Stream"; its address, read over UPnP, is what tells them apart.
@MainActor
final class RawStreamNamingTests: XCTestCase {
    private let fip = "https://stream.example.com/fip-hifi.aac"
    private let inter = "https://stream.example.com/inter-hifi.aac"

    private func rawStream(qid: Int = 4) -> NowPlayingMedia {
        NowPlayingMedia(song: "Url Stream", album: "Url Stream", artist: "Url Stream", albumID: "1", mid: "1", qid: qid, sid: 1024)
    }

    private func playing(_ address: String, qid: Int = 4, in existing: AppState? = nil) -> AppState {
        let state = existing ?? AppState()
        state.setNowPlaying(rawStream(qid: qid))
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, codec: "AAC", streamURL: address))
        return state
    }

    private func favourite(_ name: String, mid: String, imageURL: String = "") -> BrowseItem {
        BrowseItem(name: name, imageURL: imageURL, type: .station, mid: mid, playable: true)
    }

    // MARK: - From the address alone

    func testAStreamNobodySavedIsTitledAfterItsFile() {
        XCTAssertEqual(playing(inter).nowPlaying.displayedTitle, "inter-hifi")
    }

    func testAStreamNobodySavedShowsItsHostBelow() {
        XCTAssertEqual(playing(inter).nowPlaying.displayedStation, "stream.example.com")
    }

    func testAnAddressWithNoFileIsTitledAfterItsHost() {
        XCTAssertEqual(playing("http://radio.example.com:8000/").nowPlaying.displayedTitle, "radio.example.com")
    }

    func testTheSpeakersPlaceholderCreditsAreDropped() {
        let media = playing(inter).nowPlaying

        XCTAssertEqual([media.artist, media.album], ["", ""])
    }

    func testAStreamWhoseAddressIsNotReadYetIsCalledAStream() {
        let state = AppState()

        state.setNowPlaying(rawStream())

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Stream")
    }

    // MARK: - From a station saved under that address

    func testAStreamTakesTheNameOfTheStationSavedUnderItsAddress() {
        let state = AppState()
        state.cacheImageURLs(from: [favourite("France Musique", mid: fip)])

        XCTAssertEqual(playing(fip, in: state).nowPlaying.displayedTitle, "France Musique")
    }

    func testANamedStreamShowsNoSecondLine() {
        let state = AppState()
        state.cacheImageURLs(from: [favourite("France Musique", mid: fip)])

        XCTAssertNil(playing(fip, in: state).nowPlaying.displayedStation)
    }

    func testAStreamTakesTheImageOfTheStationSavedUnderItsAddress() {
        let state = AppState()
        state.cacheImageURLs(from: [favourite("France Musique", mid: fip, imageURL: "https://example.com/fm.jpg")])

        XCTAssertEqual(playing(fip, in: state).nowPlaying.imageURL, "https://example.com/fm.jpg")
    }

    func testAStationSavedOverHttpNamesTheSameStreamPlayedOverHttps() {
        let state = AppState()
        state.cacheImageURLs(from: [favourite("France Musique", mid: "http://stream.example.com/fip-hifi.aac")])

        XCTAssertEqual(playing(fip, in: state).nowPlaying.displayedTitle, "France Musique")
    }

    func testAStationSavedUnderItsAddressAloneKeepsATitleFromThatAddress() {
        let state = AppState()
        state.cacheImageURLs(from: [favourite(fip, mid: "u32")])

        XCTAssertEqual(playing(fip, in: state).nowPlaying.displayedTitle, "fip-hifi")
    }

    func testAStationSavedUnderItsAddressAloneLendsItsCustomArtwork() {
        let state = AppState()
        state.cacheImageURLs(from: [favourite(fip, mid: "u32")])

        _ = playing(fip, in: state)

        XCTAssertEqual(state.browseMID(forDeviceMID: "1"), "u32")
    }

    func testAStationLoadedAfterTheStreamStartedNamesIt() {
        let state = playing(fip)

        state.cacheImageURLs(from: [favourite("France Musique", mid: fip)])

        XCTAssertEqual(state.nowPlaying.displayedTitle, "France Musique")
    }

    // MARK: - Across events

    func testARepeatedEventKeepsTheName() {
        let state = AppState()
        state.cacheImageURLs(from: [favourite("France Musique", mid: fip)])
        _ = playing(fip, in: state)

        state.setNowPlaying(rawStream())

        XCTAssertEqual(state.nowPlaying.displayedTitle, "France Musique")
    }

    func testEveryEventAsksForTheAddressAgain() {
        let state = playing(fip)

        state.setNowPlaying(rawStream())

        XCTAssertTrue(state.playback.trackMetadataIsStale)
    }

    func testAnotherStreamInTheSameQueuePlaceIsRenamedOnceItsAddressIsRead() {
        let state = playing(fip)

        state.setNowPlaying(rawStream())
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: inter))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "inter-hifi")
    }

    func testAnUnsavedStreamAfterASavedOneBorrowsNoArtwork() {
        let state = AppState()
        state.cacheImageURLs(from: [favourite(fip, mid: "u32")])
        _ = playing(fip, in: state)

        state.setNowPlaying(rawStream())
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: inter))

        XCTAssertNil(state.browseMID(forDeviceMID: "1"))
    }

    func testAStreamInAnotherQueuePlaceStartsWithoutTheOldName() {
        let state = playing(fip)

        state.setNowPlaying(rawStream(qid: 7))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Stream")
    }

    func testATrackAfterAStreamIsNotTakenForOne() {
        let state = playing(fip)

        state.setNowPlaying(NowPlayingMedia(song: "Caffeine", artist: "Tia Gordon", mid: "568498994", qid: 5, sid: 10))
        state.setTrackMetadata(TrackMetadata(bitrate: 1_411_000, streamURL: "https://cdn.example.com/track.flac"))

        XCTAssertNil(state.nowPlaying.station)
    }

    func testANameGivenWhenTheStreamWasPlayedIsKept() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.pendingStreamContext = .init(
            pid: 42, stationName: "My Radio", browseMID: "u32", imageURL: "", streamURL: fip,
            previousMID: state.nowPlaying.mid
        )

        state.setNowPlaying(rawStream())
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: fip))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "My Radio")
    }

    // MARK: - When the stream changes

    private func context(name: String?, address: String, after state: AppState) -> PlaybackState.StreamPlayContext {
        .init(
            pid: 42, stationName: name, browseMID: "u32", imageURL: "", streamURL: address,
            previousMID: state.nowPlaying.mid, previousQID: state.nowPlaying.qid
        )
    }

    func testAStreamAskedForHereIsNamedAsSoonAsItIsAnnounced() {
        let state = playing(fip)
        state.selectedPlayerID = 42
        state.pendingStreamContext = context(name: nil, address: inter, after: state)

        state.setNowPlaying(rawStream(qid: 5))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "inter-hifi")
    }

    func testTheOutgoingStreamsReplayKeepsItsName() {
        let state = playing(fip)
        state.selectedPlayerID = 42
        state.pendingStreamContext = context(name: nil, address: inter, after: state)

        state.setNowPlaying(rawStream())

        XCTAssertEqual(state.nowPlaying.displayedTitle, "fip-hifi")
    }

    func testAReadSettlesTheAddress() {
        XCTAssertFalse(playing(fip).playback.trackMetadataIsStale)
    }

    func testALateAnswerForWhatPlayedBeforeIsNotBelieved() {
        let state = playing(fip)

        state.setNowPlaying(rawStream(qid: 7))
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: fip))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Stream")
    }

    /// Measured on a MODEL 40n: the old address is still given up to 3.5 s after the change is announced.
    func testLateAnswersAreNotBelievedHoweverManyCome() {
        let state = playing(fip)

        state.setNowPlaying(rawStream(qid: 7))
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: fip))
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: fip))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Stream")
    }

    func testALateAnswerAsksForAnotherRead() {
        let state = playing(fip)

        state.setNowPlaying(rawStream(qid: 7))
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: fip))

        XCTAssertTrue(state.playback.trackMetadataIsStale)
    }

    func testANewAddressNamesTheNewStream() {
        let state = playing(fip)

        state.setNowPlaying(rawStream(qid: 7))
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: fip))
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: inter))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "inter-hifi")
    }

    func testTheSameStreamPlayedAgainIsNamedOnceTheSpeakerPlays() {
        let state = playing(fip)

        state.setNowPlaying(rawStream(qid: 7))
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: fip))
        state.setPlayState(.play)
        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: fip))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "fip-hifi")
    }

    func testPlayAsksForTheAddressAtOnce() {
        let state = playing(fip)
        var asked = 0
        state.onTrackMetadataWanted = { asked += 1 }

        state.setPlayState(.play)

        XCTAssertEqual(asked, 1)
    }

    func testATracksAddressIsNotTakenForTheStreamThatFollows() {
        let state = AppState()
        let track = "https://cdn.example.com/audio/track-1234.flac"
        state.setNowPlaying(NowPlayingMedia(song: "Caffeine", artist: "Tia Gordon", mid: "568498994", qid: 3, sid: 10))
        state.setTrackMetadata(TrackMetadata(bitrate: 1_411_000, streamURL: track))

        state.setNowPlaying(rawStream())
        state.setTrackMetadata(TrackMetadata(bitrate: 1_411_000, streamURL: track))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Stream")
    }

    func testANameGivenAtPlayIsNotLentToTheNextStreamOfTheQueue() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.pendingStreamContext = context(name: "My Radio", address: fip, after: state)
        state.setNowPlaying(rawStream())

        state.setNowPlaying(rawStream(qid: 5))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Stream")
    }

    func testANameGivenAtPlayYieldsWhenTheAddressIsAnotherStreams() {
        let state = AppState()
        state.selectedPlayerID = 42
        state.pendingStreamContext = context(name: "My Radio", address: fip, after: state)
        state.setNowPlaying(rawStream())

        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: inter))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "inter-hifi")
    }

    // MARK: - When an entry before it leaves the queue

    /// The speaker sends the stream again at its new place, and neither stops nor reports play.
    private func playingThenMovedUp(from state: AppState) {
        state.setPlayState(.play)
        state.setNowPlaying(rawStream(qid: 3))
    }

    func testAStreamThatMovesUpTheQueueKeepsItsName() {
        let state = playing(fip)

        playingThenMovedUp(from: state)

        XCTAssertEqual(state.nowPlaying.displayedTitle, "fip-hifi")
    }

    func testAStreamThatMovesUpTheQueueStillBelievesItsAddress() {
        let state = playing(fip)
        playingThenMovedUp(from: state)

        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: fip))

        XCTAssertFalse(state.playback.trackMetadataIsStale)
    }

    func testAStreamPlayedFromHereKeepsTheNameOfItsRowWhenItMovesUpTheQueue() {
        let state = playingThroughTuneIn()

        state.setPlayState(.play)
        state.setNowPlaying(rawStream(qid: 4))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Nula Classics")
    }

    func testAStreamThatStopsRightAfterChangingPlaceIsAnotherStream() {
        let state = playing(fip)
        playingThenMovedUp(from: state)

        state.setPlayState(.stop)

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Stream")
    }

    func testThatOtherStreamDoesNotBelieveTheAddressOfTheLastOne() {
        let state = playing(fip)
        playingThenMovedUp(from: state)
        state.setPlayState(.stop)

        state.setTrackMetadata(TrackMetadata(bitrate: 192_000, streamURL: fip))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Stream")
    }

    func testThatOtherStreamIsNotNamedAfterTheRowTheLastOneWasPlayedFrom() {
        let state = playingThroughTuneIn()
        state.setPlayState(.play)
        state.setNowPlaying(rawStream(qid: 6))

        state.setPlayState(.stop)
        state.setNowPlaying(rawStream(qid: 6))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Stream")
    }

    func testAStreamStoppedLongAfterItMovedKeepsItsName() {
        let state = playing(fip)
        playingThenMovedUp(from: state)
        state.playback.rawStream.movedAt = Date(timeIntervalSinceNow: -60)

        state.setPlayState(.stop)

        XCTAssertEqual(state.nowPlaying.displayedTitle, "fip-hifi")
    }

    // MARK: - A station TuneIn resolves into a raw stream

    private let nula = "https://stream.example.com/classics"

    private func playingThroughTuneIn() -> AppState {
        let state = playing(fip)
        state.selectedPlayerID = 42
        state.pendingStreamContext = context(name: "Nula Classics", address: "", after: state)
        state.setNowPlaying(rawStream(qid: 5))
        return state
    }

    func testItTakesTheNameOfTheRowItWasPlayedFrom() {
        XCTAssertEqual(playingThroughTuneIn().nowPlaying.displayedTitle, "Nula Classics")
    }

    func testItKeepsThatNameOnceItsAddressIsRead() {
        let state = playingThroughTuneIn()

        state.setPlayState(.play)
        state.setTrackMetadata(TrackMetadata(bitrate: 128_000, streamURL: nula))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Nula Classics")
    }

    func testItsAddressIsRememberedForTheNextTimeItPlays() {
        let state = playingThroughTuneIn()

        state.setPlayState(.play)
        state.setTrackMetadata(TrackMetadata(bitrate: 128_000, streamURL: nula))

        XCTAssertEqual(state.imageCache.station(forStream: nula)?.name, "Nula Classics")
    }

    func testAnAddressReadBeforeItPlaysIsNotTakenForItsOwn() {
        let state = playingThroughTuneIn()

        state.setTrackMetadata(TrackMetadata(bitrate: 128_000, streamURL: inter))

        XCTAssertNil(state.imageCache.station(forStream: inter))
    }

    // MARK: - A bitrate sent in place of a name

    func testAStationBufferingShowsItsNameRatherThanItsBitrate() {
        let media = NowPlayingMedia(type: .station, song: "128 kbps mp3", albumID: "s50262", mid: "m", qid: 1, sid: 3, station: "Radio Choco")

        XCTAssertEqual([media.displayedTitle, media.displayedStation ?? "-"], ["Radio Choco", "-"])
    }

    func testAStationsSongIsStillItsTitle() {
        let media = NowPlayingMedia(type: .station, song: "Over And Over", albumID: "s50262", mid: "m", qid: 1, sid: 3, station: "Radio Choco")

        XCTAssertEqual([media.displayedTitle, media.displayedStation ?? "-"], ["Over And Over", "Radio Choco"])
    }

    func testARawStreamIsNotNamedAfterTheBitrateSentWithIt() {
        let state = AppState()

        state.setNowPlaying(NowPlayingMedia(
            type: .station, song: "Url Stream", album: "Url Stream", artist: "Url Stream",
            albumID: "1", mid: "1", qid: 1, sid: 1024, station: "64 kbps mp3"
        ))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Stream")
    }

    // MARK: - A station sent with no title

    private func untitledStation(station: String? = "") -> NowPlayingMedia {
        NowPlayingMedia(
            type: .station, song: "", albumID: "s44491", mid: "https://open.live.example.com/redir",
            qid: 1, sid: 3, station: station
        )
    }

    func testAStationSentWithNoTitleTakesTheNameOfItsRow() {
        let state = AppState()
        state.cacheImageURLs(from: [favourite("BBC Radio 6 Music", mid: "s44491")])

        state.setNowPlaying(untitledStation())

        XCTAssertEqual(state.nowPlaying.displayedTitle, "BBC Radio 6 Music")
    }

    func testAStationNoRowWasSeenForStaysUntitled() {
        let state = AppState()

        state.setNowPlaying(untitledStation())

        XCTAssertEqual(state.nowPlaying.displayedTitle, "Not Playing")
    }

    func testARowLoadedAfterTheStationStartedNamesIt() {
        let state = AppState()
        state.setNowPlaying(untitledStation())

        state.cacheImageURLs(from: [favourite("BBC Radio 6 Music", mid: "s44491")])

        XCTAssertEqual(state.nowPlaying.displayedTitle, "BBC Radio 6 Music")
    }

    func testAStationSentWithItsOwnNameKeepsIt() {
        let state = AppState()
        state.cacheImageURLs(from: [favourite("BBC Radio 6 Music", mid: "s44491")])

        state.setNowPlaying(untitledStation(station: "BBC 6"))

        XCTAssertEqual(state.nowPlaying.displayedTitle, "BBC 6")
    }

    // MARK: - In the queue

    func testAPlayingStreamStillMarksItsQueueRow() {
        XCTAssertTrue(playing(fip).nowPlaying.playsFromQueue)
    }

    func testAStationMarksNoQueueRow() {
        let station = NowPlayingMedia(type: .station, song: "Roy Ayers", mid: "s17439", qid: 1, sid: 3, station: "WEFUNK Radio")

        XCTAssertFalse(station.playsFromQueue)
    }

    func testTheRowStandingForAStreamShowsItsNameThenItsHost() {
        let media = playing(inter).nowPlaying

        XCTAssertEqual([media.standaloneRowTitle, media.standaloneRowSubtitle], ["inter-hifi", "stream.example.com"])
    }

    func testTheRowStandingForAStationKeepsItsSongThenItsName() {
        let station = NowPlayingMedia(type: .station, song: "Roy Ayers", mid: "s17439", qid: 1, sid: 3, station: "WEFUNK Radio")

        XCTAssertEqual([station.standaloneRowTitle, station.standaloneRowSubtitle], ["Roy Ayers", "WEFUNK Radio"])
    }
}
