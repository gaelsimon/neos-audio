import Foundation
import NeosDomain

public typealias UPnPError = NeosDomain.UPnPError
public typealias PositionInfo = NeosDomain.PositionInfo
public typealias UPnPTimeFormat = NeosDomain.UPnPTimeFormat

// MARK: - SOAP XML Helpers

enum SOAPEnvelope {
    static let avTransportServiceType = "urn:schemas-upnp-org:service:AVTransport:1"

    /// Build a complete SOAP envelope for a UPnP action.
    static func request(
        action: String,
        serviceType: String = avTransportServiceType,
        includeInstanceID: Bool = true,
        arguments: [(String, String)] = []
    ) -> Data {
        var body = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" \
        s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
        <s:Body>
        <u:\(action) xmlns:u="\(serviceType)">
        """
        if includeInstanceID {
            body += "\n<InstanceID>0</InstanceID>"
        }
        for (name, value) in arguments {
            body += "\n<\(name)>\(xmlEscape(value))</\(name)>"
        }
        body += """

        </u:\(action)>
        </s:Body>
        </s:Envelope>
        """
        return Data(body.utf8)
    }

    /// SOAPACTION header value for a given action name.
    static func soapAction(_ action: String, serviceType: String = avTransportServiceType) -> String {
        "\"\(serviceType)#\(action)\""
    }

    /// Escape XML special characters in an argument value.
    /// `&` must be replaced first so subsequent replacements don't double-escape it.
    static func xmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    /// Extract a simple `<tag>value</tag>` from XML. Matches first occurrence.
    static func extractTag(_ tag: String, from xml: String) -> String? {
        let open = "<\(tag)>"
        let close = "</\(tag)>"
        guard let openRange = xml.range(of: open),
              let closeRange = xml.range(of: close, range: openRange.upperBound..<xml.endIndex) else {
            return nil
        }
        let value = String(xml[openRange.upperBound..<closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    /// Unescape XML entities (`&lt;` → `<`, etc.) commonly found in SOAP-embedded content.
    /// Important: `&amp;` must be replaced last to avoid double-unescaping
    /// (e.g. `&amp;lt;` should become `&lt;`, not `<`).
    static func unescapeXMLEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    /// Parse a SOAP fault response, throwing `UPnPError.soapFault` if found.
    static func parseFault(from xml: String) -> UPnPError? {
        guard xml.contains("<s:Fault>") || xml.contains("<S:Fault>") else { return nil }
        let code = extractTag("errorCode", from: xml).flatMap(Int.init) ?? 0
        let description = extractTag("errorDescription", from: xml) ?? "Unknown error"
        return .soapFault(code: code, description: description)
    }

    /// POST a SOAP action and return the response XML, throwing on fault or HTTP error.
    static func send(
        action: String,
        arguments: [(String, String)] = [],
        controlURL: URL,
        serviceType: String,
        includeInstanceID: Bool = false,
        session: URLSession
    ) async throws -> String {
        var req = URLRequest(url: controlURL)
        req.httpMethod = "POST"
        req.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        req.setValue(soapAction(action, serviceType: serviceType), forHTTPHeaderField: "SOAPACTION")
        req.httpBody = request(action: action, serviceType: serviceType,
                               includeInstanceID: includeInstanceID, arguments: arguments)

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw UPnPError.invalidResponse }
        let xml = String(decoding: data, as: UTF8.self)

        if http.statusCode == 500 {
            if let fault = parseFault(from: xml) { throw fault }
            throw UPnPError.httpError(statusCode: 500)
        }
        guard (200...299).contains(http.statusCode) else {
            throw UPnPError.httpError(statusCode: http.statusCode)
        }
        return xml
    }
}
