import NeosDomain

extension BrowseItem {
    /// A station plays as a stream; the speaker refuses to put one in its queue.
    var canJoinQueue: Bool {
        playable && type != .station
    }
}
