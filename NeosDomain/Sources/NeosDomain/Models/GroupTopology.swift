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

public extension Array where Element == SpeakerGroup {
    /// Serials of collapsed-group followers (stereo/surround members), resolved via `players`.
    func collapsedFollowerSerials(players: [Player], expanded: Set<Int> = []) -> Set<String> {
        let followerPIDs = Set(filter { !expanded.contains($0.gid) }.flatMap { $0.members.map(\.pid) })
        guard !followerPIDs.isEmpty else { return [] }
        return Set(players.filter { followerPIDs.contains($0.pid) }.map(\.serial).filter { !$0.isEmpty })
    }
}

public extension Array where Element == DiscoveredDevice {
    /// Hides devices that are known stereo/surround followers (by serial), so a pair shows as one card.
    func hidingKnownFollowers(_ followerSerials: Set<String>) -> [DiscoveredDevice] {
        guard !followerSerials.isEmpty else { return self }
        return filter { $0.serialNumber.isEmpty || !followerSerials.contains($0.serialNumber) }
    }
}
