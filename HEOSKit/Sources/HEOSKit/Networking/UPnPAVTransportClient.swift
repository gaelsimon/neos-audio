import Foundation
import os

/// UPnP AVTransport client for HEOS/Marantz devices.
///
/// Sends SOAP-over-HTTP requests to the device's AVTransport service for operations
/// the HEOS CLI doesn't support (seek, position queries, transport action awareness).
/// Follows the same architectural pattern as `AVRControlClient`; a standalone actor
/// that sits alongside the HEOS CLI connection on a different port.
public actor UPnPAVTransportClient {
    private let session: URLSession
    private let baseURL: URL
    private static let controlPath = "/upnp/control/renderer_dvc/AVTransport"

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

    /// Cancel all in-flight requests and invalidate the underlying URLSession.
    public func invalidateSession() {
        session.invalidateAndCancel()
    }

    // MARK: - Public API

    /// Seek to a position in the current track.
    public func seek(target: TimeInterval) async throws {
        let timeString = UPnPTimeFormat.fromSeconds(target)
        try await sendAction("Seek", arguments: [
            ("Unit", "REL_TIME"),
            ("Target", timeString),
        ])
        HEOSLogger.upnp.debug("Seek to \(timeString)")
    }

    /// Query the current playback position, duration, and track info.
    public func getPositionInfo() async throws -> PositionInfo {
        let xml = try await sendAction("GetPositionInfo")

        guard let trackStr = SOAPEnvelope.extractTag("Track", from: xml),
              let track = Int(trackStr) else {
            throw UPnPError.invalidResponse
        }

        return PositionInfo(
            track: track,
            trackDuration: SOAPEnvelope.extractTag("TrackDuration", from: xml) ?? "0:00:00",
            relTime: SOAPEnvelope.extractTag("RelTime", from: xml) ?? "0:00:00",
            trackURI: SOAPEnvelope.extractTag("TrackURI", from: xml),
            trackMetaData: SOAPEnvelope.extractTag("TrackMetaData", from: xml)
        )
    }

    /// Query the full AVTransport state, returning the `CurrentTrackMetaData` DIDL-Lite XML.
    /// This endpoint returns richer metadata (sampleFrequency, bitsPerSample, audioFormat)
    /// than `GetPositionInfo` on Denon/Marantz devices.
    public func getCurrentTrackMetaData() async throws -> String? {
        let xml = try await sendAction("GetCurrentState")
        guard let stateStr = SOAPEnvelope.extractTag("CurrentState", from: xml) else {
            return nil
        }
        // The CurrentState value is entity-escaped XML. Unescape once to get the Event XML.
        let stateXML = SOAPEnvelope.unescapeXMLEntities(stateStr)

        // Extract the CurrentTrackMetaData val="..." attribute from the Event XML.
        // Format: <CurrentTrackMetaData val="...escaped DIDL-Lite..."/>
        guard let range = stateXML.range(of: "CurrentTrackMetaData val=\""),
              let endRange = stateXML.range(of: "\"/>", range: range.upperBound..<stateXML.endIndex) else {
            return nil
        }
        let escapedDIDL = String(stateXML[range.upperBound..<endRange.lowerBound])
        return escapedDIDL.isEmpty ? nil : escapedDIDL
    }

    /// Query which transport actions are currently available (e.g., Seek, Play, Pause).
    public func getTransportActions() async throws -> Set<String> {
        let xml = try await sendAction("GetCurrentTransportActions")

        guard let actions = SOAPEnvelope.extractTag("Actions", from: xml) else {
            return []
        }

        return Set(actions.split(separator: ",").map {
            $0.trimmingCharacters(in: .whitespaces)
        })
    }

    // MARK: - Private

    /// Send a SOAP action and return the response XML body. Throws on HTTP/SOAP errors.
    @discardableResult
    private func sendAction(_ action: String, arguments: [(String, String)] = []) async throws -> String {
        let controlURL = baseURL.appendingPathComponent(Self.controlPath)
        var request = URLRequest(url: controlURL)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue(SOAPEnvelope.soapAction(action), forHTTPHeaderField: "SOAPACTION")
        request.httpBody = SOAPEnvelope.request(action: action, arguments: arguments)

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
