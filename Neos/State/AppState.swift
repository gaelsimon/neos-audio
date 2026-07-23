import Foundation
import SwiftUI
import NeosDomain

@Observable
@MainActor
final class AppState: StateUpdater {
    struct DiagnosticEvent: Identifiable, Sendable {
        let id: UUID
        let source: String
        let message: String
        let date: Date

        init(source: String, message: String, date: Date = .now) {
            self.id = UUID()
            self.source = source
            self.message = message
            self.date = date
        }
    }

    // MARK: - Domain State (driven by AudioService via StateUpdater)

    // Connection
    var connectionState: ConnectionState = .disconnected
    var discoveredDevices: [DiscoveredDevice] = []
    var connectedDevice: DiscoveredDevice?
    /// Serials of known stereo/surround followers, hidden from the pre-connect discovery list.
    var knownFollowerSerials: Set<String> = FollowerCache.load()

    // Power
    var isPoweredOn: Bool = true

    // Players
    var players: [Player] = []
    var selectedPlayerID: Int?
    var groups: [SpeakerGroup] = []
    /// GIDs of multi-room groups (members stay listed). Empty until classified, so groups
    /// collapse by default.
    var multiRoomGroupIDs: Set<Int> = []

    // Playback (forwarded from sub-state)
    var playState: PlayState { playback.playState }
    var nowPlaying: NowPlayingMedia { playback.nowPlaying }
    var nowPlayingOptions: [ServiceOption] { playback.nowPlayingOptions }
    var trackMetadata: TrackMetadata? { playback.trackMetadata }
    var volume: Int { playback.volume }
    var maxVolume: Int? { playback.maxVolume }
    var isMuted: Bool { playback.isMuted }
    var repeatMode: RepeatMode { playback.repeatMode }
    var shuffleMode: ShuffleMode { playback.shuffleMode }
    var playbackPosition: Int { playback.playbackPosition }
    var playbackDuration: Int { playback.playbackDuration }
    var lastProgressUpdate: Date { playback.lastProgressUpdate }

    // Queue (forwarded from sub-state)
    var queue: [QueueItem] { playback.queue }

    // Groups
    var groupVolumes: [Int: Int] = [:]
    var groupMutes: [Int: Bool] = [:]
    // Per-speaker volume (by pid), for individual sliders in a multi-room group.
    var playerVolumes: [Int: Int] = [:]
    var adjustingVolumePIDs: Set<Int> = []

    // Browse (forwarded from sub-state)
    var musicSources: [MusicSource] {
        get { browse.musicSources }
        set { browse.musicSources = newValue }
    }
    var serviceCapabilities: [Int: ServiceCapabilities] {
        get { browse.serviceCapabilities }
        set { browse.serviceCapabilities = newValue }
    }
    var searchCriteria: [Int: [SearchCriteria]] {
        get { browse.searchCriteria }
        set { browse.searchCriteria = newValue }
    }

    // Account
    var signedInUser: String?

    // Stream Play Context (forwarded from sub-state)
    typealias StreamPlayContext = PlaybackState.StreamPlayContext
    var pendingStreamContext: PlaybackState.StreamPlayContext? {
        get { playback.pendingStreamContext }
        set { playback.pendingStreamContext = newValue }
    }

    // MARK: - UI State (owned by view models / views, not from StateUpdater)

    var isLoadingTrack: Bool = false
    var isAdjustingVolume: Bool = false
    var error: AppError?
    var discoveryError: String?
    var isDiscovering: Bool = false
    var toast: ToastMessage?
    var isQueuePanelOpen: Bool = false
    var isNowPlayingCanvasOpen: Bool = false
    var canvasDominantColors: [Color] = DominantColorExtractor.defaultColors
    var diagnostics: [DiagnosticEvent] = []
    private var toastDismissTask: Task<Void, Never>?

    // MARK: - Sub-States

    let imageCache = ImageCacheState()
    let browse = BrowseState()
    let playback = PlaybackState()

    // Forwarding; keeps all existing call sites working
    var customStationImages: [String: String] { imageCache.customStationImages }
    var cachedImageURLs: [String: String] { imageCache.cachedImageURLs }

    var selectedPlayer: Player? {
        players.first { $0.pid == selectedPlayerID }
    }

    /// Main-list players with collapsed groups reduced to their leader; multi-room members stay.
    var displayPlayers: [Player] {
        players.collapsingGroups(groups, expanded: multiRoomGroupIDs)
    }

    /// Discovery list with known stereo/surround followers hidden, so a pair shows as one card.
    var visibleDiscoveredDevices: [DiscoveredDevice] {
        discoveredDevices.hidingKnownFollowers(knownFollowerSerials)
    }

