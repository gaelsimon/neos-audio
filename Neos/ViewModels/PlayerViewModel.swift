import Foundation
import NeosDomain
import os

private let playerLogger = Logger(subsystem: "com.galela.neos", category: "player")

@Observable
@MainActor
final class PlayerViewModel {
    private let service: any AudioService
    private let state: AppState
    private(set) var isSkipping = false
    private let volumeGraceTask = CancellableTaskHandle()
    private let playPauseTask = CancellableTaskHandle()
    private let skipTask = CancellableTaskHandle()
    private let volumeTask = CancellableTaskHandle()
    private let muteTask = CancellableTaskHandle()
    private let playModeTask = CancellableTaskHandle()
    private let seekTask = CancellableTaskHandle()
    private let metadataTask = CancellableTaskHandle()
    private let serviceOptionTask = CancellableTaskHandle()

    init(service: any AudioService, state: AppState) {
        self.service = service
        self.state = state
    }

    /// Call once after init to start observing track changes and fetching DIDL-Lite metadata.
    /// Waits on `withObservationTracking` so it only runs when the mid actually changes.
    func startTrackMetadataObserver() {
        metadataTask.replace(with: Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await retryMetadataFetch()
                guard !Task.isCancelled else { return }
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.state.nowPlaying.mid
                    } onChange: {
                        continuation.resume()
                    }
                }
            }
        })
    }

    /// Fetches DIDL-Lite metadata up to 3 times with exponential backoff while the
    /// current mid still lacks a quality description.
    private func retryMetadataFetch() async {
        let maxRetries = 3
        let startMid = state.nowPlaying.mid
        for attempt in 0..<maxRetries {
            guard !Task.isCancelled else { return }
            guard state.nowPlaying.mid == startMid, !startMid.isEmpty else { return }
            let needsFetch = state.trackMetadata == nil || state.trackMetadata?.qualityDescription == nil
            guard needsFetch else { return }
            // Exponential backoff: 100ms, 200ms, 400ms with +/-25% jitter
            let baseDelay = 0.1 * pow(2.0, Double(attempt))
            let jitter = baseDelay * Double.random(in: -0.25...0.25)
            let delay = baseDelay + jitter
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            guard !Task.isCancelled else { return }
            await fetchTrackMetadata()
        }
    }

    private func fetchTrackMetadata() async {
        do {
            let metadata = try await service.fetchTrackMetadata()
            guard !Task.isCancelled else { return }
            state.playback.trackMetadata = metadata
        } catch {
            playerLogger.debug("Metadata fetch failed (non-fatal): \(error.localizedDescription)")
        }
    }

    func togglePlayPause() {
        guard let pid = state.selectedPlayerID else { return }
        let wasPlaying = state.isPlaying
        // Optimistic
        state.playback.playState = wasPlaying ? .pause : .play
        if !wasPlaying {
            state.playback.lastProgressUpdate = Date()
        }
        playPauseTask.replace(with: Task {
            do {
                if wasPlaying {
                    try await service.pause(pid: pid)
                } else {
                    try await service.play(pid: pid)
                }
            } catch {
                guard !Task.isCancelled, state.selectedPlayerID == pid else { return }
                // Revert
                state.playback.playState = wasPlaying ? .play : .pause
                state.error = .playbackFailed(error.localizedDescription)
            }
        })
    }

    func next() {
        guard let pid = state.selectedPlayerID, !isSkipping else { return }
        isSkipping = true
        skipTask.replace(with: Task {
            defer { isSkipping = false }
            do {
                try await service.next(pid: pid)
            } catch {
                guard !Task.isCancelled, state.selectedPlayerID == pid else { return }
                state.error = .playbackFailed(error.localizedDescription)
            }
        })
    }

    func previous() {
        guard let pid = state.selectedPlayerID, !isSkipping else { return }
        isSkipping = true
        skipTask.replace(with: Task {
            defer { isSkipping = false }
            do {
                try await service.previous(pid: pid)
            } catch {
                guard !Task.isCancelled, state.selectedPlayerID == pid else { return }
                state.error = .playbackFailed(error.localizedDescription)
            }
        })
    }

    func setVolume(_ level: Int) {
        guard let pid = state.selectedPlayerID else { return }
        let capped = min(level, state.maxVolume ?? 100)
        state.playback.volume = capped
        volumeTask.replace(with: Task {
            do {
                try await service.setVolume(pid: pid, level: capped)
            } catch {
                guard !Task.isCancelled, state.selectedPlayerID == pid else { return }
                state.error = .playbackFailed(error.localizedDescription)
            }
        })
    }

    func setAdjustingVolume(_ adjusting: Bool) {
        if adjusting {
            volumeGraceTask.cancel()
            state.isAdjustingVolume = true
        } else {
            volumeGraceTask.replace(with: Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                state.isAdjustingVolume = false
            })
        }
    }

    private var preMuteVolume: Int?

    func toggleMute() {
        guard state.selectedPlayerID != nil else { return }
        if state.volume == 0 {
            // Unmute: restore previous volume (default to 20 if unknown)
            let restore = preMuteVolume ?? 20
            preMuteVolume = nil
            setVolume(restore)
        } else {
            // Mute: save current volume, set to 0
            preMuteVolume = state.volume
            setVolume(0)
        }
    }

    func cycleRepeatMode() {
        guard let pid = state.selectedPlayerID else { return }
        let previousMode = state.repeatMode
        let nextMode: RepeatMode = switch previousMode {
        case .off: .onAll
        case .onAll: .onOne
        case .onOne: .off
        }
        // Optimistic
        state.playback.repeatMode = nextMode
        playModeTask.replace(with: Task {
            do {
                try await service.setPlayMode(pid: pid, repeat: nextMode, shuffle: state.shuffleMode)
            } catch {
                guard !Task.isCancelled, state.selectedPlayerID == pid else { return }
                state.playback.repeatMode = previousMode
                state.error = .playbackFailed(error.localizedDescription)
            }
        })
    }

    func seek(to position: TimeInterval) {
        guard let pid = state.selectedPlayerID else { return }
        // Optimistic: update position and reset interpolation anchor
        state.setProgress(position: Int(position * 1000), duration: state.playbackDuration)
        seekTask.replace(with: Task {
            do {
                try await service.seek(target: position)
            } catch {
                guard !Task.isCancelled, state.selectedPlayerID == pid else { return }
                // Let the next HEOS progress event self-correct
                state.error = .playbackFailed(error.localizedDescription)
            }
        })
    }

    func toggleShuffle() {
        guard let pid = state.selectedPlayerID else { return }
        let previousShuffle = state.shuffleMode
        let newShuffle: ShuffleMode = previousShuffle == .on ? .off : .on
        // Optimistic
        state.playback.shuffleMode = newShuffle
        playModeTask.replace(with: Task {
            do {
                try await service.setPlayMode(pid: pid, repeat: state.repeatMode, shuffle: newShuffle)
            } catch {
                guard !Task.isCancelled, state.selectedPlayerID == pid else { return }
                state.playback.shuffleMode = previousShuffle
                state.error = .playbackFailed(error.localizedDescription)
            }
        })
    }

    // MARK: - Service Options

    func executeServiceOption(_ option: ServiceOption) {
        guard let sid = state.nowPlaying.sid else { return }
        serviceOptionTask.replace(with: Task {
            do {
                var params: [String: String] = [:]
                if option.id == ServiceOption.thumbsUpID || option.id == ServiceOption.thumbsDownID {
                    if let pid = state.selectedPlayerID {
                        params["pid"] = String(pid)
                    }
                }
                if option.id == ServiceOption.addToFavoritesID {
                    params["mid"] = state.nowPlaying.mid
                    params["name"] = state.nowPlaying.station ?? state.nowPlaying.song
                }
                try await service.setServiceOption(sid: sid, option: option.id, params: params)
                state.showToast(option.name, icon: DS.Icons.success, style: .success)
            } catch {
                guard !Task.isCancelled else { return }
                state.showToast("Failed: \(option.name)", icon: DS.Icons.warning, style: .error)
            }
        })
    }
}
