import Foundation

public actor GroupService {
    private let connection: HEOSConnection
    private let parser = HEOSResponseParser()

    public init(connection: HEOSConnection) {
        self.connection = connection
    }

    public func getGroups() async throws -> [SpeakerGroup] {
        let response = try await connection.send(.getGroups)
        return parser.parseGroups(response)
    }

    public func createGroup(leaderPID: Int, memberPIDs: [Int]) async throws {
        let allPIDs = [leaderPID] + memberPIDs
        try await connection.send(.setGroup(playerIDs: allPIDs))
    }

    public func ungroup(pid: Int) async throws {
        try await connection.send(.setGroup(playerIDs: [pid]))
    }

    public func getGroupVolume(gid: Int) async throws -> Int {
        let response = try await connection.send(.getGroupVolume(gid: gid))
        return Int(response.message["level"] ?? "0") ?? 0
    }

    public func setGroupVolume(gid: Int, level: Int) async throws {
        let clamped = max(0, min(100, level))
        try await connection.send(.setGroupVolume(gid: gid, level: clamped))
    }

    public func getGroupMute(gid: Int) async throws -> Bool {
        let response = try await connection.send(.getGroupMute(gid: gid))
        return response.message["state"] == "on"
    }

    public func setGroupMute(gid: Int, muted: Bool) async throws {
        try await connection.send(.setGroupMute(gid: gid, state: muted ? .on : .off))
    }

    public func toggleGroupMute(gid: Int) async throws {
        try await connection.send(.toggleGroupMute(gid: gid))
    }
}
