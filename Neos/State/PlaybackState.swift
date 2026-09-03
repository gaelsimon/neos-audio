import Foundation
import NeosDomain

extension NowPlayingMedia {
    /// A station keeps one mid for every song it plays, so the mid alone names the station rather
    /// than what is on it. A song change only counts once the device has settled, which it signals
    /// by sending artwork: before that it reports the stream's format, then an empty title, and
    /// treating either as a new track would throw away metadata that belongs to this one.
    func isDifferentTrack(from other: NowPlayingMedia) -> Bool {
        if mid != other.mid { return true }
        return song != other.song && !imageURL.isEmpty
    }
}

@Observable
@MainActor
final class PlaybackState {

    /// Context captured at play-time for URL streams where the device reports
    /// generic "Url Stream" metadata. Consumed by setNowPlaying to enrich display.
    struct StreamPlayContext {
        let pid: Int
        let stationName: String?   // nil when the name is a URL (not user-facing)
        let browseMID: String      // key for custom artwork (e.g., "u32" or stream URL)
        let imageURL: String       // from BrowseItem
        let streamURL: String      // the actual stream URL sent to playURL
        let previousMID: String    // track playing at capture; its tail events must not kill the context
        var enrichedDeviceMID: String?   // set on first enrichment; a different mid means another stream
        var toleratedTail = false        // the outgoing track's replay went by; the next event is ours
    }

    // MARK: - Playback

    var playState: PlayState = .stop
    var nowPlaying = NowPlayingMedia()
    var nowPlayingOptions: [ServiceOption] = []
    var trackMetadata: TrackMetadata?
    var volume: Int = 0
    var maxVolume: Int?
    var isMuted: Bool = false
    var repeatMode: RepeatMode = .off
    var shuffleMode: ShuffleMode = .off
    var playbackPosition: Int = 0
    var playbackDuration: Int = 0
    var lastProgressUpdate: Date = .distantPast
    /// When the timeline last restarted, on a resume or on a new track, to spot the stale
    /// position the amp reports before the real one.
    var positionBaselineAt: Date?
    /// The user pressed play and the amp has not confirmed yet; the timeline holds until it does.
    var awaitingResumeConfirmation = false

    // MARK: - Queue

    var queue: [QueueItem] = []

    // MARK: - Stream Context

    var pendingStreamContext: StreamPlayContext?

    // MARK: - Computed

    var isPlaying: Bool {
        playState == .play
    }

    var progressPercent: Double {
        guard playbackDuration > 0 else { return 0 }
        return Double(playbackPosition) / Double(playbackDuration)
    }

    /// Interpolated position (ms) accounting for wall-clock time elapsed since last HEOS event.
    /// Only advances while playing; clamped to duration.
    func interpolatedPosition(at now: Date) -> Int {
        guard isPlaying, !awaitingResumeConfirmation else { return playbackPosition }
        let elapsed = now.timeIntervalSince(lastProgressUpdate)
        guard elapsed > 0 else { return playbackPosition }
        let interpolated = playbackPosition + Int(elapsed * 1000)
        return min(interpolated, playbackDuration)
    }

    func interpolatedProgressPercent(at now: Date) -> Double {
        guard playbackDuration > 0 else { return 0 }
        return Double(interpolatedPosition(at: now)) / Double(playbackDuration)
    }

    // MARK: - Reset

    func reset() {
        playState = .stop
        nowPlaying = NowPlayingMedia()
        nowPlayingOptions = []
        trackMetadata = nil
        playbackPosition = 0
        positionBaselineAt = nil
        awaitingResumeConfirmation = false
        playbackDuration = 0
        lastProgressUpdate = .distantPast
        queue = []
        pendingStreamContext = nil
    }
}
