import Foundation
import NeosDomain

// MARK: - Stream Context Matching

extension AppState {
    /// Whether this event belongs to the stream the context was captured for.
    /// Station to station switching replays the outgoing stream as a generic "Url Stream"
    /// event too, so the incoming context must not treat it as its own.
    static func isEnrichable(_ media: NowPlayingMedia, by ctx: PlaybackState.StreamPlayContext) -> Bool {
        if let bound = ctx.enrichedDeviceMID { return bound == media.mid }
        if Self.sameStream(media.mid, ctx.streamURL) { return true }
        if media.mid != ctx.previousMID { return true }
        // Some devices report a placeholder mid for every raw url stream, so the outgoing and
        // incoming stream look identical. Once its replay has gone by, the event is ours.
        return ctx.toleratedTail
    }

    /// Two references to one stream, ignoring the scheme: a device reports the same station
    /// over http on one play and https on the next.
    static func sameStream(_ lhs: String, _ rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        func stripped(_ s: String) -> Substring {
            if s.hasPrefix("https://") { return s.dropFirst(8) }
            if s.hasPrefix("http://") { return s.dropFirst(7) }
            return s[...]
        }
        return stripped(lhs) == stripped(rhs)
    }
}
