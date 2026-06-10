import Foundation
import Testing
@testable import HEOSKit

@Suite("UPnPACTClient", .serialized)
struct UPnPACTClientTests {

    private static let path = "/ACT/control"

    private func makeClient() throws -> UPnPACTClient {
        try UPnPACTClient(host: "127.0.0.1", port: 60006, sessionConfiguration: MockURLProtocol.makeConfiguration())
    }

    private func soapResponse(action: String, body: String) -> String {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/">
        <s:Body>
        <u:\(action)Response xmlns:u="urn:schemas-denon-com:service:ACT:1">
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

    // MARK: - getVolumeLimit

    @Test func getVolumeLimitReturnsParsedValue() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetVolumeLimit", body: "<VolumeLimit>80</VolumeLimit>"))
        }
        let client = try makeClient()
        let limit = try await client.getVolumeLimit()
        #expect(limit == 80)
        await client.invalidateSession()
    }

    @Test func getVolumeLimitClampsAbove100() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetVolumeLimit", body: "<VolumeLimit>150</VolumeLimit>"))
        }
        let client = try makeClient()
        let limit = try await client.getVolumeLimit()
        #expect(limit == 100)
        await client.invalidateSession()
    }

    @Test func getVolumeLimitReturns100ForExactly100() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetVolumeLimit", body: "<VolumeLimit>100</VolumeLimit>"))
        }
        let client = try makeClient()
        let limit = try await client.getVolumeLimit()
        #expect(limit == 100)
        await client.invalidateSession()
    }

    @Test func getVolumeLimitThrowsWhenTagMissing() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetVolumeLimit", body: "<Other>42</Other>"))
        }
        let client = try makeClient()
        await #expect(throws: UPnPError.invalidResponse) {
            try await client.getVolumeLimit()
        }
        await client.invalidateSession()
    }

    @Test func getVolumeLimitThrowsWhenValueNotInt() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (200, soapResponse(action: "GetVolumeLimit", body: "<VolumeLimit>abc</VolumeLimit>"))
        }
        let client = try makeClient()
        await #expect(throws: UPnPError.invalidResponse) {
            try await client.getVolumeLimit()
        }
        await client.invalidateSession()
    }

    // MARK: - Error handling

    @Test func throwsHTTPErrorOnNon2xxNon500() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in (403, "") }
        let client = try makeClient()
        await #expect(throws: UPnPError.httpError(statusCode: 403)) {
            try await client.getVolumeLimit()
        }
        await client.invalidateSession()
    }

    @Test func throwsSOAPFaultOn500WithFaultXML() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in
            (500, soapFault(code: 718, description: "Invalid action"))
        }
        let client = try makeClient()
        await #expect(throws: UPnPError.soapFault(code: 718, description: "Invalid action")) {
            try await client.getVolumeLimit()
        }
        await client.invalidateSession()
    }

    @Test func throwsHTTPErrorOn500WithoutFaultXML() async throws {
        MockURLProtocol.register(pathContaining: Self.path) { _ in (500, "<html>Server Error</html>") }
        let client = try makeClient()
        await #expect(throws: UPnPError.httpError(statusCode: 500)) {
            try await client.getVolumeLimit()
        }
        await client.invalidateSession()
    }

    @Test func requestUsesCorrectPathAndHeaders() async throws {
        var capturedRequest: URLRequest?
        MockURLProtocol.register(pathContaining: Self.path) { request in
            capturedRequest = request
            return (200, soapResponse(action: "GetVolumeLimit", body: "<VolumeLimit>50</VolumeLimit>"))
        }
        let client = try makeClient()
        _ = try await client.getVolumeLimit()

        #expect(capturedRequest?.url?.path.contains("/ACT/control") == true)
        #expect(capturedRequest?.httpMethod == "POST")
        let soapAction = capturedRequest?.value(forHTTPHeaderField: "SOAPACTION")
        #expect(soapAction?.contains("ACT:1#GetVolumeLimit") == true)
        await client.invalidateSession()
    }
}
