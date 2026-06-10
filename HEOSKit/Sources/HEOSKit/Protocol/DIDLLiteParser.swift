import Foundation

/// Parses UPnP DIDL-Lite XML (from AVTransport metadata) into `TrackMetadata`.
public enum DIDLLiteParser {

    /// Parse a raw metadata string (potentially XML-entity-escaped) into `TrackMetadata`.
    /// Returns nil if the string is nil, empty, or unparseable.
    public static func parse(_ rawMetadata: String?) -> TrackMetadata? {
        guard let raw = rawMetadata, !raw.isEmpty else { return nil }

        // The SOAP response may return DIDL-Lite with XML entities escaped.
        // Unescape before parsing as XML.
        let xml = unescapeXMLEntities(raw)

        guard let doc = try? XMLDocument(xmlString: xml, options: [.nodeLoadExternalEntitiesNever]) else {
            return nil
        }

        guard let item = try? doc.nodes(forXPath: "//*[local-name()='item']").first else {
            return nil
        }

        // Extract child elements by local name (ignoring namespace prefix)
        let genre = textContent(ofElement: "genre", in: item)
        let trackNumber = textContent(ofElement: "originalTrackNumber", in: item).flatMap(Int.init)
        let albumArtURI = textContent(ofElement: "albumArtURI", in: item)

        // Extract <res> element and its attributes
        let resNode = try? item.nodes(forXPath: "*[local-name()='res']").first as? XMLElement
        let sampleRate = resNode?.attribute(forName: "sampleFrequency")?.stringValue.flatMap(Int.init)
        let bitDepth = resNode?.attribute(forName: "bitsPerSample")?.stringValue.flatMap(Int.init)
        let channels = resNode?.attribute(forName: "nrAudioChannels")?.stringValue.flatMap(Int.init)
        let bitrate = resNode?.attribute(forName: "bitrate")?.stringValue.flatMap(Int.init)

        // Codec: try protocolInfo MIME type first, then Denon-specific audioFormat descriptor
        let protocolInfo = resNode?.attribute(forName: "protocolInfo")?.stringValue
        let codec = protocolInfo.flatMap(Self.codecFromProtocolInfo)
            ?? audioFormatFromDesc(in: item)

        let metadata = TrackMetadata(
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channels: channels,
            bitrate: bitrate,
            codec: codec,
            genre: genre,
            trackNumber: trackNumber,
            albumArtURI: albumArtURI
        )

        // Return nil if every field is nil (nothing useful was parsed)
        if metadata == TrackMetadata() {
            return nil
        }
        return metadata
    }

    // MARK: - Private Helpers

    /// Extract text content of the first child element matching a local name (namespace-agnostic).
    private static func textContent(ofElement localName: String, in node: XMLNode) -> String? {
        guard let element = try? node.nodes(forXPath: "*[local-name()='\(localName)']").first else {
            return nil
        }
        let text = element.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let t = text, !t.isEmpty else { return nil }
        // Filter out Denon's empty placeholder pattern: literal ""
        if t == "\"\"" { return nil }
        return t
    }

    /// Extract a Denon-specific `<desc id="...">` value by its id attribute.
    private static func descValue(id: String, in item: XMLNode) -> String? {
        guard let descs = try? item.nodes(forXPath: "*[local-name()='desc']") else {
            return nil
        }
        for desc in descs {
            guard let element = desc as? XMLElement,
                  element.attribute(forName: "id")?.stringValue == id else {
                continue
            }
            let text = element.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let t = text, !t.isEmpty else { return nil }
            return t
        }
        return nil
    }

    /// Extract the Denon-specific `<desc id="audioFormat">FLAC</desc>` element.
    private static func audioFormatFromDesc(in item: XMLNode) -> String? {
        descValue(id: "audioFormat", in: item)?.uppercased()
    }

    /// Derive a display codec name from the UPnP protocolInfo string.
    /// Format: "transport:*:mime-type:*" e.g. "http-get:*:audio/flac:*"
    static func codecFromProtocolInfo(_ protocolInfo: String) -> String? {
        let parts = protocolInfo.split(separator: ":")
        guard parts.count >= 3 else { return nil }
        let mime = String(parts[2]).trimmingCharacters(in: .whitespaces).lowercased()
        // Wildcard MIME type (e.g. "http-get:*:*:DLNA...") means no codec info
        if mime == "*" { return nil }
        return mimeToCodec[mime]
    }

    private static let mimeToCodec: [String: String] = [
        "audio/flac": "FLAC",
        "audio/x-flac": "FLAC",
        "audio/mp4": "AAC",
        "audio/x-m4a": "AAC",
        "audio/aac": "AAC",
        "audio/aacp": "AAC",
        "audio/mpeg": "MP3",
        "audio/mp3": "MP3",
        "audio/x-wav": "WAV",
        "audio/wav": "WAV",
        "audio/L16": "PCM",
        "audio/ogg": "OGG",
        "audio/x-ms-wma": "WMA",
        "audio/aiff": "AIFF",
        "audio/x-aiff": "AIFF",
        "audio/dsf": "DSD",
        "audio/x-dsd": "DSD",
    ]

    /// Unescape XML entities that may be present in SOAP-embedded DIDL-Lite.
    private static func unescapeXMLEntities(_ string: String) -> String {
        // If it already looks like XML (starts with <), no unescaping needed
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<") {
            return string
        }

        return SOAPEnvelope.unescapeXMLEntities(string)
    }
}
