import Testing
import Foundation
@testable import HEOSKit

@Suite("PlayerService Tests")
struct PlayerServiceTests {

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

    private func makeSetup() async throws -> (PlayerService, MockTCPTransport, HEOSConnection) {
        let transport = MockTCPTransport(autoRespond: true)
        let connection = HEOSConnection(transport: transport)
        try await connection.connect(host: "test", port: 1255)
        try await Task.sleep(for: .milliseconds(50))
        let service = PlayerService(connection: connection)
        return (service, transport, connection)
    }

    // MARK: - getPlayers

    @Test func getPlayersReturnsPlayerList() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_players",
            payload: """
            [{"name":"Living Room","pid":42,"model":"HEOS 1","version":"1.0","ip":"10.0.0.1","network":"wired","lineout":0,"serial":"ABC123"}]
            """
        ))

        let players = try await service.getPlayers()

        #expect(players.count == 1)
        #expect(players[0].pid == 42)
        #expect(players[0].name == "Living Room")
        await connection.disconnect()
    }

    @Test func getPlayersEmptyPayloadReturnsEmpty() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_players",
            payload: "[]"
        ))

        let players = try await service.getPlayers()

        #expect(players.isEmpty)
        await connection.disconnect()
    }

    // MARK: - getPlayState

    @Test func getPlayStateReturnsPlay() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_play_state",
            message: "pid=42&state=play"
        ))

        let state = try await service.getPlayState(pid: 42)

        #expect(state == .play)
        await connection.disconnect()
    }

    @Test func getPlayStateReturnsPause() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_play_state",
            message: "pid=42&state=pause"
        ))

        let state = try await service.getPlayState(pid: 42)

        #expect(state == .pause)
        await connection.disconnect()
    }

    @Test func getPlayStateDefaultsToStop() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_play_state",
            message: "pid=42"
        ))

        let state = try await service.getPlayState(pid: 42)

        #expect(state == .stop)
        await connection.disconnect()
    }

    // MARK: - getVolume

    @Test func getVolumeReturnsLevel() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_volume",
            message: "pid=42&level=65"
        ))

        let level = try await service.getVolume(pid: 42)

        #expect(level == 65)
        await connection.disconnect()
    }

    @Test func getVolumeDefaultsToZero() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_volume",
            message: "pid=42"
        ))

        let level = try await service.getVolume(pid: 42)

        #expect(level == 0)
        await connection.disconnect()
    }

    // MARK: - setVolume (clamping)

    @Test func setVolumeSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "player/set_volume", message: "pid=42&level=50"))

        try await service.setVolume(pid: 42, level: 50)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("set_volume") == true)
        #expect(sent?.contains("level=50") == true)
        await connection.disconnect()
    }

    @Test func setVolumeClampsTooHigh() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "player/set_volume", message: "pid=42&level=100"))

        try await service.setVolume(pid: 42, level: 150)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("level=100") == true)
        await connection.disconnect()
    }

    @Test func setVolumeClampsTooLow() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "player/set_volume", message: "pid=42&level=0"))

        try await service.setVolume(pid: 42, level: -10)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("level=0") == true)
        await connection.disconnect()
    }

    // MARK: - getMute

    @Test func getMuteReturnsTrue() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_mute",
            message: "pid=42&state=on"
        ))

        let muted = try await service.getMute(pid: 42)

        #expect(muted == true)
        await connection.disconnect()
    }

    @Test func getMuteReturnsFalse() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_mute",
            message: "pid=42&state=off"
        ))

        let muted = try await service.getMute(pid: 42)

        #expect(muted == false)
        await connection.disconnect()
    }

    // MARK: - getPlayMode

    @Test func getPlayModeReturnsModes() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_play_mode",
            message: "pid=42&repeat=on_all&shuffle=on"
        ))

        let mode = try await service.getPlayMode(pid: 42)

        #expect(mode.repeat == .onAll)
        #expect(mode.shuffle == .on)
        await connection.disconnect()
    }

    @Test func getPlayModeDefaultsToOff() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_play_mode",
            message: "pid=42"
        ))

        let mode = try await service.getPlayMode(pid: 42)

        #expect(mode.repeat == .off)
        #expect(mode.shuffle == .off)
        await connection.disconnect()
    }

    // MARK: - getNowPlayingMedia

    @Test func getNowPlayingReturnsMedia() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_now_playing_media",
            message: "pid=42",
            payload: """
            {"type":"song","song":"Test Song","album":"Test Album","artist":"Test Artist","image_url":"http://img.jpg","mid":"m1","qid":"1","sid":"5","album_id":"a1"}
            """
        ))

        let (media, options) = try await service.getNowPlayingMedia(pid: 42)

        #expect(media.song == "Test Song")
        #expect(media.artist == "Test Artist")
        #expect(media.album == "Test Album")
        #expect(options.isEmpty)
        await connection.disconnect()
    }

    // MARK: - getQueue

    @Test func getQueueReturnsItems() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "player/get_queue",
            message: "pid=42",
            payload: """
            [{"song":"Song A","album":"Album A","artist":"Artist A","image_url":"","mid":"m1","qid":1,"album_id":""},{"song":"Song B","album":"","artist":"","image_url":"","mid":"m2","qid":2,"album_id":""}]
            """
        ))

        let items = try await service.getQueue(pid: 42)

        #expect(items.count == 2)
        #expect(items[0].song == "Song A")
        #expect(items[0].qid == 1)
        #expect(items[1].qid == 2)
        await connection.disconnect()
    }

    // MARK: - Command Forwarding

    @Test func playNextSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "player/play_next", message: "pid=42"))

        try await service.playNext(pid: 42)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("play_next") == true)
        await connection.disconnect()
    }

    @Test func playPreviousSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "player/play_previous", message: "pid=42"))

        try await service.playPrevious(pid: 42)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("play_previous") == true)
        await connection.disconnect()
    }

    @Test func clearQueueSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "player/clear_queue", message: "pid=42"))

        try await service.clearQueue(pid: 42)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("clear_queue") == true)
        await connection.disconnect()
    }

    @Test func toggleMuteSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "player/toggle_mute", message: "pid=42"))

        try await service.toggleMute(pid: 42)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("toggle_mute") == true)
        await connection.disconnect()
    }
}
