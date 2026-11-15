import Foundation
import NeosDomain

#if DEBUG
/// Stands in for a speaker in demo mode: it answers from the demo's data and keeps what was played, queued and set.
@MainActor
final class DemoAudioService: AudioService, @unchecked Sendable {
    /// Hears of every change, the way a speaker's events reach the app.
    private let state: (any StateUpdater)?
    private(set) var playback = DemoDataProvider.opening
    private var volumes: [Int: Int] = [:]
    private var mutedPlayers: Set<Int> = []
    private var mutedGroups: Set<Int> = []
    private var groups = DemoDataProvider.groups
    private var favorites = DemoDataProvider.favorites
    private var signedInUser: String? = DemoDataProvider.account

    init(state: (any StateUpdater)? = nil) {
        self.state = state
    }

    // MARK: - Connection

    func connect(host: String, port: Int, cachedPlayerID: Int?) async throws {}
    func disconnect() async {}

    // MARK: - Discovery

    func discoverDevices() async throws -> [DiscoveredDevice] { [] }
    nonisolated func startContinuousDiscovery() {}
    func stopContinuousDiscovery() async {}

    // MARK: - Player Actions

    func play(pid: Int) async throws {
        publishPlayback(trackStarts: playback.set(.play))
    }

    func pause(pid: Int) async throws {
        publishPlayback(trackStarts: playback.set(.pause))
    }

    func stop(pid: Int) async throws {
        publishPlayback(trackStarts: playback.set(.stop))
    }

    func next(pid: Int) async throws {
        publishPlayback(trackStarts: playback.skip(by: 1))
    }

    func previous(pid: Int) async throws {
        publishPlayback(trackStarts: playback.skip(by: -1))
    }

    func getVolume(pid: Int) async throws -> Int {
        volume(of: pid)
    }

    func setVolume(pid: Int, level: Int) async throws {
        volumes[pid] = level
        publishVolume(of: pid)
        for group in groups where group.players.contains(where: { $0.pid == pid }) {
            state?.setGroupVolume(gid: group.gid, level: mean(of: group))
        }
    }

    func toggleMute(pid: Int) async throws {
        mutedPlayers.formSymmetricDifference([pid])
        if pid == state?.selectedPlayerID {
            state?.setMuted(mutedPlayers.contains(pid))
        }
    }

    func setPlayMode(pid: Int, repeat repeatMode: RepeatMode, shuffle: ShuffleMode) async throws {
        playback.repeatMode = repeatMode
        playback.shuffleMode = shuffle
        state?.setRepeatMode(repeatMode)
        state?.setShuffleMode(shuffle)
    }

    // MARK: - Queue Actions

    func getQueue(pid: Int, range: ClosedRange<Int>?) async throws -> [QueueItem] {
        guard let range else { return playback.queue }
        return Array(playback.queue.dropFirst(range.lowerBound).prefix(range.count))
    }

    func playQueueItem(pid: Int, qid: Int) async throws {
        publishPlayback(trackStarts: playback.play(qid: qid))
    }

    func removeFromQueue(pid: Int, qids: [Int]) async throws {
        publishPlayback(trackStarts: playback.remove(qids: qids))
    }

    func clearQueue(pid: Int) async throws {
        playback.clear()
        publishPlayback()
    }

    func moveQueueItem(pid: Int, from sourceQIDs: [Int], to destQID: Int) async throws {
        playback.move(qids: sourceQIDs, to: destQID)
        publishPlayback()
    }

    // MARK: - Group Actions

    func getGroups() async throws -> [SpeakerGroup] { groups }

    func refreshSpeakers() async throws {
        publishSpeakers()
    }

