import Foundation
import NeosDomain
import os

// MARK: - Player Selection

/// Picks the best default player from a list.
/// 1. If `cachedPID` exists in the list, return that player (user's last choice).
/// 2. Otherwise prefer standalone speakers (`lineout == 0`) over AVR zones (`lineout > 0`).
/// 3. Fall back to the first player in the list.
func preferredPlayer(from players: [Player], cachedPID: Int?) -> Player? {
    guard !players.isEmpty else { return nil }

    if let cachedPID, let cached = players.first(where: { $0.pid == cachedPID }) {
        return cached
    }

    // Prefer standalone speakers (lineout == 0) over AVR zones
    if let standalone = players.first(where: { $0.lineout == 0 }) {
        return standalone
    }

    return players.first
}

// MARK: - Lifecycle & State Loading

extension HEOSService {

    func connectUPnP(host: String) {
        // Clean up any existing UPnP sessions (prevents in-flight request leaks on reconnect)
        volumeLimitTask?.cancel()
        volumeLimitTask = nil
        if let old = upnpTransport {
            Task { await old.invalidateSession() }
            self.upnpTransport = nil
        }
        if let old = upnpACT {
            Task { await old.invalidateSession() }
            self.upnpACT = nil
        }

        do {
            upnpTransport = try UPnPAVTransportClient(host: host)
            HEOSLogger.upnp.info("UPnP AVTransport client ready for \(host):60006")
        } catch {
            HEOSLogger.upnp.warning("UPnP AVTransport setup failed: \(error.localizedDescription)")
            self.upnpTransport = nil
        }

        do {
            let actClient = try UPnPACTClient(host: host)
            self.upnpACT = actClient
            volumeLimitTask = Task { await self.queryVolumeLimit(actClient) }
        } catch {
            HEOSLogger.upnp.warning("UPnP ACT setup failed: \(error.localizedDescription)")
            self.upnpACT = nil
        }
    }

    func queryVolumeLimit(_ client: UPnPACTClient) async {
        do {
            let limit = try await client.getVolumeLimit()
            guard !Task.isCancelled else { return }
            HEOSLogger.upnp.info("Volume limit from ACT: \(limit)")
            await stateUpdater.setMaxVolume(limit)
        } catch {
            guard !Task.isCancelled else { return }
            HEOSLogger.upnp.debug("ACT GetVolumeLimit unavailable: \(error.localizedDescription)")
        }
    }

    func connectAVR(host: String) async {
        // Clean up any existing AVR connection (prevents resource/task leaks on reconnect)
        avrEventTask?.cancel()
        avrEventTask = nil
        if let oldClient = avrClient {
            await oldClient.disconnect()
            self.avrClient = nil
        }

        let client = AVRControlClient()
        do {
            try await client.connect(host: host)
            self.avrClient = client

            // Start event listener FIRST (the sole reader on the connection)
            startAVREventListening()

            // Query power state; response flows through the event stream
            do {
                try await client.queryPower()
            } catch {
                await stateUpdater.reportNonFatal(source: "avr.queryPower", message: error.localizedDescription)
            }

        } catch {
            HEOSLogger.avr.warning("AVR connection failed (power control unavailable): \(error.localizedDescription)")
            await stateUpdater.reportNonFatal(source: "avr.connect", message: error.localizedDescription)
            self.avrClient = nil
        }
    }

    func startAVREventListening() {
        guard let avrClient else { return }

        avrEventTask = Task {
            do {
                for try await message in avrClient.receiveStream() {
                    switch message {
                    case "PWON":
                        await stateUpdater.setPowerState(true)
                    case "PWSTANDBY":
                        await stateUpdater.setPowerState(false)
                    case let msg where msg.hasPrefix("MVMAX "):
                        if let heosMax = AVRControlClient.parseMaxVolume(from: msg) {
                            HEOSLogger.avr.info("AVR max volume: \(msg) → HEOS cap: \(heosMax)")
                            await stateUpdater.setMaxVolume(heosMax)
                        }
                    default:
                        break
                    }
                }
            } catch {
                HEOSLogger.avr.warning("AVR event stream ended: \(error.localizedDescription)")
            }
        }
    }

