import Foundation

public struct PlayerSnapshot: Sendable {
    public let playState: PlayState
    public let media: NowPlayingMedia
    public let volume: Int
    public let muted: Bool
    public let repeatMode: RepeatMode
    public let shuffleMode: ShuffleMode
    public let queue: [QueueItem]
    public let nowPlayingOptions: [ServiceOption]

    public init(
        playState: PlayState,
        media: NowPlayingMedia,
        volume: Int,
        muted: Bool,
        repeatMode: RepeatMode,
        shuffleMode: ShuffleMode,
        queue: [QueueItem],
        nowPlayingOptions: [ServiceOption] = []
    ) {
        self.playState = playState
        self.media = media
        self.volume = volume
        self.muted = muted
        self.repeatMode = repeatMode
        self.shuffleMode = shuffleMode
        self.queue = queue
        self.nowPlayingOptions = nowPlayingOptions
    }
}
