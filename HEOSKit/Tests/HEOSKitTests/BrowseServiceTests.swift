import Testing
import Foundation
@testable import HEOSKit

@Suite("BrowseService Tests")
struct BrowseServiceTests {

    // MARK: - Helpers

    private func makeResponse(command: String, message: String = "", payload: String = "") -> String {
        if payload.isEmpty {
            return """
            {"heos":{"command":"\(command)","result":"success","message":"\(message)"}}
            """
        }
        return """
        {"heos":{"command":"\(command)","result":"success","message":"\(message)"},"payload":\(payload)}
        """
    }

    private func makeSetup() async throws -> (BrowseService, MockTCPTransport, HEOSConnection) {
        let transport = MockTCPTransport(autoRespond: true)
        let connection = HEOSConnection(transport: transport)
        try await connection.connect(host: "test", port: 1255)
        try await Task.sleep(for: .milliseconds(50))
        let service = BrowseService(connection: connection)
        return (service, transport, connection)
    }

    // MARK: - getMusicSources

    @Test func getMusicSourcesReturnsSources() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "browse/get_music_sources",
            payload: """
            [{"name":"TuneIn","image_url":"","type":"music_service","sid":3,"available":"true"},{"name":"Tidal","image_url":"","type":"music_service","sid":10,"available":"true"}]
            """
        ))

        let sources = try await service.getMusicSources()

        #expect(sources.count == 2)
        #expect(sources[0].name == "TuneIn")
        #expect(sources[0].sid == 3)
        #expect(sources[1].name == "Tidal")
        #expect(sources[1].sid == 10)
        await connection.disconnect()
    }

    // MARK: - browseSource

    @Test func browseSourceReturnsItems() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "browse/browse",
            message: "sid=3&returned=2&count=10",
            payload: """
            [{"container":"yes","name":"Favorites","type":"container","cid":"fav_cid","playable":"no","image_url":""},{"container":"yes","name":"Local Radio","type":"container","cid":"local_cid","playable":"no","image_url":""}]
            """
        ))

        let result = try await service.browseSource(sid: 3)

        #expect(result.items.count == 2)
        #expect(result.items[0].name == "Favorites")
        #expect(result.items[0].browsable == true)
        #expect(result.returned == 2)
        #expect(result.count == 10)
        await connection.disconnect()
    }

    // MARK: - browseContainer

    @Test func browseContainerReturnsItems() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "browse/browse",
            message: "sid=3&cid=fav_cid&returned=1&count=1",
            payload: """
            [{"name":"BBC Radio 1","type":"station","mid":"s/12345","playable":"yes","image_url":"https://img.com/bbc.jpg","cid":"fav_cid"}]
            """
        ))

        let result = try await service.browseContainer(sid: 3, cid: "fav_cid")

        #expect(result.items.count == 1)
        #expect(result.items[0].name == "BBC Radio 1")
        #expect(result.items[0].playable == true)
        await connection.disconnect()
    }

    // MARK: - search

    @Test func searchReturnsResults() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "browse/search",
            message: "sid=10&scid=1&returned=1&count=50",
            payload: """
            [{"name":"Music Track","type":"song","mid":"t123","playable":"yes","image_url":"","artist":"Artist","album":"Album"}]
            """
        ))

        let result = try await service.search(sid: 10, query: "music", criteriaID: 1)

        #expect(result.items.count == 1)
        #expect(result.items[0].name == "Music Track")
        await connection.disconnect()
    }

    // MARK: - getSearchCriteria

    @Test func getSearchCriteriaReturnsCriteria() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "browse/get_search_criteria",
            message: "sid=10",
            payload: """
            [{"name":"Artist","scid":1,"cid":null,"wildcard":"yes"},{"name":"Album","scid":2,"cid":null,"wildcard":"yes"},{"name":"Track","scid":3,"cid":null,"wildcard":"yes"}]
            """
        ))

        let criteria = try await service.getSearchCriteria(sid: 10)

        #expect(criteria.count == 3)
        #expect(criteria[0].name == "Artist")
        #expect(criteria[0].scid == 1)
        await connection.disconnect()
    }

    // MARK: - getHistory

    @Test func getHistoryBrowsesSID1026() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "browse/browse",
            message: "sid=1026&returned=1&count=1",
            payload: """
            [{"name":"TRACKS","type":"container","cid":"TRACKS","playable":"no","image_url":"","container":"yes"}]
            """
        ))

        let result = try await service.getHistory()

        #expect(result.items.count == 1)
        #expect(result.items[0].name == "TRACKS")

        let sent = await transport.lastSentString()
        #expect(sent?.contains("sid=1026") == true)
        await connection.disconnect()
    }

    // MARK: - getFavorites

    @Test func getFavoritesBrowsesSID1028() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "browse/browse",
            message: "sid=1028&returned=0&count=0",
            payload: "[]"
        ))

        let result = try await service.getFavorites()

        #expect(result.items.isEmpty)
        let sent = await transport.lastSentString()
        #expect(sent?.contains("sid=1028") == true)
        await connection.disconnect()
    }

    // MARK: - playStation

    @Test func playStationSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "browse/play_stream",
            message: "pid=42&sid=3&cid=fav_cid&mid=s/12345&name=BBC"
        ))

        try await service.playStation(pid: 42, sid: 3, cid: "fav_cid", mid: "s/12345", name: "BBC")

        let sent = await transport.lastSentString()
        #expect(sent?.contains("play_stream") == true)
        await connection.disconnect()
    }

    // MARK: - addToQueue

    @Test func addToQueueWithMIDSendsTrackCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "browse/add_to_queue",
            message: "pid=42"
        ))

        try await service.addToQueue(pid: 42, sid: 10, cid: "c1", mid: "m1", criteria: .playNow)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("add_to_queue") == true)
        #expect(sent?.contains("mid=m1") == true)
        await connection.disconnect()
    }

    @Test func addToQueueWithoutMIDSendsContainerCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "browse/add_to_queue",
            message: "pid=42"
        ))

        try await service.addToQueue(pid: 42, sid: 10, cid: "c1", criteria: .playNow)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("add_to_queue") == true)
        await connection.disconnect()
    }
}
