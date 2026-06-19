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

    private func sendAction(_ action: String, arguments: [(String, String)] = []) async throws -> String {
        try await SOAPEnvelope.send(
            action: action, arguments: arguments,
            controlURL: baseURL.appendingPathComponent(Self.controlPath),
            serviceType: Self.serviceType, session: session
        )
    }
}
