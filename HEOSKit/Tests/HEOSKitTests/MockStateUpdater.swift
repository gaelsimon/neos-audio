@testable import HEOSKit
import NeosDomain
import Foundation

/// Mock StateUpdater for testing EventRouter, ConnectionCoordinator, etc.
@MainActor
final class MockStateUpdater: StateUpdater, @unchecked Sendable {

    // MARK: - Protocol Properties

    var selectedPlayerID: Int?
    var isPoweredOn: Bool = false

    // MARK: - Recorded State

    var connectionState: ConnectionState?
    var players: [Player] = []
    var groups: [SpeakerGroup] = []
    var musicSources: [MusicSource] = []
    var playState: PlayState?
    var nowPlaying: NowPlayingMedia?
    var volume: Int?
    var isMuted: Bool?
    var repeatMode: RepeatMode?
    var shuffleMode: ShuffleMode?
    var progressPosition: Int?
    var progressDuration: Int?
    var queue: [QueueItem] = []
    var signedInUser: String?
    var errorMessage: AppError?
    var groupVolumes: [Int: Int] = [:]
    var groupMuted: [Int: Bool] = [:]
    var discoveredDevices: [DiscoveredDevice] = []
    var maxVolume: Int?
    var trackMetadata: TrackMetadata?
    var nonFatalReports: [(source: String, message: String)] = []
    var snapshot: PlayerSnapshot?
    var serviceCapabilities: [Int: ServiceCapabilities] = [:]
    var nowPlayingOptions: [ServiceOption] = []

    // MARK: - Call Recording

    var calls: [String] = []

    // MARK: - Protocol Methods

    func setConnectionState(_ state: ConnectionState) {
        calls.append("setConnectionState:\(state)")
        connectionState = state
    }

    func setPlayers(_ players: [Player]) {
        calls.append("setPlayers:\(players.count)")
        self.players = players
    }

    func setGroups(_ groups: [SpeakerGroup]) {
        calls.append("setGroups:\(groups.count)")
        self.groups = groups
    }

    func setMusicSources(_ sources: [MusicSource]) {
        calls.append("setMusicSources:\(sources.count)")
        self.musicSources = sources
    }

    func setSelectedPlayerID(_ pid: Int) {
        calls.append("setSelectedPlayerID:\(pid)")
        selectedPlayerID = pid
    }

    func setPlayState(_ state: PlayState) {
        calls.append("setPlayState:\(state)")
        playState = state
    }

    func setNowPlaying(_ media: NowPlayingMedia) {
        calls.append("setNowPlaying:\(media.song)")
        nowPlaying = media
    }

    func setVolume(_ level: Int) {
        calls.append("setVolume:\(level)")
        volume = level
    }

    func setMuted(_ muted: Bool) {
        calls.append("setMuted:\(muted)")
        isMuted = muted
    }

    func setRepeatMode(_ mode: RepeatMode) {
        calls.append("setRepeatMode:\(mode)")
        repeatMode = mode
    }

    func setShuffleMode(_ mode: ShuffleMode) {
        calls.append("setShuffleMode:\(mode)")
        shuffleMode = mode
    }

    func setProgress(position: Int, duration: Int) {
        calls.append("setProgress:\(position):\(duration)")
        progressPosition = position
        progressDuration = duration
    }

    func setQueue(_ items: [QueueItem]) {
        calls.append("setQueue:\(items.count)")
        queue = items
    }

    func setSignedInUser(_ username: String?) {
        calls.append("setSignedInUser:\(username ?? "nil")")
        signedInUser = username
    }

    func setError(_ error: AppError?) {
        calls.append("setError:\(error?.message ?? "nil")")
        errorMessage = error
    }

    func setGroupVolume(gid: Int, level: Int) {
        calls.append("setGroupVolume:\(gid):\(level)")
        groupVolumes[gid] = level
    }

    func setGroupMuted(gid: Int, muted: Bool) {
        calls.append("setGroupMuted:\(gid):\(muted)")
        groupMuted[gid] = muted
    }

    func addDiscoveredDevice(_ device: DiscoveredDevice) {
        calls.append("addDiscoveredDevice:\(device.host)")
        discoveredDevices.append(device)
    }

    func setPowerState(_ isPoweredOn: Bool) {
        calls.append("setPowerState:\(isPoweredOn)")
        self.isPoweredOn = isPoweredOn
    }

    func setMaxVolume(_ level: Int?) {
        calls.append("setMaxVolume:\(level ?? -1)")
        maxVolume = level
    }

    func setTrackMetadata(_ metadata: TrackMetadata?) {
        calls.append("setTrackMetadata")
        trackMetadata = metadata
    }

    func reportNonFatal(source: String, message: String) {
        calls.append("reportNonFatal:\(source)")
        nonFatalReports.append((source: source, message: message))
    }

    func applyPlayerSnapshot(_ snapshot: PlayerSnapshot) {
        calls.append("applyPlayerSnapshot")
        self.snapshot = snapshot
    }

    func setServiceCapabilities(sid: Int, capabilities: ServiceCapabilities) {
        calls.append("setServiceCapabilities:\(sid)")
        serviceCapabilities[sid] = capabilities
    }

    func setNowPlayingOptions(_ options: [ServiceOption]) {
        calls.append("setNowPlayingOptions:\(options.count)")
        nowPlayingOptions = options
    }
}
