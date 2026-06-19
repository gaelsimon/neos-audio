import Foundation

/// Reads a device's audio channel (NORMAL vs LEFT/RIGHT/…) via Denon's GroupControl UPnP
/// service — how we tell a stereo pair from a multi-room group. Endpoint on port 60006.
public actor UPnPGroupControlClient {
    private let session: URLSession
    private let baseURL: URL
    private static let controlPath = "/upnp/control/AiosServicesDvc/GroupControl"
    private static let serviceType = "urn:schemas-denon-com:service:GroupControl:1"

    public init(host: String, port: Int = 60006) throws {
        guard let url = URL(string: "http://\(host):\(port)") else { throw UPnPError.invalidResponse }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: config)
        self.baseURL = url
    }

    /// Test-only init accepting a custom session configuration (e.g. for URLProtocol mocking).
    init(host: String, port: Int = 60006, sessionConfiguration: URLSessionConfiguration) throws {
        guard let url = URL(string: "http://\(host):\(port)") else { throw UPnPError.invalidResponse }
        self.session = URLSession(configuration: sessionConfiguration)
        self.baseURL = url
    }

    public func invalidateSession() {
        session.invalidateAndCancel()
    }

    /// This device's audio channel within its current group (e.g. NORMAL, LEFT, RIGHT).
    public func memberChannel() async throws -> String {
        let uuidXML = try await sendAction("GetGroupUUID")
        guard let uuid = SOAPEnvelope.extractTag("GroupUUID", from: uuidXML), !uuid.isEmpty else {
            throw UPnPError.invalidResponse
        }
        let channelXML = try await sendAction("GetGroupMemberChannel", arguments: [("GroupUUID", uuid)])
        guard let channel = SOAPEnvelope.extractTag("AudioChannel", from: channelXML) else {
            throw UPnPError.invalidResponse
        }
        return channel
    }

    private func sendAction(_ action: String, arguments: [(String, String)] = []) async throws -> String {
        let controlURL = baseURL.appendingPathComponent(Self.controlPath)
        var request = URLRequest(url: controlURL)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue(
            SOAPEnvelope.soapAction(action, serviceType: Self.serviceType),
            forHTTPHeaderField: "SOAPACTION"
        )
        request.httpBody = SOAPEnvelope.request(
            action: action,
            serviceType: Self.serviceType,
            includeInstanceID: false,
            arguments: arguments
        )

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw UPnPError.invalidResponse }
        let xml = String(decoding: data, as: UTF8.self)

        if httpResponse.statusCode == 500 {
            if let fault = SOAPEnvelope.parseFault(from: xml) { throw fault }
            throw UPnPError.httpError(statusCode: 500)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw UPnPError.httpError(statusCode: httpResponse.statusCode)
        }
        return xml
    }
}
