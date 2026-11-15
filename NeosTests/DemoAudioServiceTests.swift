import Foundation
import Testing
import NeosDomain
@testable import Neos

#if DEBUG
/// The demo's speaker against the real app state, which is how the app hears of what it does.
@MainActor
struct DemoAudioServiceTests {
    private final class Clock {
        var now = Date(timeIntervalSince1970: 0)
    }

    private let state = AppState()
    private let clock = Clock()
    private let service: DemoAudioService
    private let pid = DemoDataProvider.playerID
    private let den = DemoDataProvider.denPID
    private let bathroom = DemoDataProvider.bathPID
    private let pair = DemoDataProvider.kitchenLeftPID
    private let deezer = DemoCatalog.deezerSID

    init() {
        DemoDataProvider.populate(state)
        service = DemoAudioService(state: state) { [clock] in clock.now }
    }

    private func wait(_ seconds: TimeInterval) {
        clock.now += seconds
    }

    private func favorites() async throws -> BrowseResult {
        try await service.browseSource(sid: HEOSConstants.favoritesSID, range: nil)
    }

    private func playPulseFM() async throws {
        try await service.playStation(pid: pid, sid: DemoCatalog.tuneInSID, cid: "ti-local", mid: "s/24939", name: "Pulse FM")
    }

    // MARK: - Opening

    @Test func theDemoOpensOnTheQueueItsSpeakerHolds() {
        #expect(state.queue == service.playback.queue)
    }

    @Test func theDemoOpensOnTheTrackItsSpeakerPlays() {
        #expect(state.nowPlaying == service.playback.nowPlaying)
    }

    @Test func aSpeakerWithoutAnAppStillKeepsItsQueue() async throws {
        let lone = DemoAudioService()
        try await lone.clearQueue(pid: pid)
        #expect(lone.playback.queue.isEmpty)
    }

    // MARK: - Transport

    @Test func nextShowsTheFollowingTrack() async throws {
        try await service.next(pid: pid)
        #expect(state.nowPlaying.song == "Glass Weather")
    }

    @Test func nextRestartsTheTimeline() async throws {
        try await service.next(pid: pid)
        #expect(state.playbackPosition < 1_000)
    }

    @Test func nextBringsTheLengthOfTheNewTrack() async throws {
        try await service.next(pid: pid)
        #expect(state.playbackDuration == service.playback.duration)
    }

    @Test func nextOnTheLastTrackLeavesTheTimelineAlone() async throws {
        try await service.next(pid: pid)
        wait(60)
        try await service.next(pid: pid)
        #expect(state.nowPlaying.song == "Glass Weather")
        #expect(state.playbackPosition == 60_000)
    }

    @Test func previousStartsATrackUnderWayAgain() async throws {
        try await service.previous(pid: pid)
        #expect(state.nowPlaying.song == "Paper Lanterns")
        #expect(state.playbackPosition < 1_000)
    }

    @Test func previousOnATrackJustStartedShowsTheEarlierOne() async throws {
        try await service.previous(pid: pid)
        try await service.previous(pid: pid)
        #expect(state.nowPlaying.song == "Keep the Lights On")
    }

    @Test func aTrackRestartedFromPauseRewindsToo() async throws {
        try await service.pause(pid: pid)
        try await service.previous(pid: pid)
        #expect(state.playbackPosition < 1_000)
        #expect(state.playState == .play)
    }

    @Test func pauseIsConfirmed() async throws {
        try await service.pause(pid: pid)
        #expect(state.playState == .pause)
    }

    @Test func aPausedTrackKeepsItsPlace() async throws {
        try await service.pause(pid: pid)
        wait(60)
        try await service.play(pid: pid)
        #expect(state.playbackPosition == DemoDataProvider.opening.position)
    }

    @Test func stopIsConfirmed() async throws {
        try await service.stop(pid: pid)
        #expect(state.playState == .stop)
    }

    @Test func stoppingShowsTheFirstTrackOfTheQueue() async throws {
        try await service.stop(pid: pid)
        #expect(state.nowPlaying.song == "Someone Like Summer")
        #expect(state.playbackPosition < 1_000)
    }

    @Test func seekingMovesTheTimeline() async throws {
        try await service.seek(target: 120)
        #expect(state.playbackPosition == 120_000)
    }

