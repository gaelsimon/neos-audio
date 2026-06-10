import Foundation
import os

/// UPnP ACT (Denon-specific) client for querying device settings like volume limits.
///
/// The ACT service (`urn:schemas-denon-com:service:ACT:1`) exposes Denon/Marantz-specific
/// controls that aren't available through HEOS CLI or standard UPnP services.
/// Control endpoint: `/ACT/control` on port 60006.
public actor UPnPACTClient {
    private let session: URLSession
    private let baseURL: URL
    private static let controlPath = "/ACT/control"
    private static let serviceType = "urn:schemas-denon-com:service:ACT:1"

    public init(host: String, port: Int = 60006) throws {
        guard let url = URL(string: "http://\(host):\(port)") else {
            throw UPnPError.invalidResponse
        }
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: config)
        self.baseURL = url
    }

    /// Test-only init that accepts a custom session configuration (e.g. for URLProtocol mocking).
    init(host: String, port: Int = 60006, sessionConfiguration: URLSessionConfiguration) throws {
        guard let url = URL(string: "http://\(host):\(port)") else {
            throw UPnPError.invalidResponse
        }
        self.session = URLSession(configuration: sessionConfiguration)
        self.baseURL = url
    }

    public func invalidateSession() {
        session.invalidateAndCancel()
    }

    // MARK: - Public API

    /// Query the configured volume limit (0–100 on the HEOS scale).
    public func getVolumeLimit() async throws -> Int {
        let xml = try await sendAction("GetVolumeLimit")

        guard let valueStr = SOAPEnvelope.extractTag("VolumeLimit", from: xml),
              let limit = Int(valueStr) else {
            throw UPnPError.invalidResponse
        }

        return min(limit, 100)
    }

    // MARK: - Private

    @discardableResult
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

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UPnPError.invalidResponse
        }

        let xml = String(decoding: data, as: UTF8.self)

        if httpResponse.statusCode == 500 {
            if let fault = SOAPEnvelope.parseFault(from: xml) {
                throw fault
            }
            throw UPnPError.httpError(statusCode: 500)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw UPnPError.httpError(statusCode: httpResponse.statusCode)
        }

        return xml
    }
}
