import Foundation

// Stereo/surround bonds (members carry LEFT/RIGHT/… channels) collapse to one leader row;
// plain multi-room groups (all NORMAL) stay expanded. Missing channel info → collapse (safe).

public let normalAudioChannel = "NORMAL"

public extension Array where Element == SpeakerGroup {
    /// Leader PID for a member of a collapsed group; the pid unchanged otherwise.
    func leaderPID(for pid: Int, expanded: Set<Int> = []) -> Int {
        for group in self where !expanded.contains(group.gid)
            && group.players.contains(where: { $0.pid == pid }) {
            return group.leader?.pid ?? pid
        }
        return pid
    }

    /// The group led by `pid`, if any.
    func group(ledBy pid: Int) -> SpeakerGroup? {
        first { $0.leader?.pid == pid }
    }

    /// GIDs whose every member reports NORMAL; anything else collapses.
    func multiRoomGroupIDs(channelsByPID: [Int: String]) -> Set<Int> {
        Set(filter { group in
            group.players.allSatisfy { channelsByPID[$0.pid] == normalAudioChannel }
        }.map(\.gid))
    }
}

public extension Array where Element == Player {
    /// Hides non-leader members of collapsed groups; `expanded` groups keep their members.
    func collapsingGroups(_ groups: [SpeakerGroup], expanded: Set<Int> = []) -> [Player] {
        let hidden = Set(groups.filter { !expanded.contains($0.gid) }.flatMap { $0.members.map(\.pid) })
        guard !hidden.isEmpty else { return self }
        return filter { !hidden.contains($0.pid) }
    }
}