    func ensureConnected() async throws {
        let reconnecting = await connectionCoordinator.isReconnecting
        if connection != nil, !reconnecting {
            return
        }

        // Auto wake-up: if amp is in standby but AVR is reachable, power on and wait
        guard let avrClient, await avrClient.isConnected, !isWakingUp else {
            throw HEOSServiceError.notConnected
        }

        isWakingUp = true
        defer { isWakingUp = false }

        HEOSLogger.avr.info("Auto-powering on amp for pending command...")
        try await avrClient.powerOn()
        await stateUpdater.setPowerState(true)

        // Poll for HEOS reconnection (amp boot takes 3-15s)
        let deadline = ContinuousClock.now + .seconds(15)
        while ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(500))
            let stillReconnecting = await connectionCoordinator.isReconnecting
            if connection != nil, !stillReconnecting {
                HEOSLogger.avr.info("Amp powered on, HEOS reconnected")
                return
            }
        }

        throw HEOSServiceError.notConnected
    }

    func ensurePoweredOn() async throws {
        guard let avrClient, await avrClient.isConnected else { return }
        let powered = await stateUpdater.isPoweredOn
        if !powered {
            HEOSLogger.avr.info("Auto-powering on amp for play action...")
            try await avrClient.powerOn()
            await stateUpdater.setPowerState(true)
            try await Task.sleep(for: .milliseconds(500))
        }
    }

    func setupVolumeThrottles() {
        volumeThrottle = Throttle(interval: .milliseconds(100), action: { [weak self] args in
            try await self?.playerService?.setVolume(pid: args.pid, level: args.level)
        }, onError: { [weak self] error in
            guard let self else { return }
            await self.stateUpdater.reportNonFatal(source: "volumeThrottle", message: error.localizedDescription)
        })
        groupVolumeThrottle = Throttle(interval: .milliseconds(100), action: { [weak self] args in
            try await self?.groupService?.setGroupVolume(gid: args.gid, level: args.level)
        }, onError: { [weak self] error in
            guard let self else { return }
            await self.stateUpdater.reportNonFatal(source: "groupVolumeThrottle", message: error.localizedDescription)
        })
    }

    func loadInitialState(cachedPlayerID: Int? = nil) async {
        if let cachedPID = cachedPlayerID {
            // Fast path: fire all 10 queries in a single parallel burst
            await loadAllStateParallel(cachedPID: cachedPID)
        } else {
            // No cached PID: two-phase approach (need PID from getPlayers first)
            await loadStateTwoPhase()
        }
    }

    func loadAllStateParallel(cachedPID: Int) async {
        // 9 commands fired concurrently; queue is deferred to avoid starvation
        // when HomeViewModel's browse storm starts after setMusicSources.
        async let playersResult = { [playerService] in try? await playerService?.getPlayers() }()
        async let groupsResult = { [groupService] in try? await groupService?.getGroups() }()
        async let sourcesResult = { [browseService] in try? await browseService?.getMusicSources() }()
        async let accountResult = { [systemService] in try? await systemService?.checkAccount() }()
        async let playStateResult = { [playerService] in try? await playerService?.getPlayState(pid: cachedPID) }()
        async let mediaAndOptionsResult = { [playerService] in try? await playerService?.getNowPlayingMedia(pid: cachedPID) }()
        async let volumeResult = { [playerService] in try? await playerService?.getVolume(pid: cachedPID) }()
        async let mutedResult = { [playerService] in try? await playerService?.getMute(pid: cachedPID) }()
        async let playModeResult = { [playerService] in try? await playerService?.getPlayMode(pid: cachedPID) }()

        // Phase 1: UI-critical state; apply as soon as available so the sidebar
        // renders sources without waiting for slower queries (account, queue).
        let players = await playersResult ?? []
        let groups = await groupsResult ?? []
        let sources = await sourcesResult ?? []

        await stateUpdater.setPlayers(players)
        await stateUpdater.setGroups(groups)
        await stateUpdater.setMusicSources(sources)

        // Phase 2: remaining global state (account check may hit cloud servers)
        let signedInUser = await accountResult
        await stateUpdater.setSignedInUser(signedInUser)

        // Determine the correct PID; prefer cached if it still exists, then standalone speakers
        guard let preferred = preferredPlayer(from: players, cachedPID: cachedPID) else {
            HEOSLogger.service.warning("getPlayers returned empty during parallel load; skipping player state")
            return
        }

        let resolvedPID = preferred.pid
        await connectionCoordinator.updateLastPlayerID(resolvedPID)
        await stateUpdater.setSelectedPlayerID(resolvedPID)

        // Phase 3: player-specific state
        if resolvedPID != cachedPID {
            // PID changed; re-fetch player state with correct PID
            HEOSLogger.service.info("Cached PID \(cachedPID) stale, reloading for \(resolvedPID)")
            await loadPlayerState(pid: resolvedPID)
        } else {
            // Cached PID was correct; apply the results we already have
            let playState = await playStateResult ?? .stop
            let mediaAndOptions = await mediaAndOptionsResult
            let media = mediaAndOptions?.media ?? NowPlayingMedia()
            let nowPlayingOptions = mediaAndOptions?.options ?? []
            let volume = await volumeResult ?? 0
            let muted = await mutedResult ?? false
            let playMode = await playModeResult

            let snapshot = PlayerSnapshot(
                playState: playState,
                media: media,
                volume: volume,
                muted: muted,
                repeatMode: playMode?.repeat ?? .off,
                shuffleMode: playMode?.shuffle ?? .off,
                queue: [],
                nowPlayingOptions: nowPlayingOptions
            )
            await apply(snapshot: snapshot)
        }

        // Phase 4: Queue; fetched after player state is applied so it doesn't
        // compete with the browse storm triggered by setMusicSources above.
        let queue = (try? await playerService?.getQueue(pid: resolvedPID)) ?? []
        await stateUpdater.setQueue(queue)
    }

    func loadStateTwoPhase() async {
        async let playersResult = { [playerService] in try? await playerService?.getPlayers() }()
        async let groupsResult = { [groupService] in try? await groupService?.getGroups() }()
        async let sourcesResult = { [browseService] in try? await browseService?.getMusicSources() }()
        async let accountResult = { [systemService] in try? await systemService?.checkAccount() }()

        // Apply UI-critical state first without waiting for account check
        let players = await playersResult ?? []
        let groups = await groupsResult ?? []
        let sources = await sourcesResult ?? []

        await stateUpdater.setPlayers(players)
        await stateUpdater.setGroups(groups)
        await stateUpdater.setMusicSources(sources)

        let signedInUser = await accountResult
        await stateUpdater.setSignedInUser(signedInUser)

        if let player = preferredPlayer(from: players, cachedPID: nil) {
            await connectionCoordinator.updateLastPlayerID(player.pid)
            await stateUpdater.setSelectedPlayerID(player.pid)
            await loadPlayerState(pid: player.pid)
        }
    }

    func loadPlayerState(pid: Int) async {
        let snapshot = await fetchPlayerSnapshot(pid: pid)
        await apply(snapshot: snapshot)
    }

    func fetchPlayerSnapshot(pid: Int) async -> PlayerSnapshot {
        // Fire all 6 player queries concurrently; each has a unique command path
        // so HEOSConnection's FIFO matching handles them correctly.
        // Each wrapped in try? so one failure doesn't cancel siblings.
        async let playStateResult = { [playerService] in try? await playerService?.getPlayState(pid: pid) }()
        async let mediaAndOptionsResult = { [playerService] in try? await playerService?.getNowPlayingMedia(pid: pid) }()
        async let volumeResult = { [playerService] in try? await playerService?.getVolume(pid: pid) }()
        async let mutedResult = { [playerService] in try? await playerService?.getMute(pid: pid) }()
        async let playModeResult = { [playerService] in try? await playerService?.getPlayMode(pid: pid) }()
        async let queueResult = { [playerService] in try? await playerService?.getQueue(pid: pid) }()

        let playState = await playStateResult ?? .stop
        let mediaAndOptions = await mediaAndOptionsResult
        let media = mediaAndOptions?.media ?? NowPlayingMedia()
        let nowPlayingOptions = mediaAndOptions?.options ?? []
        let volume = await volumeResult ?? 0
        let muted = await mutedResult ?? false
        let playMode = await playModeResult
        let queue = await queueResult ?? []

        return PlayerSnapshot(
            playState: playState,
            media: media,
            volume: volume,
            muted: muted,
            repeatMode: playMode?.repeat ?? .off,
            shuffleMode: playMode?.shuffle ?? .off,
            queue: queue,
            nowPlayingOptions: nowPlayingOptions
        )
    }

    func apply(snapshot: PlayerSnapshot) async {
        await stateUpdater.applyPlayerSnapshot(snapshot)
    }

    func startEventListening() {
        guard let connection, let eventRouter else { return }

        eventTask = Task {
            for await event in await connection.makeEventStream() {
                await eventRouter.handle(event)
            }
            // Stream ended; only reconnect if not intentionally disconnected
            guard !Task.isCancelled else { return }
            await handleConnectionLost()
        }
    }

    func handleConnectionLost() async {
        HEOSLogger.service.warning("Connection lost")
        await stateUpdater.setConnectionState(.disconnected)
        await connectionCoordinator.startReconnection { [weak self] host, port, cachedPlayerID in
            try await self?.connect(host: host, port: port, cachedPlayerID: cachedPlayerID)
        }
    }

    func requirePlayerService() throws -> PlayerService {
        guard let playerService else { throw HEOSServiceError.notConnected }
        return playerService
    }

    func requireGroupService() throws -> GroupService {
        guard let groupService else { throw HEOSServiceError.notConnected }
        return groupService
    }

    func requireBrowseService() throws -> BrowseService {
        guard let browseService else { throw HEOSServiceError.notConnected }
        return browseService
    }

    func requireSystemService() throws -> SystemService {
        guard let systemService else { throw HEOSServiceError.notConnected }
        return systemService
    }
}
