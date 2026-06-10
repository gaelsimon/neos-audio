import Foundation
import NeosDomain

/// Minimal mock conforming to AudioService for ViewModel unit tests.
/// Records calls and returns configurable stub values.
/// Uses @MainActor to avoid data races; tests are @MainActor anyway.
@MainActor
final class MockAudioService: AudioService, @unchecked Sendable {

    // MARK: - Call Recording

    var calls: [String] = []

    // MARK: - Stub Responses

    var playError: Error?
    var pauseError: Error?
    var nextError: Error?
    var previousError: Error?
    var setVolumeError: Error?
    var playModeError: Error?
    var seekError: Error?
    var searchResult: BrowseResult = MockData.searchTracks
    var browseResult: BrowseResult = MockData.deezerRoot
    var historyResult: BrowseResult = MockData.historyRoot
    var queueItems: [QueueItem] = MockData.queueItems
    var groups: [SpeakerGroup] = []
    var searchCriteria: [SearchCriteria] = MockData.searchCriteria
    var createGroupError: Error?
    var ungroupError: Error?
    var removeFromQueueError: Error?
    var playQueueItemError: Error?
    var getQueueError: Error?
    var clearQueueError: Error?
    var signInError: Error?
    var signOutError: Error?
    var accountUser: String?
    var discoveredDevicesList: [DiscoveredDevice] = [MockData.discoveredDevice]
    var discoverError: Error?
    var connectError: Error?
    var powerOffError: Error?
    var powerOnError: Error?

    // MARK: - Connection

    func connect(host: String, port: Int, cachedPlayerID: Int?) async throws {
        calls.append("connect")
        if let error = connectError { throw error }
    }

    func disconnect() async {
        calls.append("disconnect")
    }

    // MARK: - Discovery

    func discoverDevices() async throws -> [DiscoveredDevice] {
        calls.append("discoverDevices")
        if let error = discoverError { throw error }
        return discoveredDevicesList
    }

    nonisolated func startContinuousDiscovery() {}

    func stopContinuousDiscovery() async {
        calls.append("stopContinuousDiscovery")
    }

    // MARK: - Player Actions

    func play(pid: Int) async throws {
        calls.append("play:\(pid)")
        if let error = playError { throw error }
    }

    func pause(pid: Int) async throws {
        calls.append("pause:\(pid)")
        if let error = pauseError { throw error }
    }

    func stop(pid: Int) async throws {
        calls.append("stop:\(pid)")
    }

    func next(pid: Int) async throws {
        calls.append("next:\(pid)")
        if let error = nextError { throw error }
    }

    func previous(pid: Int) async throws {
        calls.append("previous:\(pid)")
        if let error = previousError { throw error }
    }

    func setVolume(pid: Int, level: Int) async throws {
        calls.append("setVolume:\(pid):\(level)")
        if let error = setVolumeError { throw error }
    }

    func toggleMute(pid: Int) async throws {
        calls.append("toggleMute:\(pid)")
    }

    func setPlayMode(pid: Int, repeat repeatMode: RepeatMode, shuffle: ShuffleMode) async throws {
        calls.append("setPlayMode:\(pid):\(repeatMode):\(shuffle)")
        if let error = playModeError { throw error }
    }

    // MARK: - Queue Actions

    func getQueue(pid: Int, range: ClosedRange<Int>?) async throws -> [QueueItem] {
        calls.append("getQueue:\(pid)")
        if let error = getQueueError { throw error }
        return queueItems
    }

    func playQueueItem(pid: Int, qid: Int) async throws {
        calls.append("playQueueItem:\(pid):\(qid)")
        if let error = playQueueItemError { throw error }
    }

    func removeFromQueue(pid: Int, qids: [Int]) async throws {
        calls.append("removeFromQueue:\(pid):\(qids)")
        if let error = removeFromQueueError { throw error }
    }

    func clearQueue(pid: Int) async throws {
        calls.append("clearQueue:\(pid)")
        if let error = clearQueueError { throw error }
    }

