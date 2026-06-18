import Foundation

// HEOS exposes no flag separating a stereo pair from a multi-room group, so both are
// treated the same: the leader represents the group, and control/state target the
// leader — the speaker the device reports playback events for.

public extension Array where Element == SpeakerGroup {
    /// PIDs of non-leader members, hidden from the main list.
    var groupedMemberPIDs: Set<Int> {
        Set(flatMap { $0.members.map(\.pid) })
    }

    /// The leader's PID for a grouped member; the PID itself when ungrouped.
    func leaderPID(for pid: Int) -> Int {
        for group in self where group.players.contains(where: { $0.pid == pid }) {
            return group.leader?.pid ?? pid
        }
        return pid
    }

    /// The group led by `pid`, if any.
    func group(ledBy pid: Int) -> SpeakerGroup? {
        first { $0.leader?.pid == pid }
    }
}

public extension Array where Element == Player {
    /// Drops non-leader members so each pair/group shows as a single (leader) row.
    func collapsingGroups(_ groups: [SpeakerGroup]) -> [Player] {
        let hidden = groups.groupedMemberPIDs
        guard !hidden.isEmpty else { return self }
        return filter { !hidden.contains($0.pid) }
    }
}