    /// A speaker that joins leaves the group it was in, and a group left without its leader or its members is gone.
    func createGroup(leaderPID: Int, memberPIDs: [Int]) async throws {
        let joining = [leaderPID] + memberPIDs.filter { $0 != leaderPID }
        let players = joining.compactMap { pid in DemoDataProvider.players.first { $0.pid == pid } }
        guard players.count == joining.count, players.count > 1 else { return }
        groups = groups.compactMap { $0.without(Set(joining)) }
        groups.append(SpeakerGroup(
            gid: leaderPID,
            name: players.map(\.name).joined(separator: " + "),
            players: players.map { GroupPlayer(name: $0.name, pid: $0.pid, role: $0.pid == leaderPID ? .leader : .member) }
        ))
        publishSpeakers()
    }

    func ungroup(pid: Int) async throws {
        groups.removeAll { $0.gid == pid }
        publishSpeakers()
    }

    /// The speakers of a group move with it, by as much.
    func setGroupVolume(gid: Int, level: Int) async throws {
        guard let group = groups.first(where: { $0.gid == gid }) else { return }
        let change = level - mean(of: group)
        for player in group.players {
            volumes[player.pid] = min(max(volume(of: player.pid) + change, 0), 100)
            publishVolume(of: player.pid)
        }
        state?.setGroupVolume(gid: gid, level: level)
    }

    func toggleGroupMute(gid: Int) async throws {
        mutedGroups.formSymmetricDifference([gid])
        state?.setGroupMuted(gid: gid, muted: mutedGroups.contains(gid))
    }

    // MARK: - Browse Actions

    func getMusicSources() async throws -> [MusicSource] {
        signedInUser == nil ? DemoDataProvider.sourcesWithServicesRefused(signedIn: false) : DemoDataProvider.musicSources
    }

    func browseSource(sid: Int, range: ClosedRange<Int>?) async throws -> BrowseResult {
        if let items = DemoCatalog.root(of: sid) {
            return DemoCatalog.page(items, range)
        }
        switch sid {
        case HEOSConstants.favoritesSID:
            return BrowseResult(
                items: favorites, returned: favorites.count, count: favorites.count, options: [DemoCatalog.removeFavorite]
            )
        case HEOSConstants.historySID:
            return DemoCatalog.page(DemoDataProvider.history, nil)
        case DemoCatalog.deezerSID:
            return DemoCatalog.page(DemoDataProvider.deezerCategories, nil)
        case DemoCatalog.tidalSID:
            return DemoCatalog.page(DemoDataProvider.tidalCategories, nil)
        default:
            return BrowseResult(items: [])
        }
    }

    func browseContainer(sid: Int, cid: String, range: ClosedRange<Int>?) async throws -> BrowseResult {
        if cid == DemoCatalog.brokenCID {
            throw DemoCatalog.Failure()
        }
        return DemoCatalog.page(DemoCatalog.container(sid: sid, cid: cid) ?? [], range)
    }

    func playStation(pid: Int, sid: Int, cid: String, mid: String, name: String) async throws {
        playback.play(stream: DemoCatalog.station(sid: sid, mid: mid, name: name))
        publishPlayback(trackStarts: true)
    }

    /// A speaker knows nothing of a bare URL but that it is one; the app names it from what the user picked.
    func playURL(pid: Int, url: String) async throws {
        playback.play(stream: NowPlayingMedia(type: .station, song: "Url Stream", mid: url))
        publishPlayback(trackStarts: true)
    }

    func playInput(pid: Int, input: String) async throws {
        playback.play(stream: DemoCatalog.input(input))
        publishPlayback(trackStarts: true)
    }

    func addToQueue(pid: Int, sid: Int, cid: String, mid: String?, criteria: AddCriteria) async throws {
        let tracks = DemoCatalog.tracks(sid: sid, cid: cid, mid: mid)
        publishPlayback(trackStarts: playback.add(tracks, criteria))
    }

    func getHistory(range: ClosedRange<Int>?) async throws -> BrowseResult {
        DemoCatalog.page(DemoDataProvider.history, nil)
    }

    func renamePlaylist(sid: Int, cid: String, name: String) async throws {}
    func deletePlaylist(sid: Int, cid: String) async throws {}

