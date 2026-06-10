import Testing
import Foundation
@testable import HEOSKit

@Suite("GroupService Tests")
struct GroupServiceTests {

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

    private func makeSetup() async throws -> (GroupService, MockTCPTransport, HEOSConnection) {
        let transport = MockTCPTransport(autoRespond: true)
        let connection = HEOSConnection(transport: transport)
        try await connection.connect(host: "test", port: 1255)
        try await Task.sleep(for: .milliseconds(50))
        let service = GroupService(connection: connection)
        return (service, transport, connection)
    }

    // MARK: - getGroups

    @Test func getGroupsReturnsGroups() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "group/get_groups",
            payload: """
            [{"name":"Living Room + Kitchen","gid":42,"players":[{"name":"Living Room","pid":42,"role":"leader"},{"name":"Kitchen","pid":43,"role":"member"}]}]
            """
        ))

        let groups = try await service.getGroups()

        #expect(groups.count == 1)
        #expect(groups[0].gid == 42)
        #expect(groups[0].players.count == 2)
        await connection.disconnect()
    }

    @Test func getGroupsEmptyReturnsEmpty() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "group/get_groups",
            payload: "[]"
        ))

        let groups = try await service.getGroups()

        #expect(groups.isEmpty)
        await connection.disconnect()
    }

    // MARK: - createGroup

    @Test func createGroupSendsAllPIDs() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "group/set_group",
            message: "gid=42&name=Group&pid=42,43,44"
        ))

        try await service.createGroup(leaderPID: 42, memberPIDs: [43, 44])

        let sent = await transport.lastSentString()
        #expect(sent?.contains("set_group") == true)
        #expect(sent?.contains("pid=42") == true)
        await connection.disconnect()
    }

    // MARK: - ungroup

    @Test func ungroupSendsSinglePID() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "group/set_group",
            message: "pid=42"
        ))

        try await service.ungroup(pid: 42)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("set_group") == true)
        await connection.disconnect()
    }

    // MARK: - getGroupVolume

    @Test func getGroupVolumeReturnsLevel() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "group/get_volume",
            message: "gid=42&level=75"
        ))

        let level = try await service.getGroupVolume(gid: 42)

        #expect(level == 75)
        await connection.disconnect()
    }

    // MARK: - setGroupVolume (clamping)

    @Test func setGroupVolumeSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "group/set_volume", message: "gid=42&level=60"))

        try await service.setGroupVolume(gid: 42, level: 60)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("set_volume") == true)
        #expect(sent?.contains("level=60") == true)
        await connection.disconnect()
    }

    @Test func setGroupVolumeClampsTooHigh() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "group/set_volume", message: "gid=42&level=100"))

        try await service.setGroupVolume(gid: 42, level: 200)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("level=100") == true)
        await connection.disconnect()
    }

    @Test func setGroupVolumeClampsTooLow() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "group/set_volume", message: "gid=42&level=0"))

        try await service.setGroupVolume(gid: 42, level: -5)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("level=0") == true)
        await connection.disconnect()
    }

    // MARK: - getGroupMute

    @Test func getGroupMuteReturnsTrue() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "group/get_mute",
            message: "gid=42&state=on"
        ))

        let muted = try await service.getGroupMute(gid: 42)

        #expect(muted == true)
        await connection.disconnect()
    }

    @Test func getGroupMuteReturnsFalse() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "group/get_mute",
            message: "gid=42&state=off"
        ))

        let muted = try await service.getGroupMute(gid: 42)

        #expect(muted == false)
        await connection.disconnect()
    }

    // MARK: - toggleGroupMute

    @Test func toggleGroupMuteSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "group/toggle_mute", message: "gid=42"))

        try await service.toggleGroupMute(gid: 42)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("toggle_mute") == true)
        await connection.disconnect()
    }
}
