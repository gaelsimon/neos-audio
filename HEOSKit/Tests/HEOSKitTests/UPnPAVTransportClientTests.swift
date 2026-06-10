import Foundation
import Testing
@testable import HEOSKit

@Suite("UPnPAVTransportClient", .serialized)
struct UPnPAVTransportClientTests {

    private static let path = "/upnp/control/renderer_dvc/AVTransport"

    private func makeClient() throws -> UPnPAVTransportClient {
        try UPnPAVTransportClient(host: "127.0.0.1", port: 60006, sessionConfiguration: MockURLProtocol.makeConfiguration())
    }

    private func soapResponse(action: String, body: String) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
        <u:\(action)Response xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
        \(body)
        </u:\(action)Response>
        </s:Body>
        </s:Envelope>
        """
    }

    private func soapFault(code: Int, description: String) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
        <s:Fault>
        <detail>
        <UPnPError>
        <errorCode>\(code)</errorCode>
        <errorDescription>\(description)</errorDescription>
        </UPnPError>
        </detail>
        </s:Fault>
        </s:Body>
        </s:Envelope>
        """
    }

    // MARK: - seek

    @Test func seekSendsCorrectAction() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.register(pathContaining: Self.path) { request in
            capturedRequest = request
            return (200, soapResponse(action: "Seek", body: ""))
        }
        let client = try makeClient()
        try await client.seek(target: 65) // 1:05

        #expect(capturedRequest?.url?.path.contains(Self.path) == true)
        let soapAction = capturedRequest?.value(forHTTPHeaderField: "SOAPACTION")
        #expect(soapAction?.contains("AVTransport:1#Seek") == true)
        await client.invalidateSession()
    }

    @Test func seekUsesCorrectControlPath() async throws {
        var capturedURL: URL?
        MockURLProtocol.register(pathContaining: Self.path) { request in
            capturedURL = request.url
            return (200, soapResponse(action: "Seek", body: ""))
        }
        let client = try makeClient()
        try await client.seek(target: 0)
        #expect(capturedURL?.path.contains("/upnp/control/renderer_dvc/AVTransport") == true)
        await client.invalidateSession()
    }

    // MARK: - getPositionInfo

    @Test func getPositionInfoReturnsParsedResult() async throws {
        let xml = """
        <Track>3</Track>
        <TrackDuration>0:04:30</TrackDuration>
        <RelTime>0:01:15</RelTime>
        <TrackURI>x-rincon-mp3radio://example.com/stream</TrackURI>
        <TrackMetaData>&lt;DIDL-Lite&gt;metadata&lt;/DIDL-Lite&gt;</TrackMetaData>
        """
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetPositionInfo", body: xml))
        }
        let client = try makeClient()
        let info = try await client.getPositionInfo()

        #expect(info.track == 3)
        #expect(info.trackDuration == "0:04:30")
        #expect(info.relTime == "0:01:15")
        #expect(info.trackURI == "x-rincon-mp3radio://example.com/stream")
        #expect(info.trackMetaData == "&lt;DIDL-Lite&gt;metadata&lt;/DIDL-Lite&gt;")
        await client.invalidateSession()
    }

    @Test func getPositionInfoUsesDefaultsForMissingOptionalTags() async throws {
        let xml = "<Track>1</Track>"
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetPositionInfo", body: xml))
        }
        let client = try makeClient()
        let info = try await client.getPositionInfo()

        #expect(info.track == 1)
        #expect(info.trackDuration == "0:00:00")
        #expect(info.relTime == "0:00:00")
        #expect(info.trackURI == nil)
        #expect(info.trackMetaData == nil)
        await client.invalidateSession()
    }

    @Test func getPositionInfoThrowsWhenTrackMissing() async throws {
        let xml = "<TrackDuration>0:04:30</TrackDuration><RelTime>0:01:15</RelTime>"
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetPositionInfo", body: xml))
        }
        let client = try makeClient()
        await #expect(throws: UPnPError.invalidResponse) {
            try await client.getPositionInfo()
        }
        await client.invalidateSession()
    }

    @Test func getPositionInfoThrowsWhenTrackNotInt() async throws {
        let xml = "<Track>abc</Track>"
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetPositionInfo", body: xml))
        }
        let client = try makeClient()
        await #expect(throws: UPnPError.invalidResponse) {
            try await client.getPositionInfo()
        }
        await client.invalidateSession()
    }

    // MARK: - getCurrentTrackMetaData

    @Test func getCurrentTrackMetaDataExtractsDIDL() async throws {
        let escapedState = "&lt;Event&gt;&lt;CurrentTrackMetaData val=&quot;&amp;lt;DIDL-Lite&amp;gt;track info&amp;lt;/DIDL-Lite&amp;gt;&quot;/&gt;&lt;/Event&gt;"
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetCurrentState", body: "<CurrentState>\(escapedState)</CurrentState>"))
        }
        let client = try makeClient()
        let didl = try await client.getCurrentTrackMetaData()
        #expect(didl == "&lt;DIDL-Lite&gt;track info&lt;/DIDL-Lite&gt;")
        await client.invalidateSession()
    }

    @Test func getCurrentTrackMetaDataReturnsNilWhenCurrentStateMissing() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetCurrentState", body: "<Other>value</Other>"))
        }
        let client = try makeClient()
        let result = try await client.getCurrentTrackMetaData()
        #expect(result == nil)
        await client.invalidateSession()
    }

    @Test func getCurrentTrackMetaDataReturnsNilWhenValAttributeMissing() async throws {
        let escapedState = "&lt;Event&gt;&lt;SomeOtherTag val=&quot;data&quot;/&gt;&lt;/Event&gt;"
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetCurrentState", body: "<CurrentState>\(escapedState)</CurrentState>"))
        }
        let client = try makeClient()
        let result = try await client.getCurrentTrackMetaData()
        #expect(result == nil)
        await client.invalidateSession()
    }

    // MARK: - getTransportActions

    @Test func getTransportActionsReturnsActionSet() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetCurrentTransportActions", body: "<Actions>Play,Pause,Seek,Next</Actions>"))
        }
        let client = try makeClient()
        let actions = try await client.getTransportActions()
        #expect(actions == ["Play", "Pause", "Seek", "Next"])
        await client.invalidateSession()
    }

    @Test func getTransportActionsTrimsWhitespace() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetCurrentTransportActions", body: "<Actions>Play , Pause , Seek</Actions>"))
        }
        let client = try makeClient()
        let actions = try await client.getTransportActions()
        #expect(actions == ["Play", "Pause", "Seek"])
        await client.invalidateSession()
    }

    @Test func getTransportActionsReturnsEmptySetWhenTagMissing() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetCurrentTransportActions", body: "<Other>data</Other>"))
        }
        let client = try makeClient()
        let actions = try await client.getTransportActions()
        #expect(actions.isEmpty)
        await client.invalidateSession()
    }

    // MARK: - Error handling

    @Test func throwsHTTPErrorOnNon2xxNon500() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in (403, "") }
        let client = try makeClient()
        await #expect(throws: UPnPError.httpError(statusCode: 403)) {
            try await client.getPositionInfo()
        }
        await client.invalidateSession()
    }

    @Test func throwsSOAPFaultOn500WithFaultXML() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (500, soapFault(code: 501, description: "Action failed"))
        }
        let client = try makeClient()
        await #expect(throws: UPnPError.soapFault(code: 501, description: "Action failed")) {
            try await client.seek(target: 0)
        }
        await client.invalidateSession()
    }

    @Test func throwsHTTPErrorOn500WithoutFaultXML() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in (500, "not xml") }
        let client = try makeClient()
        await #expect(throws: UPnPError.httpError(statusCode: 500)) {
            try await client.getTransportActions()
        }
        await client.invalidateSession()
    }
}