    func setServiceOption(sid: Int, option: Int, params: [String: String]) async throws {
        guard let mid = params["mid"] else { return }
        switch option {
        case ServiceOption.addToFavoritesID where !favorites.contains(where: { $0.mid == mid }):
            favorites.append(DemoCatalog.favorite(named: params["name"] ?? mid, mid: mid, sid: sid))
        case ServiceOption.removeFromFavoritesID:
            favorites.removeAll { $0.mid == mid }
        default:
            break
        }
    }

    // MARK: - Search Actions

    func getSearchCriteria(sid: Int) async throws -> [SearchCriteria] {
        DemoCatalog.criteria(for: sid)
    }

    func search(sid: Int, query: String, scid: Int, range: ClosedRange<Int>?) async throws -> BrowseResult {
        DemoCatalog.page(DemoCatalog.search(sid: sid, scid: scid, query: query), range)
    }

    // MARK: - Account Actions

    func signIn(username: String, password: String) async throws {
        signedInUser = username
    }

    func signOut() async throws {
        signedInUser = nil
    }

    func checkAccount() async throws -> String? { signedInUser }

    // MARK: - Power Control

    func powerOn() async throws {}
    func powerOff() async throws {}

    // MARK: - UPnP Transport

    func seek(target: TimeInterval) async throws {}

    func getPositionInfo() async throws -> PositionInfo? { nil }

    func fetchTrackMetadata() async throws -> TrackMetadata? {
        guard let stream = playback.stream else { return DemoDataProvider.trackQuality }
        return stream.station == nil ? nil : DemoDataProvider.stationQuality
    }

    func getTransportActions() async throws -> Set<String> { [] }

    // MARK: - Playback Sync

    func resyncPlaybackState(pid: Int) async {
        publishPlayback()
    }

    // MARK: - What the app hears

    /// AppState drops a position of exactly zero near a restart, as the stale first report of a real speaker.
    private static let trackStart = 1

    private func publishPlayback(trackStarts: Bool = false) {
        guard let state else { return }
        let media = playback.nowPlaying
        state.setNowPlaying(media)
        state.setNowPlayingOptions(media.station == nil ? [] : [DemoCatalog.addFavorite])
        state.setPlayState(playback.playState)
        state.setQueue(playback.queue)
        if trackStarts {
            state.setProgress(position: Self.trackStart, duration: playback.duration)
        } else if media.mid.isEmpty {
            // Nothing plays any more: the length of the last track must not stay on the timeline.
            state.setProgress(position: 0, duration: 0)
        }
    }

    private func publishVolume(of pid: Int) {
        state?.setPlayerVolume(pid: pid, level: volume(of: pid))
        if pid == state?.selectedPlayerID {
            state?.setVolume(volume(of: pid))
        }
    }

    private func publishSpeakers() {
        guard let state else { return }
        state.setPlayers(DemoDataProvider.players)
        state.setGroups(groups)
        // Only the pair the demo opens with is one; any group made since is multi-room.
        state.setMultiRoomGroups(Set(groups.filter { !DemoDataProvider.pairs.contains($0) }.map(\.gid)))
        for group in groups {
            state.setGroupVolume(gid: group.gid, level: mean(of: group))
        }
    }

    private func volume(of pid: Int) -> Int {
        volumes[pid] ?? DemoDataProvider.volume(for: pid)
    }

    private func mean(of group: SpeakerGroup) -> Int {
        DemoDataProvider.level(of: group) { volume(of: $0) }
    }
}

private extension SpeakerGroup {
    func without(_ leaving: Set<Int>) -> SpeakerGroup? {
        let staying = players.filter { !leaving.contains($0.pid) }
        guard staying.count < players.count else { return self }
        guard staying.count > 1, staying.contains(where: { $0.role == .leader }) else { return nil }
        return SpeakerGroup(gid: gid, name: staying.map(\.name).joined(separator: " + "), players: staying)
    }
}
#endif
