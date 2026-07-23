import Foundation
import NeosDomain
import os

/// Routes HEOS events to the appropriate state updater methods.
/// Extracted from HEOSService to keep event-handling logic in a dedicated unit.
actor EventRouter {
    private let stateUpdater: StateUpdater
    private let playerService: PlayerService?
    private let groupService: GroupService?
    private let browseService: BrowseService?
    private static let serviceTimeout: Duration = .seconds(5)

    init(
        stateUpdater: StateUpdater,
        playerService: PlayerService?,
        groupService: GroupService?,
        browseService: BrowseService?
    ) {
        self.stateUpdater = stateUpdater
        self.playerService = playerService
        self.groupService = groupService
        self.browseService = browseService
    }

    func handle(_ event: HEOSEvent) async {
        switch event.eventName {
        case "player_state_changed":        await handlePlayerStateChanged(event)
        case "player_now_playing_changed":  await handleNowPlayingChanged(event)
        case "player_now_playing_progress": await handleNowPlayingProgress(event)
        case "player_volume_changed":       await handlePlayerVolumeChanged(event)
        case "player_queue_changed":        await handlePlayerQueueChanged(event)
        case "player_playback_error":       await handlePlaybackError(event)
        case "repeat_mode_changed":         await handleRepeatModeChanged(event)
        case "shuffle_mode_changed":        await handleShuffleModeChanged(event)
        case "group_volume_changed":        await handleGroupVolumeChanged(event)
        case "players_changed":             await handlePlayersChanged()
        case "groups_changed":              await handleGroupsChanged()
        case "user_changed":                await handleUserChanged(event)
        case "sources_changed":             await handleSourcesChanged()
        case "system_error":                await handleSystemError(event)
        default: break
        }
    }

    // MARK: - Timeout Helper

    /// Runs an async operation with a timeout.
    /// Returns nil on timeout (caller may retry).
    /// Throws `TransportError` on connection failures (caller should bail).
    private func withTimeout<T: Sendable>(
        _ label: String,
        timeout: Duration = EventRouter.serviceTimeout,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T? {
        do {
            return try await withThrowingTaskGroup(of: T.self) { group in
                group.addTask { try await operation() }
                group.addTask {
                    try await Task.sleep(for: timeout)
                    throw TransportError.timeout
                }
                guard let result = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return result
            }
        } catch let transportError as TransportError {
            // Connection-level failure; retrying won't help
            HEOSLogger.service.debug("EventRouter: \(label) skipped (transport unavailable)")
            throw transportError
        } catch is CancellationError {
            return nil
        } catch {
            HEOSLogger.service.warning("EventRouter timeout/error in \(label): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Player Event Handlers (PID-filtered)

    private func isSelectedPlayer(_ event: HEOSEvent) async -> Bool {
        guard let pidStr = event.message["pid"],
              let pid = Int(pidStr) else { return false }
        return await stateUpdater.selectedPlayerID == pid
    }

    private func handlePlayerStateChanged(_ event: HEOSEvent) async {
        guard await isSelectedPlayer(event) else { return }
        if let stateStr = event.message["state"],
           let state = PlayState(rawValue: stateStr) {
            await stateUpdater.setPlayState(state)
        }
    }

    private func handleNowPlayingChanged(_ event: HEOSEvent) async {
        guard await isSelectedPlayer(event) else { return }
        guard let pidStr = event.message["pid"], let pid = Int(pidStr) else { return }
        for attempt in 0..<3 {
            do {
                if let result = try await withTimeout("now_playing_changed", operation: { [playerService] in
                    try await playerService?.getNowPlayingMedia(pid: pid)
                }) {
                    if let (media, options) = result {
                        await stateUpdater.setNowPlaying(media)
                        await stateUpdater.setNowPlayingOptions(options)
                        return
                    }
                }
            } catch {
                return // Transport error; connection is dead, stop retrying
            }
            if attempt < 2 {
                try? await Task.sleep(for: .milliseconds(300 * (attempt + 1)))
            }
        }
        await stateUpdater.reportNonFatal(source: "event.now_playing_changed", message: "Failed after 3 attempts")
    }

    private func handleNowPlayingProgress(_ event: HEOSEvent) async {
        guard await isSelectedPlayer(event) else { return }
        if let curPos = event.message["cur_pos"].flatMap(Int.init),
           let duration = event.message["duration"].flatMap(Int.init) {
            await stateUpdater.setProgress(position: curPos, duration: duration)
        }
    }

    private func handlePlayerVolumeChanged(_ event: HEOSEvent) async {
        let pid = event.message["pid"].flatMap(Int.init)
        let level = event.message["level"].flatMap(Int.init)
        // Track every player's volume (for per-speaker sliders), not only the selected one.
        if let pid, let level {
            await stateUpdater.setPlayerVolume(pid: pid, level: level)
        }
        // Keep the main single-slider state in sync only for the selected player.
        guard await isSelectedPlayer(event) else { return }
        if let level {
            await stateUpdater.setVolume(level)
        }
        if let muteStr = event.message["mute"] {
            await stateUpdater.setMuted(muteStr == "on")
        }
    }

    private func handlePlayerQueueChanged(_ event: HEOSEvent) async {
        guard await isSelectedPlayer(event) else { return }
        guard let pidStr = event.message["pid"], let pid = Int(pidStr) else { return }
        // Queue fetches can be slow when the device is processing browse commands.
        // Retry up to 3 times with increasing back-off so the UI eventually updates.
        for attempt in 0..<3 {
            do {
                if let queue = try await withTimeout("queue_changed", timeout: .seconds(15), operation: { [playerService] in
                    try await playerService?.getQueue(pid: pid)
                }) {
                    await stateUpdater.setQueue(queue ?? [])
                    return
                }
            } catch {
                return // Transport error; connection is dead, stop retrying
            }
            if attempt < 2 {
                try? await Task.sleep(for: .milliseconds(500 * (attempt + 1)))
            }
        }
        await stateUpdater.reportNonFatal(source: "event.queue_changed", message: "Timed out fetching queue after 3 attempts")
    }

    private func handlePlaybackError(_ event: HEOSEvent) async {
        guard await isSelectedPlayer(event) else { return }
        if let error = event.message["error"] {
            HEOSLogger.service.warning("Playback error: \(error)")
            await stateUpdater.setError(.playbackFailed(error))
        }
    }

    private func handleRepeatModeChanged(_ event: HEOSEvent) async {
        guard await isSelectedPlayer(event) else { return }
        if let modeStr = event.message["repeat"],
           let mode = RepeatMode(rawValue: modeStr) {
            await stateUpdater.setRepeatMode(mode)
        }
    }

    private func handleShuffleModeChanged(_ event: HEOSEvent) async {
        guard await isSelectedPlayer(event) else { return }
        if let modeStr = event.message["shuffle"],
           let mode = ShuffleMode(rawValue: modeStr) {
            await stateUpdater.setShuffleMode(mode)
        }
    }

    // MARK: - Global Event Handlers

    private func handleGroupVolumeChanged(_ event: HEOSEvent) async {
        if let gidStr = event.message["gid"], let gid = Int(gidStr) {
            if let level = event.message["level"].flatMap(Int.init) {
                await stateUpdater.setGroupVolume(gid: gid, level: level)
            }
            if let muteStr = event.message["mute"] {
                await stateUpdater.setGroupMuted(gid: gid, muted: muteStr == "on")
            }
        }
    }

    private func handlePlayersChanged() async {
        do {
            let result = try await withTimeout("players_changed", operation: { [playerService] in
                try await playerService?.getPlayers()
            })
            switch result {
            case .some(.some(let players)):
                await stateUpdater.setPlayers(players)
            case .some(.none):
                // Service was briefly nil; skip update rather than wipe state
                break
            case .none:
                await stateUpdater.reportNonFatal(source: "event.players_changed", message: "Timed out fetching players")
            }
        } catch {
            // Transport error; connection lost
        }
    }

    private func handleGroupsChanged() async {
        do {
            let result = try await withTimeout("groups_changed", operation: { [groupService] in
                try await groupService?.getGroups()
            })
            switch result {
            case .some(.some(let groups)):
                await stateUpdater.setGroups(groups)
            case .some(.none):
                break
            case .none:
                await stateUpdater.reportNonFatal(source: "event.groups_changed", message: "Timed out fetching groups")
            }
        } catch {
            // Transport error; connection lost
        }
    }

    private func handleUserChanged(_ event: HEOSEvent) async {
        if event.message["signed_out"] != nil {
            await stateUpdater.setSignedInUser(nil)
        } else if let un = event.message["un"] {
            await stateUpdater.setSignedInUser(un)
        }
    }

    private func handleSourcesChanged() async {
        do {
            let result = try await withTimeout("sources_changed", operation: { [browseService] in
                try await browseService?.getMusicSources()
            })
            switch result {
            case .some(.some(let sources)):
                await stateUpdater.setMusicSources(sources)
            case .some(.none):
                break
            case .none:
                await stateUpdater.reportNonFatal(source: "event.sources_changed", message: "Timed out fetching sources")
            }
        } catch {
            // Transport error; connection lost
        }
    }

    private func handleSystemError(_ event: HEOSEvent) async {
        let command = event.message["command"] ?? "unknown"
        let error = event.message["error"] ?? "Unknown error"
        HEOSLogger.service.warning("System error for \(command): \(error)")
        await stateUpdater.setError(.deviceError(error))
        await stateUpdater.reportNonFatal(source: "event.system_error", message: "\(command): \(error)")
    }
}
