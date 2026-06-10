import Foundation

public struct SpeakerGroup: Identifiable, Equatable, Sendable {
    public let gid: Int
    public let name: String
    public let players: [GroupPlayer]

    public var id: Int { gid }

    public var leader: GroupPlayer? {
        players.first { $0.role == .leader }
    }

    public var members: [GroupPlayer] {
        players.filter { $0.role == .member }
    }

    public init(gid: Int, name: String, players: [GroupPlayer]) {
        self.gid = gid
        self.name = name
        self.players = players
    }
}

public struct GroupPlayer: Equatable, Sendable {
    public let name: String
    public let pid: Int
    public let role: PlayerRole

    public init(name: String, pid: Int, role: PlayerRole) {
        self.name = name
        self.pid = pid
        self.role = role
    }
}

public enum PlayerRole: String, Sendable {
    case leader
    case member
}