    /// Group name when the player leads a *collapsed* group, else its own name.
    func displayName(for player: Player) -> String {
        if let group = groups.group(ledBy: player.pid), !multiRoomGroupIDs.contains(group.gid) {
            return group.name
        }
        return player.name
    }

    /// Display name for the current selection (group name for a collapsed leader).
    var selectedPlayerDisplayName: String? {
        selectedPlayer.map { displayName(for: $0) }
    }

    var isPlaying: Bool { playback.isPlaying }
    var progressPercent: Double { playback.progressPercent }

    func interpolatedPosition(at now: Date) -> Int {
        playback.interpolatedPosition(at: now)
    }

    func interpolatedProgressPercent(at now: Date) -> Double {
        playback.interpolatedProgressPercent(at: now)
    }

    var isConnected: Bool {
        connectionState == .connected
    }

    // MARK: - StateUpdater

    func setConnectionState(_ state: ConnectionState) {
        connectionState = state
        if state == .disconnected {
            resetPlaybackState()
            serviceCapabilities = [:]
            searchCriteria = [:]
        }
    }

    private func resetPlaybackState() {
        playback.reset()
        imageCache.resetAliases()
    }

    func setPlayers(_ players: [Player]) {
        self.players = players
    }

    func setGroups(_ groups: [SpeakerGroup]) {
        // Only drop the classification when the group set changes, so a plain reload
        // (e.g. opening settings) doesn't wipe the current pair/multi-room split.
        if Set(groups.map(\.gid)) != Set(self.groups.map(\.gid)) {
            self.multiRoomGroupIDs = []
        }
        self.groups = groups
    }

    func setMultiRoomGroups(_ gids: Set<Int>) {
        self.multiRoomGroupIDs = gids
        // Remember this system's stereo/surround followers so the next launch hides them pre-connect.
        guard !groups.isEmpty else { return }
        let followers = groups.collapsedFollowerSerials(players: players, expanded: gids)
        knownFollowerSerials = followers
        FollowerCache.save(followers)
    }

    func setMusicSources(_ sources: [MusicSource]) {
        self.musicSources = sources
    }

    func setSelectedPlayerID(_ pid: Int) {
        // Collapsed groups target the leader; expanded members stay selectable.
        self.selectedPlayerID = groups.leaderPID(for: pid, expanded: multiRoomGroupIDs)
    }

    func setPlayState(_ state: PlayState) {
        // Reset interpolation anchor on resume so elapsed time doesn't include pause duration
        if state == .play && playback.playState != .play {
            playback.lastProgressUpdate = Date()
        }
        playback.playState = state
        isLoadingTrack = false
    }

    func setNowPlaying(_ media: NowPlayingMedia) {
        var enrichedMedia = media

        // Enrich generic "Url Stream" metadata with context captured at play-time
        if let ctx = playback.pendingStreamContext,
           ctx.pid == selectedPlayerID,
           media.song == "Url Stream" {
            if let name = ctx.stationName, !name.isEmpty {
                enrichedMedia = NowPlayingMedia(
                    type: media.type, song: media.song, album: media.album,
                    artist: media.artist,
                    imageURL: media.imageURL.isEmpty ? ctx.imageURL : media.imageURL,
                    albumID: media.albumID, mid: media.mid,
                    qid: media.qid, sid: media.sid,
                    station: name
                )
            }
            // Register alias so resolvedImageURL can find custom artwork via browse MID
            if !ctx.browseMID.isEmpty, ctx.browseMID != media.mid {
                imageCache.registerStreamAlias(deviceMID: media.mid, browseMID: ctx.browseMID)
            }
            // Keep context alive; device fires multiple now_playing_changed events
            // for the same stream. Context is cleared when a different track starts
            // or on disconnect.
        } else if playback.pendingStreamContext != nil {
            // Context belongs to another player or another track; drop it
            playback.pendingStreamContext = nil
        }

        if enrichedMedia.mid != playback.nowPlaying.mid {
            playback.trackMetadata = nil
            playback.nowPlayingOptions = []
            playback.playbackPosition = 0
            playback.lastProgressUpdate = Date()
        }
        playback.nowPlaying = enrichedMedia

        // Cache mid → imageURL for later lookup (e.g. favorites with empty image_url)
        if !enrichedMedia.imageURL.isEmpty {
            var entries: [(mid: String, imageURL: String)] = []
            if !enrichedMedia.mid.isEmpty {
                entries.append((mid: enrichedMedia.mid, imageURL: enrichedMedia.imageURL))
            }
            // Station ID lives in albumID (e.g. "s44491"), which matches favorites mid
            if !enrichedMedia.albumID.isEmpty, enrichedMedia.albumID != enrichedMedia.mid {
                entries.append((mid: enrichedMedia.albumID, imageURL: enrichedMedia.imageURL))
            }
            imageCache.cacheImageEntries(entries)
        }
    }

