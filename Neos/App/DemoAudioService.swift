import Foundation
import NeosDomain

/// No-op AudioService that returns canned data for demo mode.
/// All mutating commands (play, pause, etc.) are silently accepted
/// so ViewModels can execute without errors.
@MainActor
final class DemoAudioService: AudioService, @unchecked Sendable {

    // MARK: - Connection

    func connect(host: String, port: Int, cachedPlayerID: Int?) async throws {}
    func disconnect() async {}

    // MARK: - Discovery

    func discoverDevices() async throws -> [DiscoveredDevice] { [] }
    nonisolated func startContinuousDiscovery() {}
    func stopContinuousDiscovery() async {}

    // MARK: - Player Actions

    func play(pid: Int) async throws {}
    func pause(pid: Int) async throws {}
    func stop(pid: Int) async throws {}
    func next(pid: Int) async throws {}
    func previous(pid: Int) async throws {}
    func getVolume(pid: Int) async throws -> Int { DemoDataProvider.volume(for: pid) }
    func setVolume(pid: Int, level: Int) async throws {}
    func toggleMute(pid: Int) async throws {}
    func setPlayMode(pid: Int, repeat repeatMode: RepeatMode, shuffle: ShuffleMode) async throws {}

    // MARK: - Queue Actions

    func getQueue(pid: Int, range: ClosedRange<Int>?) async throws -> [QueueItem] {
        DemoDataProvider.queue
    }

    func playQueueItem(pid: Int, qid: Int) async throws {}
    func removeFromQueue(pid: Int, qids: [Int]) async throws {}
    func clearQueue(pid: Int) async throws {}
    func moveQueueItem(pid: Int, from sourceQIDs: [Int], to destQID: Int) async throws {}

    // MARK: - Group Actions

    func getGroups() async throws -> [SpeakerGroup] { DemoDataProvider.groups }
    func createGroup(leaderPID: Int, memberPIDs: [Int]) async throws {}
    func ungroup(pid: Int) async throws {}
    func setGroupVolume(gid: Int, level: Int) async throws {}
    func toggleGroupMute(gid: Int) async throws {}

    // MARK: - Browse Actions

    func getMusicSources() async throws -> [MusicSource] {
        DemoDataProvider.musicSources
    }

    func browseSource(sid: Int, range: ClosedRange<Int>?) async throws -> BrowseResult {
        switch sid {
        case 1028:
            return BrowseResult(items: DemoDataProvider.favorites, returned: DemoDataProvider.favorites.count, count: DemoDataProvider.favorites.count)
        case 1026:
            return BrowseResult(items: DemoDataProvider.history, returned: DemoDataProvider.history.count, count: DemoDataProvider.history.count)
        default:
            return BrowseResult(items: [])
        }
    }

    func browseContainer(sid: Int, cid: String, range: ClosedRange<Int>?) async throws -> BrowseResult {
        BrowseResult(items: [])
    }

    func playStation(pid: Int, sid: Int, cid: String, mid: String, name: String) async throws {}
    func playURL(pid: Int, url: String) async throws {}
    func playInput(pid: Int, input: String) async throws {}
    func addToQueue(pid: Int, sid: Int, cid: String, mid: String?, criteria: AddCriteria) async throws {}

    func getHistory(range: ClosedRange<Int>?) async throws -> BrowseResult {
        BrowseResult(items: DemoDataProvider.history, returned: DemoDataProvider.history.count, count: DemoDataProvider.history.count)
    }

    func renamePlaylist(sid: Int, cid: String, name: String) async throws {}
    func deletePlaylist(sid: Int, cid: String) async throws {}
    func setServiceOption(sid: Int, option: Int, params: [String: String]) async throws {}

    // MARK: - Search Actions

    func getSearchCriteria(sid: Int) async throws -> [SearchCriteria] {
        [
            SearchCriteria(scid: 1, name: "Artist"),
            SearchCriteria(scid: 2, name: "Album"),
            SearchCriteria(scid: 3, name: "Track"),
            SearchCriteria(scid: 4, name: "Playlist")
        ]
    }

    func search(sid: Int, query: String, scid: Int, range: ClosedRange<Int>?) async throws -> BrowseResult {
        BrowseResult(items: DemoDataProvider.searchTracks, returned: DemoDataProvider.searchTracks.count, count: DemoDataProvider.searchTracks.count)
    }

    // MARK: - Account Actions

    func signIn(username: String, password: String) async throws {}
    func signOut() async throws {}
    func checkAccount() async throws -> String? { "user@example.com" }

    // MARK: - Power Control

    func powerOn() async throws {}
    func powerOff() async throws {}

    // MARK: - UPnP Transport

    func seek(target: TimeInterval) async throws {}

    func getPositionInfo() async throws -> PositionInfo? { nil }

    func fetchTrackMetadata() async throws -> TrackMetadata? {
        TrackMetadata(
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            codec: "FLAC",
            genre: "Rock",
            trackNumber: 11
        )
    }

    func getTransportActions() async throws -> Set<String> { [] }

    // MARK: - Playback Sync

    func resyncPlaybackState(pid: Int) async {}
}
