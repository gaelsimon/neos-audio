import Foundation

public actor PlayerService {
    private let connection: HEOSConnection
    private let parser = HEOSResponseParser()

    public init(connection: HEOSConnection) {
        self.connection = connection
    }

    public func getPlayers() async throws -> [Player] {
        let response = try await connection.send(.getPlayers)
        return parser.parsePlayers(response)
    }

    public func getPlayState(pid: Int) async throws -> PlayState {
        let response = try await connection.send(.getPlayState(pid: pid))
        let stateStr = response.message["state"] ?? "stop"
        return PlayState(rawValue: stateStr) ?? .stop
    }

    public func setPlayState(pid: Int, state: PlayState) async throws {
        try await connection.send(.setPlayState(pid: pid, state: state))
    }

    public func getNowPlayingMedia(pid: Int) async throws -> (media: NowPlayingMedia, options: [ServiceOption]) {
        let response = try await connection.send(.getNowPlayingMedia(pid: pid))
        return parser.parseNowPlayingMediaWithOptions(response)
    }

    public func getVolume(pid: Int) async throws -> Int {
        let response = try await connection.send(.getVolume(pid: pid))
        return Int(response.message["level"] ?? "0") ?? 0
    }

    public func setVolume(pid: Int, level: Int) async throws {
        let clamped = max(0, min(100, level))
        try await connection.send(.setVolume(pid: pid, level: clamped))
    }

    public func getMute(pid: Int) async throws -> Bool {
        let response = try await connection.send(.getMute(pid: pid))
        return response.message["state"] == "on"
    }

    public func setMute(pid: Int, muted: Bool) async throws {
        try await connection.send(.setMute(pid: pid, state: muted ? .on : .off))
    }

    public func toggleMute(pid: Int) async throws {
        try await connection.send(.toggleMute(pid: pid))
    }

    public func playNext(pid: Int) async throws {
        try await connection.send(.playNext(pid: pid))
    }

    public func playPrevious(pid: Int) async throws {
        try await connection.send(.playPrevious(pid: pid))
    }

    public func getPlayMode(pid: Int) async throws -> (repeat: RepeatMode, shuffle: ShuffleMode) {
        let response = try await connection.send(.getPlayMode(pid: pid))
        let repeatMode = RepeatMode(rawValue: response.message["repeat"] ?? "off") ?? .off
        let shuffleMode = ShuffleMode(rawValue: response.message["shuffle"] ?? "off") ?? .off
        return (repeatMode, shuffleMode)
    }

    public func setPlayMode(pid: Int, repeat repeatMode: RepeatMode, shuffle: ShuffleMode) async throws {
        try await connection.send(.setPlayMode(pid: pid, repeat: repeatMode, shuffle: shuffle))
    }

    public func getQueue(pid: Int, range: ClosedRange<Int>? = nil) async throws -> [QueueItem] {
        // Queue responses can be large and the device deprioritizes them under
        // heavy browse traffic, so use a longer timeout than the default 10s.
        let response = try await connection.send(.getQueue(pid: pid, range: range), timeout: .seconds(20))
        return parser.parseQueueItems(response)
    }

    public func playQueueItem(pid: Int, qid: Int) async throws {
        try await connection.send(.playQueueItem(pid: pid, qid: qid))
    }

    public func removeFromQueue(pid: Int, qids: [Int]) async throws {
        try await connection.send(.removeFromQueue(pid: pid, qids: qids))
    }

    public func clearQueue(pid: Int) async throws {
        try await connection.send(.clearQueue(pid: pid))
    }

    public func moveQueueItem(pid: Int, from sourceQIDs: [Int], to destQID: Int) async throws {
        try await connection.send(.moveQueueItem(pid: pid, sourceQueueIDs: sourceQIDs, destinationQueueID: destQID))
    }

    public func saveQueue(pid: Int, name: String) async throws {
        try await connection.send(.saveQueue(pid: pid, name: name))
    }

    public func checkUpdate(pid: Int) async throws -> HEOSResponse {
        try await connection.send(.checkUpdate(pid: pid))
    }
}
