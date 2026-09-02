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
    private let resyncTask = CancellableTaskHandle()

    /// Gaps are injectable so tests do not wait out the real schedule.
    init(service: any AudioService, state: AppState, metadataAttemptGaps: [Double] = defaultMetadataAttemptGaps) {
        self.service = service
        self.state = state
        self.metadataAttemptGaps = metadataAttemptGaps
    }

    /// Call once after init to start observing track changes and fetching DIDL-Lite metadata.
    /// Waits on `withObservationTracking` so it only runs when the mid actually changes.
    func startTrackMetadataObserver() {
        metadataTask.replace(with: Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                // Re-enters for the track now playing; waiting would skip it until the next one.
                if await self.retryMetadataFetch() { continue }
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

    /// Waits before each attempt, so the four of them land at roughly 0.15s, 1.5s, 3s and 5s.
    /// The amp reports sampleFrequency and bitsPerSample either at once or 1.3 to 4.6 seconds
    /// into a track and never in between, so an exponential backoff spends two attempts inside
    /// the first second, where the answer is not yet there, and still gives up before it is.
    static let defaultMetadataAttemptGaps: [Double] = [0.15, 1.35, 1.5, 2.0]

    private let metadataAttemptGaps: [Double]

    /// Fetches DIDL-Lite metadata while the current mid still lacks a quality description.
    /// Returns true when the track changed while it was working, so the caller starts again for
    /// the one now playing instead of waiting for the track after it.
    private func retryMetadataFetch() async -> Bool {
        let startMid = state.nowPlaying.mid
        for gap in metadataAttemptGaps {
            guard !Task.isCancelled else { return false }
            guard !startMid.isEmpty else { return false }
            guard state.nowPlaying.mid == startMid else { return true }
            let needsFetch = state.trackMetadata == nil || state.trackMetadata?.qualityDescription == nil
            guard needsFetch else { return false }
            // Jittered, so grouped players do not all ask on the same beat.
            let delay = gap + gap * Double.random(in: -0.25...0.25)
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            guard !Task.isCancelled else { return false }
            await fetchTrackMetadata()
        }
        return false
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

    /// Re-syncs the selected player's playback state, recovering from any push events
    /// missed while the connection stayed alive. Triggered when a UI surface appears.
    func resyncPlaybackState() {
        guard let pid = state.selectedPlayerID, state.isConnected else { return }
        resyncTask.replace(with: Task {
            await service.resyncPlaybackState(pid: pid)
        })
    }

    func togglePlayPause() {
        guard let pid = state.selectedPlayerID else { return }
        let wasPlaying = state.isPlaying
        // Optimistic
        state.setPlayStateOptimistically(wasPlaying ? .pause : .play)
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
                state.setPlayStateOptimistically(wasPlaying ? .play : .pause)
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

    func toggleMute() {
        guard let pid = state.selectedPlayerID else { return }
        let wasMuted = state.isMuted
        // Optimistic; the device confirms through player_volume_changed
        state.setMuted(!wasMuted)
        muteTask.replace(with: Task {
            do {
                try await service.toggleMute(pid: pid)
            } catch {
                guard !Task.isCancelled, state.selectedPlayerID == pid else { return }
                // Revert
                state.setMuted(wasMuted)
                state.error = .playbackFailed(error.localizedDescription)
            }
        })
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