    // MARK: - Time

    @Test func theTimelineFollowsTheTimeThatPassed() async {
        wait(10)
        await service.resyncPlaybackState(pid: pid)
        #expect(state.playbackPosition == DemoDataProvider.opening.position + 10_000)
    }

    @Test func theQueueMovesOnWhenATrackEnds() async {
        wait(Double(DemoDataProvider.opening.duration - DemoDataProvider.opening.position) / 1000)
        await service.resyncPlaybackState(pid: pid)
        #expect(state.nowPlaying.song == "Glass Weather")
        #expect(state.playState == .play)
    }

    @Test func theQueueStopsOnItsFirstTrackAfterTheLast() async throws {
        try await service.next(pid: pid)
        wait(Double(service.playback.duration) / 1000)
        await service.resyncPlaybackState(pid: pid)
        #expect(state.playState == .stop)
        #expect(state.nowPlaying.song == "Someone Like Summer")
    }

    @Test func playingAgainFromThePlayerLetsTheTimelineRun() async {
        let player = PlayerViewModel(service: service, state: state)
        player.togglePlayPause()
        player.togglePlayPause()
        await waitUntil { state.isTimelineRunning }
        #expect(state.isTimelineRunning)
    }

    @Test func playingAQueueItemShowsIt() async throws {
        try await service.playQueueItem(pid: pid, qid: 1)
        #expect(state.nowPlaying.song == "Someone Like Summer")
    }

    @Test func aResyncRepeatsWhatPlays() async {
        state.setNowPlaying(NowPlayingMedia())
        await service.resyncPlaybackState(pid: pid)
        #expect(state.nowPlaying.song == "Paper Lanterns")
    }

    // MARK: - Play mode and volume

    @Test func thePlayModeIsKept() async throws {
        try await service.setPlayMode(pid: pid, repeat: .onAll, shuffle: .on)
        #expect(state.repeatMode == .onAll)
        #expect(state.shuffleMode == .on)
    }

    @Test func aRepeatingQueueWrapsOnNext() async throws {
        try await service.setPlayMode(pid: pid, repeat: .onAll, shuffle: .off)
        try await service.playQueueItem(pid: pid, qid: 4)
        try await service.next(pid: pid)
        #expect(state.nowPlaying.song == "Someone Like Summer")
    }

    @Test func theSelectedSpeakersLevelShowsInThePlayer() async throws {
        try await service.setVolume(pid: pid, level: 30)
        #expect(state.volume == 30)
    }

    @Test func aLevelSetIsTheLevelRead() async throws {
        try await service.setVolume(pid: pid, level: 30)
        let level = try await service.getVolume(pid: pid)
        #expect(level == 30)
    }

    @Test func anotherSpeakersLevelLeavesThePlayerAlone() async throws {
        try await service.setVolume(pid: den, level: 70)
        #expect(state.volume == DemoDataProvider.volume(for: pid))
        #expect(state.playerVolumes[den] == 70)
    }

    @Test func muteTogglesOnTheSelectedSpeaker() async throws {
        try await service.toggleMute(pid: pid)
        #expect(state.isMuted)
        try await service.toggleMute(pid: pid)
        #expect(!state.isMuted)
    }

    @Test func anotherSpeakersMuteLeavesThePlayerAlone() async throws {
        try await service.toggleMute(pid: den)
        #expect(!state.isMuted)
    }

    // MARK: - Queue

    @Test func aRemovedTrackStaysOut() async throws {
        try await service.removeFromQueue(pid: pid, qids: [1])
        let queue = try await service.getQueue(pid: pid, range: nil)
        #expect(queue.map(\.song) == ["Keep the Lights On", "Paper Lanterns", "Glass Weather"])
    }

    @Test func removingAnEarlierTrackRenumbersThePlayingOne() async throws {
        try await service.removeFromQueue(pid: pid, qids: [1])
        #expect(state.nowPlaying.qid == 2)
        #expect(state.queue.map(\.qid) == [1, 2, 3])
    }

    @Test func removingAnEarlierTrackLeavesTheTimelineAlone() async throws {
        try await service.removeFromQueue(pid: pid, qids: [1])
        #expect(state.playbackPosition == DemoDataProvider.opening.position)
    }