    func moveQueueItem(pid: Int, from sourceQIDs: [Int], to destQID: Int) async throws {
        calls.append("moveQueueItem:\(pid)")
    }

    // MARK: - Group Actions

    func getGroups() async throws -> [SpeakerGroup] {
        calls.append("getGroups")
        return groups
    }

    func createGroup(leaderPID: Int, memberPIDs: [Int]) async throws {
        calls.append("createGroup:\(leaderPID):\(memberPIDs)")
        if let error = createGroupError { throw error }
    }

    func ungroup(pid: Int) async throws {
        calls.append("ungroup:\(pid)")
        if let error = ungroupError { throw error }
    }

    func setGroupVolume(gid: Int, level: Int) async throws {
        calls.append("setGroupVolume:\(gid):\(level)")
    }

    func toggleGroupMute(gid: Int) async throws {
        calls.append("toggleGroupMute:\(gid)")
    }

    // MARK: - Browse Actions

    func getMusicSources() async throws -> [MusicSource] {
        calls.append("getMusicSources")
        return []
    }

    func browseSource(sid: Int, range: ClosedRange<Int>?) async throws -> BrowseResult {
        calls.append("browseSource:\(sid)")
        return browseResult
    }

    func browseContainer(sid: Int, cid: String, range: ClosedRange<Int>?) async throws -> BrowseResult {
        calls.append("browseContainer:\(sid):\(cid)")
        return browseResult
    }

    func playStation(pid: Int, sid: Int, cid: String, mid: String, name: String) async throws {
        calls.append("playStation:\(pid):sid=\(sid):cid=\(cid)")
    }

    func playURL(pid: Int, url: String) async throws {
        calls.append("playURL:\(pid)")
    }

    func playInput(pid: Int, input: String) async throws {
        calls.append("playInput:\(pid):\(input)")
    }

    func addToQueue(pid: Int, sid: Int, cid: String, mid: String?, criteria: AddCriteria) async throws {
        calls.append("addToQueue:\(pid)")
    }

    func getHistory(range: ClosedRange<Int>?) async throws -> BrowseResult {
        calls.append("getHistory")
        return historyResult
    }

    func renamePlaylist(sid: Int, cid: String, name: String) async throws {
        calls.append("renamePlaylist")
    }

    func deletePlaylist(sid: Int, cid: String) async throws {
        calls.append("deletePlaylist")
    }

    func setServiceOption(sid: Int, option: Int, params: [String: String]) async throws {
        calls.append("setServiceOption")
    }

    // MARK: - Search Actions

    func getSearchCriteria(sid: Int) async throws -> [SearchCriteria] {
        calls.append("getSearchCriteria:\(sid)")
        return searchCriteria
    }

    func search(sid: Int, query: String, scid: Int, range: ClosedRange<Int>?) async throws -> BrowseResult {
        calls.append("search:\(sid):\(query):\(scid)")
        return searchResult
    }

    // MARK: - Account Actions

    func signIn(username: String, password: String) async throws {
        calls.append("signIn:\(username)")
        if let error = signInError { throw error }
    }

    func signOut() async throws {
        calls.append("signOut")
        if let error = signOutError { throw error }
    }

    func checkAccount() async throws -> String? {
        calls.append("checkAccount")
        return accountUser
    }

    // MARK: - Power Control

    func powerOn() async throws {
        calls.append("powerOn")
        if let error = powerOnError { throw error }
    }
    func powerOff() async throws {
        calls.append("powerOff")
        if let error = powerOffError { throw error }
    }

    // MARK: - UPnP Transport

    func seek(target: TimeInterval) async throws {
        calls.append("seek:\(target)")
        if let error = seekError { throw error }
    }

    func getPositionInfo() async throws -> PositionInfo? {
        calls.append("getPositionInfo")
        return nil
    }

    func fetchTrackMetadata() async throws -> TrackMetadata? {
        calls.append("fetchTrackMetadata")
        return nil
    }

    func getTransportActions() async throws -> Set<String> {
        calls.append("getTransportActions")
        return []
    }
}
