import Foundation
import NeosDomain

public actor BrowseService {
    private let connection: HEOSConnection
    private let parser = HEOSResponseParser()

    // MARK: - Browse Serialization

    /// The HEOS device processes browse commands one at a time. Sending multiple
    /// concurrently causes "command under process" responses and eventual timeouts.
    /// This gate ensures only one browse command is in-flight at a time.
    private struct QueuedWaiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }
    private var browseQueue: [QueuedWaiter] = []
    private var isBrowsing = false

    private func acquireBrowseGate() async throws {
        if !isBrowsing {
            isBrowsing = true
            return
        }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                browseQueue.append(QueuedWaiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelWaiter(id: id) }
        }
        isBrowsing = true
    }

    private func cancelWaiter(id: UUID) {
        guard let index = browseQueue.firstIndex(where: { $0.id == id }) else { return }
        let waiter = browseQueue.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func releaseBrowseGate() {
        if let next = browseQueue.first {
            browseQueue.removeFirst()
            next.continuation.resume()
        } else {
            isBrowsing = false
        }
    }

    public init(connection: HEOSConnection) {
        self.connection = connection
    }

    public func getMusicSources() async throws -> [MusicSource] {
        let response = try await connection.send(.getMusicSources)
        return parser.parseMusicSources(response)
    }

    public func browseSource(sid: Int, range: ClosedRange<Int>? = nil) async throws -> BrowseResult {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        let response = try await connection.send(.browseSource(sid: sid, range: range))
        return parser.parseBrowseResult(response)
    }

    public func browseContainer(sid: Int, cid: String, range: ClosedRange<Int>? = nil) async throws -> BrowseResult {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        let response = try await connection.send(.browseSourceContainer(sid: sid, cid: cid, range: range))
        return parser.parseBrowseResult(response)
    }

    public func search(sid: Int, query: String, criteriaID: Int, range: ClosedRange<Int>? = nil) async throws -> BrowseResult {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        let response = try await connection.send(.search(sid: sid, searchString: query, searchCriteriaID: criteriaID, range: range))
        return parser.parseBrowseResult(response)
    }

    public func getSearchCriteria(sid: Int) async throws -> [SearchCriteria] {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        let response = try await connection.send(.getSearchCriteria(sid: sid))
        return parser.parseSearchCriteria(response)
    }

    public func playStation(pid: Int, sid: Int, cid: String, mid: String, name: String) async throws {
        try await connection.send(.playStation(pid: pid, sid: sid, cid: cid, mid: mid, name: name))
    }

    public func playURL(pid: Int, url: String) async throws {
        try await connection.send(.playURL(pid: pid, url: url))
    }

    public func playPreset(pid: Int, preset: Int) async throws {
        try await connection.send(.playPresetStation(pid: pid, preset: preset))
    }

    public func playInput(pid: Int, input: String, sourcePlayerID: Int? = nil) async throws {
        try await connection.send(.playInputSource(pid: pid, input: input, sourcePlayerID: sourcePlayerID))
    }

    public func addToQueue(pid: Int, sid: Int, cid: String, mid: String? = nil, criteria: AddCriteria) async throws {
        if let mid {
            try await connection.send(.addTrackToQueue(pid: pid, sid: sid, cid: cid, mid: mid, aid: criteria))
        } else {
            try await connection.send(.addContainerToQueue(pid: pid, sid: sid, cid: cid, aid: criteria))
        }
    }

    public func getFavorites(range: ClosedRange<Int>? = nil) async throws -> BrowseResult {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        let response = try await connection.send(.browseSource(sid: 1028, range: range))
        return parser.parseBrowseResult(response)
    }

    public func getPlaylists(range: ClosedRange<Int>? = nil) async throws -> BrowseResult {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        let response = try await connection.send(.browseSource(sid: 1025, range: range))
        return parser.parseBrowseResult(response)
    }

    public func getSourceInfo(sid: Int) async throws -> HEOSResponse {
        try await connection.send(.getSourceInfo(sid: sid))
    }

    public func getHistory(range: ClosedRange<Int>? = nil) async throws -> BrowseResult {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        let response = try await connection.send(.browseSource(sid: 1026, range: range))
        return parser.parseBrowseResult(response)
    }

    public func renamePlaylist(sid: Int, cid: String, name: String) async throws {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        try await connection.send(.renamePlaylist(sid: sid, cid: cid, name: name))
    }

    public func deletePlaylist(sid: Int, cid: String) async throws {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        try await connection.send(.deletePlaylist(sid: sid, cid: cid))
    }

    public func retrieveMetadata(sid: Int, cid: String) async throws -> HEOSResponse {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        return try await connection.send(.retrieveMetadata(sid: sid, cid: cid))
    }

    public func setServiceOption(sid: Int, option: Int, params: [String: String] = [:]) async throws {
        try await acquireBrowseGate()
        defer { releaseBrowseGate() }
        try Task.checkCancellation()
        try await connection.send(.setServiceOption(sid: sid, option: option, params: params))
    }
}
