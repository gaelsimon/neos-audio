import Testing
import Foundation
@testable import HEOSKit

@Suite("SystemService Tests")
struct SystemServiceTests {

    // MARK: - Helpers

    private func makeResponse(command: String, message: String = "") -> String {
        """
        {"heos":{"command":"\(command)","result":"success","message":"\(message)"}}
        """
    }

    private func makeSetup() async throws -> (SystemService, MockTCPTransport, HEOSConnection) {
        let transport = MockTCPTransport(autoRespond: true)
        let connection = HEOSConnection(transport: transport)
        try await connection.connect(host: "test", port: 1255)
        try await Task.sleep(for: .milliseconds(50))
        let service = SystemService(connection: connection)
        return (service, transport, connection)
    }

    // MARK: - registerForChangeEvents

    @Test func registerForChangeEventsEnable() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "system/register_for_change_events",
            message: "enable=on"
        ))

        try await service.registerForChangeEvents(enable: true)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("register_for_change_events") == true)
        #expect(sent?.contains("enable=on") == true)
        await connection.disconnect()
    }

    @Test func registerForChangeEventsDisable() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "system/register_for_change_events",
            message: "enable=off"
        ))

        try await service.registerForChangeEvents(enable: false)

        let sent = await transport.lastSentString()
        #expect(sent?.contains("enable=off") == true)
        await connection.disconnect()
    }

    // MARK: - checkAccount

    @Test func checkAccountSignedInReturnsUsername() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "system/check_account",
            message: "signed_in&un=user@test.com"
        ))

        let user = try await service.checkAccount()

        #expect(user == "user@test.com")
        await connection.disconnect()
    }

    @Test func checkAccountSignedOutReturnsNil() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "system/check_account",
            message: "signed_out"
        ))

        let user = try await service.checkAccount()

        #expect(user == nil)
        await connection.disconnect()
    }

    // MARK: - signIn

    @Test func signInSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "system/sign_in",
            message: "signed_in&un=user@test.com"
        ))

        try await service.signIn(username: "user@test.com", password: "secret")

        let sent = await transport.lastSentString()
        #expect(sent?.contains("sign_in") == true)
        #expect(sent?.contains("un=user") == true)
        await connection.disconnect()
    }

    // MARK: - signOut

    @Test func signOutSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(
            command: "system/sign_out",
            message: "signed_out"
        ))

        try await service.signOut()

        let sent = await transport.lastSentString()
        #expect(sent?.contains("sign_out") == true)
        await connection.disconnect()
    }

    // MARK: - heartBeat

    @Test func heartBeatSendsCommand() async throws {
        let (service, transport, connection) = try await makeSetup()
        await transport.enqueueResponse(makeResponse(command: "system/heart_beat"))

        try await service.heartBeat()

        let sent = await transport.lastSentString()
        #expect(sent?.contains("heart_beat") == true)
        await connection.disconnect()
    }

    // MARK: - reboot

    @Test func rebootSendsFireAndForget() async throws {
        let (service, transport, connection) = try await makeSetup()
        // reboot is fire-and-forget, no response needed

        try await service.reboot()

        let sent = await transport.lastSentString()
        #expect(sent?.contains("reboot") == true)
        await connection.disconnect()
    }
}
