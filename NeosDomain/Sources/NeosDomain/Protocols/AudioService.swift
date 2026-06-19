import Foundation

// MARK: - Sub-Protocols

/// Connection lifecycle management.
public protocol ConnectionService: Sendable {
    func connect(host: String, port: Int, cachedPlayerID: Int?) async throws
    func disconnect() async
}

/// Network discovery of speakers/devices.
public protocol DiscoveryService: Sendable {
    func discoverDevices() async throws -> [DiscoveredDevice]
    func startContinuousDiscovery()
    func stopContinuousDiscovery() async
}

/// Playback transport controls for the selected player.
public protocol PlayerControlService: Sendable {
    func play(pid: Int) async throws
    func pause(pid: Int) async throws
    func stop(pid: Int) async throws
    func next(pid: Int) async throws
    func previous(pid: Int) async throws
    func setVolume(pid: Int, level: Int) async throws
    func toggleMute(pid: Int) async throws
    func setPlayMode(pid: Int, repeat repeatMode: RepeatMode, shuffle: ShuffleMode) async throws
}

/// Queue inspection and manipulation.
public protocol QueueService: Sendable {
    func getQueue(pid: Int, range: ClosedRange<Int>?) async throws -> [QueueItem]
    func playQueueItem(pid: Int, qid: Int) async throws
    func removeFromQueue(pid: Int, qids: [Int]) async throws
    func clearQueue(pid: Int) async throws
    func moveQueueItem(pid: Int, from sourceQIDs: [Int], to destQID: Int) async throws
}

/// Multi-room speaker grouping.
public protocol GroupService: Sendable {
    func getGroups() async throws -> [SpeakerGroup]
    func createGroup(leaderPID: Int, memberPIDs: [Int]) async throws
    func ungroup(pid: Int) async throws
    func setGroupVolume(gid: Int, level: Int) async throws
    func toggleGroupMute(gid: Int) async throws
}

/// Browsing music sources and containers.
public protocol BrowseService: Sendable {
    func getMusicSources() async throws -> [MusicSource]
    func browseSource(sid: Int, range: ClosedRange<Int>?) async throws -> BrowseResult
    func browseContainer(sid: Int, cid: String, range: ClosedRange<Int>?) async throws -> BrowseResult
    func playStation(pid: Int, sid: Int, cid: String, mid: String, name: String) async throws
    func playURL(pid: Int, url: String) async throws
    func playInput(pid: Int, input: String) async throws
    func addToQueue(pid: Int, sid: Int, cid: String, mid: String?, criteria: AddCriteria) async throws
    func getHistory(range: ClosedRange<Int>?) async throws -> BrowseResult
    func renamePlaylist(sid: Int, cid: String, name: String) async throws
    func deletePlaylist(sid: Int, cid: String) async throws
    func setServiceOption(sid: Int, option: Int, params: [String: String]) async throws
}

/// Searching within music sources.
public protocol SearchService: Sendable {
    func getSearchCriteria(sid: Int) async throws -> [SearchCriteria]
    func search(sid: Int, query: String, scid: Int, range: ClosedRange<Int>?) async throws -> BrowseResult
}

/// HEOS account sign-in / sign-out.
public protocol AccountService: Sendable {
    func signIn(username: String, password: String) async throws
    func signOut() async throws
    func checkAccount() async throws -> String?
}

/// Receiver power control.
public protocol PowerControlService: Sendable {
    func powerOn() async throws
    func powerOff() async throws
}

/// UPnP-based transport actions (seek, position, metadata).
public protocol UPnPTransportService: Sendable {
    func seek(target: TimeInterval) async throws
    func getPositionInfo() async throws -> PositionInfo?
    func fetchTrackMetadata() async throws -> TrackMetadata?
    func getTransportActions() async throws -> Set<String>
}

/// Re-reads live playback state to recover from missed push events.
public protocol PlaybackSyncService: Sendable {
    func resyncPlaybackState(pid: Int) async
}

// MARK: - Composite Protocol

/// Abstracts vendor-specific speaker services so the app layer never imports
/// a concrete implementation (e.g. HEOSKit) directly. View models depend on
/// `any AudioService` rather than a concrete actor, enabling testability and
/// future multi-vendor support.
public protocol AudioService:
    ConnectionService & DiscoveryService &
    PlayerControlService & QueueService & GroupService &
    BrowseService & SearchService & AccountService &
    PowerControlService & UPnPTransportService & PlaybackSyncService {}

// MARK: - Default Parameter Overloads

public extension ConnectionService {
    func connect(host: String, port: Int = 1255, cachedPlayerID: Int? = nil) async throws {
        try await connect(host: host, port: port, cachedPlayerID: cachedPlayerID)
    }
}

public extension QueueService {
    func getQueue(pid: Int, range: ClosedRange<Int>? = nil) async throws -> [QueueItem] {
        try await getQueue(pid: pid, range: range)
    }
}

public extension BrowseService {

    func browseSource(sid: Int, range: ClosedRange<Int>? = nil) async throws -> BrowseResult {
        try await browseSource(sid: sid, range: range)
    }

    func browseContainer(sid: Int, cid: String, range: ClosedRange<Int>? = nil) async throws -> BrowseResult {
        try await browseContainer(sid: sid, cid: cid, range: range)
    }

    func getHistory(range: ClosedRange<Int>? = nil) async throws -> BrowseResult {
        try await getHistory(range: range)
    }

    func setServiceOption(sid: Int, option: Int, params: [String: String] = [:]) async throws {
        try await setServiceOption(sid: sid, option: option, params: params)
    }
}

public extension SearchService {
    func search(sid: Int, query: String, scid: Int, range: ClosedRange<Int>? = nil) async throws -> BrowseResult {
        try await search(sid: sid, query: query, scid: scid, range: range)
    }
}
