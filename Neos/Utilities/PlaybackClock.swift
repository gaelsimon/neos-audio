import Foundation

/// Where playback stands between two progress reports from the speaker, in milliseconds.
enum PlaybackClock {
    static func position(reported: Int, duration: Int, reportedAt: Date, isPlaying: Bool, at now: Date) -> Int {
        guard isPlaying else { return reported }
        let elapsed = now.timeIntervalSince(reportedAt)
        guard elapsed > 0 else { return reported }
        return min(reported + Int(elapsed * 1000), duration)
    }

    /// The same position as a share of the track, 0 when the speaker gives no duration.
    static func fraction(reported: Int, duration: Int, reportedAt: Date, isPlaying: Bool, at now: Date) -> Double {
        guard duration > 0 else { return 0 }
        let current = position(reported: reported, duration: duration, reportedAt: reportedAt, isPlaying: isPlaying, at: now)
        return min(max(Double(current) / Double(duration), 0), 1)
    }
}
