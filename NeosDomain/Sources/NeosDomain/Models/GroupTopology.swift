import Foundation

// Stereo bonds collapse to one row; plain multi-room stays expanded; unknown channels collapse.

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

public extension Array where Element == SpeakerGroup {
    /// Pair room name by leader serial *and* name: Bonjour reports no serial before connecting.
    func collapsedPairNames(players: [Player], expanded: Set<Int> = []) -> [String: String] {
        var names: [String: String] = [:]
        for group in self where !expanded.contains(group.gid) && !group.members.isEmpty {
            guard let leader = group.leader else { continue }
            let roomName = group.collapsedDisplayName
            if let serial = players.first(where: { $0.pid == leader.pid })?.serial, !serial.isEmpty {
                names[serial] = roomName
            }
            if !leader.name.isEmpty {
                names[leader.name] = roomName
            }
        }
        return names
    }

    /// Names of collapsed-group followers, for discovery entries that carry no serial.
    func collapsedFollowerNames(expanded: Set<Int> = []) -> Set<String> {
        Set(filter { !expanded.contains($0.gid) }
            .flatMap { $0.members.map(\.name) }
            .filter { !$0.isEmpty })
    }
}

public extension Array where Element == DiscoveredDevice {
    /// Hides known followers so a pair shows as one card; falls back to the name without a serial.
    func hidingKnownFollowers(_ followerSerials: Set<String>, names followerNames: Set<String> = []) -> [DiscoveredDevice] {
        guard !followerSerials.isEmpty || !followerNames.isEmpty else { return self }
        return filter { device in
            device.serialNumber.isEmpty
                ? !followerNames.contains(device.friendlyName)
                : !followerSerials.contains(device.serialNumber)
        }
    }
}
