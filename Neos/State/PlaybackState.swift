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
        var streamURL: String      // the stream URL sent to playURL; empty until read when TuneIn resolves it
        let previousMID: String    // track playing at capture; its tail events must not kill the context
        var previousQID: Int?      // its queue place; a raw stream asked for here takes another
        var enrichedDeviceMID: String?   // set on first enrichment; a different mid means another stream
        var enrichedQID: Int?            // every raw stream shares one mid, so the queue place tells them apart
        var toleratedTail = false        // the outgoing track's replay went by; the next event is ours
    }

    /// What the address reads have said of the raw stream playing.
    struct RawStreamReading {
        var address: String?
        /// The address the shown name came from; nil when the name came with the play.
        var namedFrom: String?
        /// The address of what played before: a speaker still answers with it until the new stream plays.
        var doubted: String?
        /// The speaker reported play since this stream's first event, so the address it gives is this stream's.
        var heardPlay = false
        /// When it last took another queue place while playing, which a stop right after shows to be another stream starting.
        var movedAt: Date?
    }

    // MARK: - Playback

    var playState: PlayState = .stop
    var nowPlaying = NowPlayingMedia()
    var nowPlayingOptions: [ServiceOption] = []
    var trackMetadata: TrackMetadata?
    /// Every raw stream shares one placeholder id, so only a fresh read of its address says which one plays.
    var trackMetadataIsStale = false
    var rawStream = RawStreamReading()
    /// A radio was asked for here and the speaker has not reported playing since.
    var awaitsRadioStart = false
    var volume: Int = 0
    /// The limit set in Settings.
    var volumeLimit: Int?
    /// The limit the speaker reports for itself.
    var speakerVolumeLimit: Int?
    /// The lower of the two.
    var maxVolume: Int? { [volumeLimit, speakerVolumeLimit].compactMap { $0 }.min() }
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
    /// Neos edited the queue and has not seen the amp's version since.
    var queueNeedsReload = false

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
        trackMetadataIsStale = false
        rawStream = RawStreamReading()
        awaitsRadioStart = false
        playbackPosition = 0
        positionBaselineAt = nil
        awaitingResumeConfirmation = false
        playbackDuration = 0
        lastProgressUpdate = .distantPast
        queue = []
        pendingStreamContext = nil
    }
}