    @Test func clearingTheQueueLeavesNothingPlaying() async throws {
        try await service.clearQueue(pid: pid)
        #expect(state.queue.isEmpty)
        #expect(state.playState == .stop)
        #expect(state.nowPlaying.displayedTitle == "Not Playing")
    }

    @Test func clearingTheQueueLeavesNoTrackLengthBehind() async throws {
        try await service.clearQueue(pid: pid)
        #expect(state.playbackDuration == 0)
    }

    @Test func theQueueArrivesInPages() async throws {
        let page = try await service.getQueue(pid: pid, range: 1...2)
        #expect(page.map(\.qid) == [2, 3])
    }

    @Test func aMovedTrackChangesPlaceOnScreen() async throws {
        try await service.moveQueueItem(pid: pid, from: [1], to: 4)
        #expect(state.queue.last?.song == "Someone Like Summer")
    }

    // MARK: - Playing from a source

    @Test func playingAnAlbumReplacesTheQueueWithItsTracks() async throws {
        try await service.addToQueue(pid: pid, sid: deezer, cid: "album-ram", mid: nil, criteria: .replaceAndPlay)
        #expect(state.queue.map(\.song) == ["Tape Hiss", "Signal Path", "Warm Circuit"])
        #expect(state.nowPlaying.song == "Tape Hiss")
    }

    @Test func anAlbumTrackPlaysUnderTheCoverOfItsAlbum() async throws {
        try await service.addToQueue(pid: pid, sid: deezer, cid: "album-ram", mid: nil, criteria: .replaceAndPlay)
        #expect(state.nowPlaying.imageURL == DemoDataProvider.deezerAlbums.last?.imageURL)
    }

