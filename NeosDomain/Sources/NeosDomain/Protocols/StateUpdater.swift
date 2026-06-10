import Foundation

@MainActor
public protocol StateUpdater: AnyObject, Sendable {
    var selectedPlayerID: Int? { get }
    var isPoweredOn: Bool { get }
    func setConnectionState(_ state: ConnectionState)
    func setPlayers(_ players: [Player])
    func setGroups(_ groups: [SpeakerGroup])
    func setMusicSources(_ sources: [MusicSource])
    func setSelectedPlayerID(_ pid: Int)
    func setPlayState(_ state: PlayState)
    func setNowPlaying(_ media: NowPlayingMedia)
    func setVolume(_ level: Int)
    func setMuted(_ muted: Bool)
    func setRepeatMode(_ mode: RepeatMode)
    func setShuffleMode(_ mode: ShuffleMode)
    func setProgress(position: Int, duration: Int)
    func setQueue(_ items: [QueueItem])
    func setSignedInUser(_ username: String?)
    func setError(_ error: AppError?)
    func setGroupVolume(gid: Int, level: Int)
    func setGroupMuted(gid: Int, muted: Bool)
    func addDiscoveredDevice(_ device: DiscoveredDevice)
    func setPowerState(_ isPoweredOn: Bool)
    func setMaxVolume(_ level: Int?)
    func setTrackMetadata(_ metadata: TrackMetadata?)
    func reportNonFatal(source: String, message: String)
    func applyPlayerSnapshot(_ snapshot: PlayerSnapshot)
    func setServiceCapabilities(sid: Int, capabilities: ServiceCapabilities)
    func setNowPlayingOptions(_ options: [ServiceOption])
}

public extension StateUpdater {
    func setMaxVolume(_ level: Int?) {}
    func setTrackMetadata(_ metadata: TrackMetadata?) {}

    func reportNonFatal(source: String, message: String) {
        _ = source
        _ = message
    }

    func setServiceCapabilities(sid: Int, capabilities: ServiceCapabilities) {}
    func setNowPlayingOptions(_ options: [ServiceOption]) {}

    func applyPlayerSnapshot(_ snapshot: PlayerSnapshot) {
        setPlayState(snapshot.playState)
        setNowPlaying(snapshot.media)
        setNowPlayingOptions(snapshot.nowPlayingOptions)
        setVolume(snapshot.volume)
        setMuted(snapshot.muted)
        setRepeatMode(snapshot.repeatMode)
        setShuffleMode(snapshot.shuffleMode)
        setQueue(snapshot.queue)
    }
}
