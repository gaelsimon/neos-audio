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
    /// Follower names, used for discovery entries without a serial (Bonjour reports none).
    var knownFollowerNames: Set<String> = FollowerCache.loadFollowerNames()
    /// Demo data must never reach the real caches; a demo name would hide a real speaker.
    var persistsDiscoveryCaches = true
    /// Leader serial and leader name → pair room name, for naming a pair before connecting.
    var knownPairNames: [String: String] = FollowerCache.loadPairNames()

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

    private(set) var isLoadingTrack: Bool = false
    var isAdjustingVolume: Bool = false
    var error: AppError?
    var discoveryError: String?
    var isDiscovering: Bool = false
    var toast: ToastMessage?
    var isQueuePanelOpen: Bool = false
    var isNowPlayingCanvasOpen: Bool = false
    /// Drives the search field's focus; shared so the menu bar can focus it too.
    var isSearchFieldFocused: Bool = false
    var canvasDominantColors: [Color] = DominantColorExtractor.defaultColors
    var diagnostics: [DiagnosticEvent] = []
    private var toastDismissTask: Task<Void, Never>?
    private var trackLoadWatchdog: Task<Void, Never>?
    /// Called for every device discovery reports, so a remembered speaker can reconnect on its own.
    @ObservationIgnored var onDeviceDiscovered: ((DiscoveredDevice) -> Void)?

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
        discoveredDevices.hidingKnownFollowers(knownFollowerSerials, names: knownFollowerNames)
    }

    /// Group name when the player leads a *collapsed* group, else its own name.
    func displayName(for player: Player) -> String {
        if let group = groups.group(ledBy: player.pid), !multiRoomGroupIDs.contains(group.gid) {
            return group.collapsedDisplayName
        }
        return player.name
    }

    /// Pre-connect name for a discovered device; a known pair leader shows its room name.
    func displayName(for device: DiscoveredDevice) -> String {
        if !device.serialNumber.isEmpty, let paired = knownPairNames[device.serialNumber] {
            return paired
        }
        return knownPairNames[device.friendlyName] ?? device.friendlyName
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

    /// True from the first connection until the user disconnects; a drop in between is a reconnection.
    private(set) var hasEstablishedSession = false

    // MARK: - StateUpdater

    func setConnectionState(_ state: ConnectionState) {
        connectionState = state
        switch state {
        case .connected:
            hasEstablishedSession = true
        case .disconnected:
            hasEstablishedSession = false
            resetPlaybackState()
            serviceCapabilities = [:]
            searchCriteria = [:]
        case .connecting, .reconnecting:
            break
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

    func setMultiRoomGroups(_ gids: Set<Int>, unconfirmed: Set<Int>) {
        self.multiRoomGroupIDs = gids
        guard persistsDiscoveryCaches else { return }
        // No groups means no pair: clear the caches so an ungrouped speaker reappears in discovery.
        guard !groups.isEmpty else {
            knownFollowerSerials = []
            knownFollowerNames = []
            knownPairNames = [:]
            FollowerCache.clear()
            return
        }
        // A wrong entry hides a real speaker from discovery, so only groups whose channels we
        // actually read may feed the caches. `gids` alone still drives the collapse on screen:
        // an unconfirmed group stays collapsed there, it just never gets remembered as a pair.
        let evidenced = gids.union(unconfirmed)
        // Remember this system's stereo/surround followers so the next launch hides them pre-connect.
        let followers = groups.collapsedFollowerSerials(players: players, expanded: evidenced)
        knownFollowerSerials = followers
        FollowerCache.save(followers)
        let followerNames = groups.collapsedFollowerNames(expanded: evidenced)
        knownFollowerNames = followerNames
        FollowerCache.saveFollowerNames(followerNames)
        let pairNames = groups.collapsedPairNames(players: players, expanded: evidenced)
        knownPairNames = pairNames
        FollowerCache.savePairNames(pairNames)
    }

    func setMusicSources(_ sources: [MusicSource]) {
        self.musicSources = sources
    }

    func setSelectedPlayerID(_ pid: Int) {
        // Collapsed groups target the leader; expanded members stay selectable.
        self.selectedPlayerID = groups.leaderPID(for: pid, expanded: multiRoomGroupIDs)
    }

    // MARK: - Track Loading

    /// Arms the spinner and its watchdog: a device that never reports the track must not strand it.
    func beginTrackLoad(timeout: Duration = .seconds(30)) {
        isLoadingTrack = true
        trackLoadWatchdog?.cancel()
        trackLoadWatchdog = Task {
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled else { return }
            isLoadingTrack = false
        }
    }

    /// Clears the spinner and disarms the watchdog, so an older load cannot clear a newer one.
    func endTrackLoad() {
        trackLoadWatchdog?.cancel()
        trackLoadWatchdog = nil
        isLoadingTrack = false
    }

    // MARK: - Playback

    func setPlayState(_ state: PlayState) {
        // Reset interpolation anchor on resume so elapsed time doesn't include pause duration
        if state == .play && playback.playState != .play {
            playback.lastProgressUpdate = Date()
        }
        playback.playState = state
        // Playback starting is not the end of the load; a waking amp needs ~20 s to describe the track.
        if state != .play {
            endTrackLoad()
        }
    }

    func setNowPlaying(_ media: NowPlayingMedia) {
        endTrackLoad()
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

        onDeviceDiscovered?(device)
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
