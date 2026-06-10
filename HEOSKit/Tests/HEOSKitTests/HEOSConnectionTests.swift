import Testing
import Foundation
@testable import HEOSKit

@Suite("HEOSConnection Tests")
struct HEOSConnectionTests {

    private func makeResponse(command: String, message: String = "") -> String {
        """
        {"heos":{"command":"\(command)","result":"success","message":"\(message)"}}
        """
    }

    private func makeErrorResponse(command: String, eid: Int, text: String) -> String {
        """
        {"heos":{"command":"\(command)","result":"fail","message":"eid=\(eid)&text=\(text)"}}
        """
    }

    /// Helper: connect and wait for the receive loop to be ready.
    private func connectAndWait(_ connection: HEOSConnection, transport: MockTCPTransport) async throws {
        try await connection.connect(host: "test", port: 1255)
        // Give the receive loop time to set up the stream continuation
        try await Task.sleep(for: .milliseconds(50))
    }

    // MARK: - Command Timeout

    @Test func commandTimesOutAfterDuration() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connectAndWait(connection, transport: transport)

        await #expect(throws: TransportError.self) {
            try await connection.send(.getPlayers, timeout: .milliseconds(100))
        }

        await connection.disconnect()
    }

    // MARK: - Duplicate Command FIFO Resolution

    @Test func duplicateCommandKeysResolvedFIFO() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connectAndWait(connection, transport: transport)

        // Launch two browse commands concurrently; both have key "browse/browse"
        async let first = connection.send(.browseSource(sid: 1), timeout: .seconds(5))
        try await Task.sleep(for: .milliseconds(30))
        async let second = connection.send(.browseSource(sid: 2), timeout: .seconds(5))
        try await Task.sleep(for: .milliseconds(30))

        // Deliver first response; should match the first command (FIFO)
        await transport.simulateEvent(makeResponse(command: "browse/browse", message: "sid=1"))
        try await Task.sleep(for: .milliseconds(50))

        // Deliver second response
        await transport.simulateEvent(makeResponse(command: "browse/browse", message: "sid=2"))

        let r1 = try await first
        let r2 = try await second

        #expect(r1.message["sid"] == "1")
        #expect(r2.message["sid"] == "2")

        await connection.disconnect()
    }

    // MARK: - Disconnect Resumes Pending

    @Test func disconnectResumesPendingWithError() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connectAndWait(connection, transport: transport)

        let task = Task {
            try await connection.send(.getPlayers, timeout: .seconds(30))
        }
        try await Task.sleep(for: .milliseconds(50))

        await connection.disconnect()

        await #expect(throws: TransportError.self) {
            try await task.value
        }
    }

    // MARK: - Basic Send/Receive

    @Test func sendAndReceiveResponse() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connectAndWait(connection, transport: transport)

        let task = Task {
            try await connection.send(.getPlayers)
        }
        try await Task.sleep(for: .milliseconds(30))

        await transport.simulateEvent(makeResponse(command: "player/get_players"))

        let response = try await task.value
        #expect(response.command == "player/get_players")
        #expect(response.isSuccess)

        await connection.disconnect()
    }

    // MARK: - Error Response

    @Test func errorResponseResumesWithHEOSError() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connectAndWait(connection, transport: transport)

        let task = Task {
            try await connection.send(.signIn(username: "test", password: "wrong"))
        }
        try await Task.sleep(for: .milliseconds(30))

        await transport.simulateEvent(
            makeErrorResponse(command: "system/sign_in", eid: 10, text: "Invalid credentials")
        )

        await #expect(throws: HEOSError.self) {
            try await task.value
        }

        await connection.disconnect()
    }

    // MARK: - Command Under Process

    @Test func commandUnderProcessWaitsForRealResponse() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connectAndWait(connection, transport: transport)

        let task = Task {
            try await connection.send(.browseSource(sid: 1028), timeout: .seconds(5))
        }
        try await Task.sleep(for: .milliseconds(30))

        // Simulate the intermediate "command under process" response (no payload)
        await transport.simulateEvent("""
        {"heos":{"command":"browse/browse","result":"success","message":"command under process"}}
        """)
        try await Task.sleep(for: .milliseconds(50))

        // Simulate the real response with payload
        await transport.simulateEvent("""
        {"heos":{"command":"browse/browse","result":"success","message":"sid=1028&returned=2&count=2"},"payload":[{"name":"Station 1","type":"station","playable":"yes","container":"no"},{"name":"Station 2","type":"station","playable":"yes","container":"no"}]}
        """)

        let response = try await task.value
        #expect(response.command == "browse/browse")
        #expect(response.message["returned"] == "2")
        #expect(response.payloadArray.count == 2)
        #expect(!response.isUnderProcess)

        await connection.disconnect()
    }

    // MARK: - CID-Based Matching

    @Test func concurrentRootAndContainerBrowseSameSID() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connectAndWait(connection, transport: transport)

        // Home probes a container while BrowseVM fetches the source root; same SID
        async let container = connection.send(.browseSourceContainer(sid: 10, cid: "NEW_MUSIC", range: 0...4), timeout: .seconds(5))
        try await Task.sleep(for: .milliseconds(30))
        async let root = connection.send(.browseSource(sid: 10), timeout: .seconds(5))
        try await Task.sleep(for: .milliseconds(30))

        // Root response arrives FIRST (out of order; device processed it faster)
        await transport.simulateEvent(makeResponse(command: "browse/browse", message: "sid=10&returned=5&count=5"))
        try await Task.sleep(for: .milliseconds(50))

        // Container response arrives second
        await transport.simulateEvent(makeResponse(command: "browse/browse", message: "sid=10&cid=NEW_MUSIC&returned=4&count=20"))

        let rootResult = try await root
        let containerResult = try await container

        // Root response (no cid) must go to the root command
        #expect(rootResult.message["cid"] == nil)
        #expect(rootResult.message["returned"] == "5")

        // Container response (with cid) must go to the container command
        #expect(containerResult.message["cid"] == "NEW_MUSIC")
        #expect(containerResult.message["returned"] == "4")

        await connection.disconnect()
    }

    // MARK: - Events

    @Test func eventsAreDeliveredToStream() async throws {
        let transport = MockTCPTransport(autoRespond: false)
        let connection = HEOSConnection(transport: transport)
        try await connectAndWait(connection, transport: transport)

        let eventStream = await connection.makeEventStream()

        await transport.simulateEvent("""
        {"heos":{"command":"event/player_state_changed","message":"pid=123&state=play"}}
        """)

        var received: HEOSEvent?
        for await event in eventStream {
            received = event
            break
        }

        #expect(received?.eventName == "player_state_changed")
        #expect(received?.message["state"] == "play")

        await connection.disconnect()
    }
}
