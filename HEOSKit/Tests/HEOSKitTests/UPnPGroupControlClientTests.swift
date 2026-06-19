import Foundation
import Testing
@testable import HEOSKit

@Suite("UPnPGroupControlClient", .serialized)
struct UPnPGroupControlClientTests {

    private static let path = "/upnp/control/AiosServicesDvc/GroupControl"

    private func makeClient() throws -> UPnPGroupControlClient {
        try UPnPGroupControlClient(host: "127.0.0.1", port: 60006, sessionConfiguration: MockURLProtocol.makeConfiguration())
    }

    private func response(action: String, body: String) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
        <u:\(action)Response xmlns:u="urn:schemas-denon-com:service:GroupControl:1">
        \(body)
        </u:\(action)Response>
        </s:Body>
        </s:Envelope>
        """
    }

    /// Serves the two-step exchange: GetGroupUUID then GetGroupMemberChannel(channel).
    private func registerExchange(channel: String) {
        MockURLProtocol.register(pathContaining: Self.path) { request in
            let action = request.value(forHTTPHeaderField: "SOAPACTION") ?? ""
            if action.contains("GetGroupMemberChannel") {
                return (200, self.response(action: "GetGroupMemberChannel", body: "<AudioChannel>\(channel)</AudioChannel>"))
            }
            return (200, self.response(action: "GetGroupUUID", body: "<GroupUUID>uuid-123</GroupUUID>"))
        }
    }

    @Test func returnsNormalChannelForMultiRoomMember() async throws {
        registerExchange(channel: "NORMAL")
        let client = try makeClient()
        let channel = try await client.memberChannel()
        #expect(channel == "NORMAL")
        await client.invalidateSession()
    }

    @Test func returnsLeftChannelForStereoPairMember() async throws {
        registerExchange(channel: "LEFT")
        let client = try makeClient()
        let channel = try await client.memberChannel()
        #expect(channel == "LEFT")
        await client.invalidateSession()
    }

    @Test func throwsWhenGroupUUIDMissing() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, self.response(action: "GetGroupUUID", body: "<GroupUUID></GroupUUID>"))
        }
        let client = try makeClient()
        await #expect(throws: (any Error).self) { try await client.memberChannel() }
        await client.invalidateSession()
    }

    @Test func throwsOnSoapFault() async throws {
        let fault = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body><s:Fault><detail><UPnPError>
        <errorCode>501</errorCode><errorDescription>Action Failed</errorDescription>
        </UPnPError></detail></s:Fault></s:Body></s:Envelope>
        """
        MockURLProtocol.register(pathContaining: Self.path) { _ in (500, fault) }
        let client = try makeClient()
        await #expect(throws: (any Error).self) { try await client.memberChannel() }
        await client.invalidateSession()
    }

    @Test func throwsOnHTTPError() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in (404, "") }
        let client = try makeClient()
        await #expect(throws: (any Error).self) { try await client.memberChannel() }
        await client.invalidateSession()
    }

    @Test func productionInitBuildsAndInvalidates() async throws {
        let client = try UPnPGroupControlClient(host: "127.0.0.1")
        await client.invalidateSession()
    }
}
