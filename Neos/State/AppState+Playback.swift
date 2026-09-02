import Foundation
import NeosDomain

// MARK: - Play State

extension AppState {
    /// The amp reporting what it is doing.
    func setPlayState(_ state: PlayState) {
        applyPlayState(state, confirmedByDevice: true)
    }

    /// The user pressed play or pause; the amp has not answered yet.
    func setPlayStateOptimistically(_ state: PlayState) {
        applyPlayState(state, confirmedByDevice: false)
    }

    private func applyPlayState(_ state: PlayState, confirmedByDevice: Bool) {
        if state == .play {
            if playback.playState != .play || playback.awaitingResumeConfirmation {
                if confirmedByDevice {
                    // The amp is playing now, so the timeline starts counting from now.
                    playback.lastProgressUpdate = Date()
                    playback.positionBaselineAt = Date()
                    playback.awaitingResumeConfirmation = false
                } else {
                    // Hold the position until the amp says it resumed, the way a seek does.
                    playback.awaitingResumeConfirmation = true
                }
            }
        } else {
            if playback.playState == .play {
                // Freeze where playback actually got to. The last position the amp sent can be
                // seconds old, and resuming from it would rewind the track by that much.
                playback.playbackPosition = playback.interpolatedPosition(at: Date())
                playback.lastProgressUpdate = Date()
            }
            playback.positionBaselineAt = nil
            playback.awaitingResumeConfirmation = false
        }
        playback.playState = state
        // Playback starting is not the end of the load; a waking amp needs ~20 s to describe the track.
        if state != .play {
            endTrackLoad()
        }
    }
}