    @Test func aTrackPlayedNowJoinsTheQueueAfterTheCurrentOne() async throws {
        let track = try #require(DemoCatalog.container(sid: deezer, cid: "album-ram")?.last)
        try await service.addToQueue(pid: pid, sid: deezer, cid: "album-ram", mid: track.mid, criteria: .playNow)
        #expect(state.queue.map(\.song) == [
            "Someone Like Summer", "Keep the Lights On", "Paper Lanterns", "Warm Circuit", "Glass Weather",
        ])
        #expect(state.nowPlaying.qid == 4)
    }

    @Test func aTrackAddedToTheQueueWaitsAtItsEnd() async throws {
        let track = try #require(DemoCatalog.container(sid: deezer, cid: "album-ram")?.first)
        try await service.addToQueue(pid: pid, sid: deezer, cid: "album-ram", mid: track.mid, criteria: .addToEnd)
        #expect(state.queue.last?.song == "Tape Hiss")
        #expect(state.nowPlaying.song == "Paper Lanterns")
    }

    @Test func aSearchResultPlaysFromTheServiceItWasFoundOn() async throws {
        try await service.addToQueue(pid: pid, sid: DemoCatalog.tidalSID, cid: "", mid: "dz-1896030", criteria: .playNow)
        #expect(state.nowPlaying.song == "Paper Hearts")
        #expect(state.nowPlaying.sid == DemoCatalog.tidalSID)
    }

    @Test func anAlbumFromTheHistoryPlaysItsTracks() async throws {
        try await service.addToQueue(pid: pid, sid: deezer, cid: "dz-album-7890", mid: "dz-album-7890", criteria: .replaceAndPlay)
        #expect(state.queue.map(\.song) == ["Night Drive", "Underpass", "Amber Signal"])
    }

    @Test func theOpeningTrackKeepsItsLengthWhenPlayedFromItsAlbum() async throws {
        try await service.addToQueue(pid: pid, sid: deezer, cid: "album-opera", mid: nil, criteria: .replaceAndPlay)
        #expect(state.playbackDuration == 354_000)
    }

    @Test func aPlayThatNamesNothingStillEndsTheLoading() async throws {
        _ = state.beginTrackLoad()
        try await service.addToQueue(pid: pid, sid: deezer, cid: "nowhere", mid: "nothing", criteria: .playNow)
        #expect(!state.isLoadingTrack)
    }

    // MARK: - Stations and inputs

    @Test func aStationShowsUnderItsName() async throws {
        try await playPulseFM()
        #expect(state.nowPlaying.displayedTitle == "Pulse FM")
    }

    @Test func aStationOffersToBecomeAFavorite() async throws {
        try await playPulseFM()
        #expect(state.nowPlayingOptions.map(\.id) == [ServiceOption.addToFavoritesID])
    }

    @Test func aTrackAfterAStationOffersNothing() async throws {
        try await playPulseFM()
        try await service.playQueueItem(pid: pid, qid: 1)
        #expect(state.nowPlayingOptions.isEmpty)
    }

    @Test func aStationHasNoTimeline() async throws {
        try await playPulseFM()
        #expect(state.playbackDuration == 0)
    }

    @Test func aStationLeavesTheQueueAlone() async throws {
        try await playPulseFM()
        #expect(state.queue == DemoDataProvider.opening.queue)
    }

    @Test func aStationRefusesNext() async throws {
        try await playPulseFM()
        await #expect(throws: DemoPlayback.SkipLimit.self) { try await service.next(pid: pid) }
    }

    @Test func theRefusalReachesTheUser() async throws {
        try await playPulseFM()
        PlayerViewModel(service: service, state: state).next()
        await waitUntil { state.error != nil }
        #expect(state.error == .playbackFailed("Reached skip limit"))
    }

    @Test func pausingAStationStopsIt() async throws {
        try await playPulseFM()
        try await service.pause(pid: pid)
        #expect(state.playState == .stop)
        #expect(state.nowPlaying.displayedTitle == "Pulse FM")
    }

    @Test func aStationReportsTheQualityOfAStream() async throws {
        try await playPulseFM()
        let quality = try await service.fetchTrackMetadata()?.qualityDescription
        #expect(quality == "128 kbps MP3")
    }

    @Test func aTrackReportsALosslessQuality() async throws {
        let quality = try await service.fetchTrackMetadata()?.qualityDescription
        #expect(quality == "24-bit / 96 kHz FLAC")
    }

    @Test func anInputShowsItsName() async throws {
        try await service.playInput(pid: pid, input: "inputs/aux_in")
        #expect(state.nowPlaying.displayedTitle == "Living Room - AUX In")
    }

    @Test func anInputReportsNoQuality() async throws {
        try await service.playInput(pid: pid, input: "inputs/aux_in")
        let metadata = try await service.fetchTrackMetadata()
        #expect(metadata == nil)
    }

    @Test func anInputOffersNothing() async throws {
        try await service.playInput(pid: pid, input: "inputs/aux_in")
        #expect(state.nowPlayingOptions.isEmpty)
    }

    @Test func aURLStreamTakesTheNameItWasPickedUnder() async throws {
        let station = BrowseItem(name: "My Radio", type: .station, mid: "http://example.com/live", playable: true)
        try await PlaybackRouter.play(station, sid: HEOSConstants.favoritesSID, cid: "", service: service, state: state)
        #expect(state.nowPlaying.station == "My Radio")
    }

    @Test func aURLStreamJoinsTheQueueAfterTheCurrentTrack() async throws {
        try await service.playURL(pid: pid, url: "http://example.com/live")
        #expect(state.queue.map(\.song) == [
            "Someone Like Summer", "Keep the Lights On", "Paper Lanterns", "Url Stream", "Glass Weather",
        ])
        #expect(state.nowPlaying.qid == 4)
    }

    @Test func aURLStreamReportsNoQuality() async throws {
        try await service.playURL(pid: pid, url: "http://example.com/live")
        let metadata = try await service.fetchTrackMetadata()
        #expect(metadata == nil)
    }

    // MARK: - Groups

    @Test func aGroupOpensOnTheMeanOfItsSpeakers() {
        #expect(state.groupVolumes[den] == 42)
    }

    @Test func aNewGroupIsNamedAfterItsSpeakers() async throws {
        try await service.createGroup(leaderPID: pid, memberPIDs: [DemoDataProvider.avrMainZonePID])
        #expect(state.groups.last?.name == "Living Room + Denon AVR-X2800H")
    }

    @Test func aNewGroupListsItsMembers() async throws {
        try await service.createGroup(leaderPID: pid, memberPIDs: [DemoDataProvider.avrMainZonePID])
        #expect(state.multiRoomGroupIDs.contains(pid))
    }

    @Test func theStereoPairStaysOneSpeakerWhenGroupsChange() async throws {
        try await service.createGroup(leaderPID: pid, memberPIDs: [DemoDataProvider.avrMainZonePID])
        #expect(!state.multiRoomGroupIDs.contains(pair))
    }

    @Test func aSpeakerThatJoinsLeavesTheGroupItWasIn() async throws {
        try await service.createGroup(leaderPID: pid, memberPIDs: [bathroom])
        #expect(state.groups.map(\.gid) == [pair, pid])
    }

    @Test func aGroupOfOneIsNotMade() async throws {
        try await service.createGroup(leaderPID: pid, memberPIDs: [])
        #expect(state.groups == DemoDataProvider.groups)
    }

    @Test func ungroupingDropsTheGroup() async throws {
        try await service.ungroup(pid: den)
        #expect(state.groups.map(\.gid) == [pair])
    }

    @Test func aRefreshRepeatsTheGroups() async throws {
        state.setGroups([])
        try await service.refreshSpeakers()
        #expect(state.groups == DemoDataProvider.groups)
    }

    @Test func aGroupLevelMovesItsSpeakersByAsMuch() async throws {
        try await service.setGroupVolume(gid: den, level: 52)
        #expect(state.playerVolumes[den] == 65)
        #expect(state.playerVolumes[bathroom] == 40)
    }

    @Test func aGroupLevelIsShownAsSet() async throws {
        try await service.setGroupVolume(gid: den, level: 52)
        #expect(state.groupVolumes[den] == 52)
    }

    @Test func aSpeakerLevelMovesTheMeanOfItsGroup() async throws {
        try await service.setVolume(pid: den, level: 75)
        #expect(state.groupVolumes[den] == 52)
    }

    @Test func aGroupMuteToggles() async throws {
        try await service.toggleGroupMute(gid: den)
        #expect(state.groupMutes[den] == true)
    }

    // MARK: - Account and favourites

    @Test func signingOutTakesTheServicesAway() async throws {
        try await service.signOut()
        let services = try await service.getMusicSources().filter { $0.type == "music_service" }
        #expect(services.allSatisfy { !$0.available })
    }

    @Test func signingOutKeepsTheLocalSources() async throws {
        try await service.signOut()
        let local = try await service.getMusicSources().first { $0.sid == HEOSConstants.localMusicSID }
        #expect(local?.available == true)
    }

    @Test func signingOutLeavesNoAccount() async throws {
        try await service.signOut()
        let account = try await service.checkAccount()
        #expect(account == nil)
    }

    @Test func signingInBringsTheServicesBack() async throws {
        try await service.signOut()
        try await service.signIn(username: "me@example.com", password: "secret")
        let sources = try await service.getMusicSources()
        #expect(sources == DemoDataProvider.musicSources)
    }

    @Test func signingInNamesTheAccount() async throws {
        try await service.signIn(username: "me@example.com", password: "secret")
        let account = try await service.checkAccount()
        #expect(account == "me@example.com")
    }

    @Test func aStationAddedToTheFavoritesIsListedThere() async throws {
        try await service.setServiceOption(
            sid: DemoCatalog.tuneInSID, option: ServiceOption.addToFavoritesID,
            params: ["mid": "s/30001", "name": "Radio Without a Cover"]
        )
        let listed = try await favorites().items
        #expect(listed.last?.name == "Radio Without a Cover")
    }

    @Test func aFavoriteIsListedOnce() async throws {
        try await service.setServiceOption(
            sid: DemoCatalog.tuneInSID, option: ServiceOption.addToFavoritesID, params: ["mid": "s/24939", "name": "Pulse FM"]
        )
        let listed = try await favorites().items
        #expect(listed.count == DemoDataProvider.favorites.count)
    }

    @Test func aRemovedFavoriteIsGone() async throws {
        try await service.setServiceOption(
            sid: DemoCatalog.tuneInSID, option: ServiceOption.removeFromFavoritesID, params: ["mid": "s/24939"]
        )
        let listed = try await favorites().items
        #expect(listed.map(\.name) == ["Eclectic FM", "Daily Mix"])
    }

    @Test func theFavoritesOfferTheirRemoval() async throws {
        let options = try await favorites().options
        #expect(options.map(\.id) == [ServiceOption.removeFromFavoritesID])
    }
}
#endif