    func setNowPlayingOptions(_ options: [ServiceOption]) {
        playback.nowPlayingOptions = options
    }

    func setTrackMetadata(_ metadata: TrackMetadata?) {
        playback.trackMetadata = metadata
    }

    func setVolume(_ level: Int) {
        guard !isAdjustingVolume else { return }
        playback.volume = level
    }

    func setMuted(_ muted: Bool) {
        playback.isMuted = muted
    }

    func setRepeatMode(_ mode: RepeatMode) {
        playback.repeatMode = mode
    }

    func setShuffleMode(_ mode: ShuffleMode) {
        playback.shuffleMode = mode
    }

    func setProgress(position: Int, duration: Int) {
        playback.playbackPosition = position
        playback.playbackDuration = duration
        playback.lastProgressUpdate = Date()
    }

    func setQueue(_ items: [QueueItem]) {
        playback.queue = items
    }

    func setSignedInUser(_ username: String?) {
        self.signedInUser = username
    }

    func setError(_ error: AppError?) {
        self.error = error
        if case .playbackFailed(let msg) = error {
            showToast(msg, icon: DS.Icons.warning, style: .error)
        }
    }

    func setGroupVolume(gid: Int, level: Int) {
        self.groupVolumes[gid] = level
    }

    func setGroupMuted(gid: Int, muted: Bool) {
        self.groupMutes[gid] = muted
    }

    func setPlayerVolume(pid: Int, level: Int) {
        guard !adjustingVolumePIDs.contains(pid) else { return }
        self.playerVolumes[pid] = level
    }

    /// Marks a speaker's slider as being dragged so incoming events don't fight the drag.
    func setAdjustingVolume(pid: Int, _ adjusting: Bool) {
        if adjusting {
            adjustingVolumePIDs.insert(pid)
        } else {
            adjustingVolumePIDs.remove(pid)
        }
    }

    func setPowerState(_ isPoweredOn: Bool) {
        self.isPoweredOn = isPoweredOn
    }

    func setMaxVolume(_ level: Int?) {
        playback.maxVolume = level.map { max(1, $0) }
    }

    func setServiceCapabilities(sid: Int, capabilities: ServiceCapabilities) {
        self.serviceCapabilities[sid] = capabilities
    }

    func addDiscoveredDevice(_ device: DiscoveredDevice) {
        // Skip IPv6 addresses; HEOS CLI requires IPv4
        guard !device.host.contains(":") else { return }

        if let idx = discoveredDevices.firstIndex(where: { $0.host == device.host }) {
            // Replace if new entry has richer metadata (e.g. friendly name from UPnP)
            let existing = discoveredDevices[idx]
            if existing.friendlyName == existing.host, device.friendlyName != device.host {
                discoveredDevices[idx] = device
            }
        } else {
            discoveredDevices.append(device)
        }
    }

    // MARK: - Toast

    func showToast(_ text: String, icon: String = DS.Icons.success, style: ToastMessage.Style = .success) {
        toastDismissTask?.cancel()
        toast = ToastMessage(text: text, icon: icon, style: style)
        toastDismissTask = Task {
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            toast = nil
        }
    }

    func showNoPlayerToast() {
        showToast("No player selected", icon: DS.Icons.noPlayer, style: .error)
    }

    func reportNonFatal(source: String, message: String) {
        diagnostics.append(DiagnosticEvent(source: source, message: message))
        if diagnostics.count > 100 {
            diagnostics.removeFirst(diagnostics.count - 100)
        }
    }

    // MARK: - Image Cache Forwarding

    func resolvedImageURL(forMID mid: String?, originalURL: String) -> String {
        imageCache.resolvedImageURL(forMID: mid, originalURL: originalURL)
    }

    func setCustomStationImage(url: String, forMID mid: String) {
        imageCache.setCustomStationImage(url: url, forMID: mid)
    }

    func removeCustomStationImage(forMID mid: String) {
        imageCache.removeCustomStationImage(forMID: mid)
    }

    func hasCustomStationImage(forMID mid: String?) -> Bool {
        imageCache.hasCustomStationImage(forMID: mid)
    }

    func cacheImageURLs(from items: [BrowseItem]) {
        imageCache.cacheImageURLs(from: items)
    }
}
