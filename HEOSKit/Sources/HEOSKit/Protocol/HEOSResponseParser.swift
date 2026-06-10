import Foundation
import NeosDomain

public struct HEOSResponseParser: Sendable {
    private let messageParser = HEOSMessageParser()

    public init() {}

    /// Parses a raw JSON string into a HEOSResponse or HEOSEvent
    public func parse(_ data: Data) throws -> ParsedMessage {
        guard let jsonAny = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HEOSParseError.invalidJSON
        }

        let json = JSONValue.from(jsonAny)

        guard let heosObj = json["heos"]?.asObject else {
            throw HEOSParseError.missingHEOSBlock
        }

        guard let command = heosObj["command"]?.asString else {
            throw HEOSParseError.missingCommand
        }

        let messageString = heosObj["message"]?.asString ?? ""
        let parsedMessage = messageParser.parse(messageString)

        if command.hasPrefix("event/") {
            return .event(HEOSEvent(command: command, message: parsedMessage))
        }

        guard let resultString = heosObj["result"]?.asString,
              let result = HEOSResult(rawValue: resultString) else {
            throw HEOSParseError.missingResult
        }

        if result == .fail {
            let errorID = Int(parsedMessage["eid"] ?? "0") ?? 0
            let errorText = parsedMessage["text"] ?? "Unknown error"
            throw HEOSError(errorID: errorID, text: errorText, command: command, message: parsedMessage)
        }

        let payload = json["payload"] ?? .null

        return .response(HEOSResponse(
            command: command,
            result: result,
            message: parsedMessage,
            payload: payload,
            rawJSON: json
        ))
    }

    // MARK: - Payload Parsers

    private func isPrivateNetworkURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString), let host = url.host else { return false }
        if host.hasSuffix(".local") { return true }
        if host.hasPrefix("10.") { return true }
        if host.hasPrefix("192.168.") { return true }
        if host.hasPrefix("172.") {
            let parts = host.split(separator: ".")
            if parts.count >= 2, let second = Int(parts[1]), (16...31).contains(second) { return true }
        }
        return false
    }

    private func upgradeToHTTPS(_ urlString: String) -> String {
        if urlString.hasPrefix("http://") && !isPrivateNetworkURL(urlString) {
            return "https://" + urlString.dropFirst(7)
        }
        return urlString
    }

    /// Decodes HEOS CLI percent-encoded text in JSON payload fields.
    /// HEOS encodes `&` → `%26`, `=` → `%3D`, `%` → `%25` in text values.
    /// `%25` must be decoded last to prevent double-decode (e.g. `%2526` → `%26`, not `&`).
    private func decodeHEOSText(_ value: String) -> String {
        value
            .replacingOccurrences(of: "%26", with: "&")
            .replacingOccurrences(of: "%3D", with: "=")
            .replacingOccurrences(of: "%25", with: "%")
    }

    public func parsePlayers(_ response: HEOSResponse) -> [Player] {
        response.payloadArray.compactMap { dict in
            guard let pid = dict["pid"]?.asInt,
                  let name = dict["name"]?.asString else { return nil }

            return Player(
                pid: pid,
                name: decodeHEOSText(name),
                model: dict["model"]?.asString ?? "",
                version: dict["version"]?.asString ?? "",
                ip: dict["ip"]?.asString ?? "",
                network: NetworkType(rawValue: dict["network"]?.asString ?? "wifi") ?? .unknown,
                lineout: dict["lineout"]?.asInt ?? 0,
                serial: dict["serial"]?.asString ?? "",
                gid: dict["gid"]?.asInt,
                control: dict["control"]?.asInt
            )
        }
    }

    public func parseGroups(_ response: HEOSResponse) -> [SpeakerGroup] {
        response.payloadArray.compactMap { dict in
            guard let gid = dict["gid"]?.asInt,
                  let name = dict["name"]?.asString,
                  let playersArray = dict["players"]?.asObjectArray else { return nil }

            let players = playersArray.compactMap { pDict -> GroupPlayer? in
                guard let pName = pDict["name"]?.asString,
                      let pid = pDict["pid"]?.asInt,
                      let roleStr = pDict["role"]?.asString,
                      let role = PlayerRole(rawValue: roleStr) else { return nil }
                return GroupPlayer(name: decodeHEOSText(pName), pid: pid, role: role)
            }

            return SpeakerGroup(gid: gid, name: decodeHEOSText(name), players: players)
        }
    }

    public func parseNowPlayingMedia(_ response: HEOSResponse) -> NowPlayingMedia {
        let dict = response.payloadDict
        return NowPlayingMedia(
            type: MediaType(rawValue: dict["type"]?.asString ?? "song") ?? .song,
            song: decodeHEOSText(dict["song"]?.asString ?? ""),
            album: decodeHEOSText(dict["album"]?.asString ?? ""),
            artist: decodeHEOSText(dict["artist"]?.asString ?? ""),
            imageURL: upgradeToHTTPS(dict["image_url"]?.asString ?? ""),
            albumID: dict["album_id"]?.asString ?? "",
            mid: dict["mid"]?.asString ?? "",
            qid: dict["qid"]?.asInt,
            sid: dict["sid"]?.asInt,
            station: dict["station"]?.asString.map(decodeHEOSText)
        )
    }

    public func parseQueueItems(_ response: HEOSResponse) -> [QueueItem] {
        response.payloadArray.compactMap { dict in
            guard let qid = dict["qid"]?.asInt else { return nil }
            return QueueItem(
                qid: qid,
                song: decodeHEOSText(dict["song"]?.asString ?? ""),
                album: decodeHEOSText(dict["album"]?.asString ?? ""),
                artist: decodeHEOSText(dict["artist"]?.asString ?? ""),
                imageURL: upgradeToHTTPS(dict["image_url"]?.asString ?? ""),
                mid: dict["mid"]?.asString ?? "",
                albumID: dict["album_id"]?.asString ?? ""
            )
        }
    }

    public func parseMusicSources(_ response: HEOSResponse) -> [MusicSource] {
        response.payloadArray.compactMap { dict in
            guard let sid = dict["sid"]?.asInt,
                  let name = dict["name"]?.asString else { return nil }
            return MusicSource(
                sid: sid,
                name: decodeHEOSText(name),
                imageURL: upgradeToHTTPS(dict["image_url"]?.asString ?? ""),
                type: dict["type"]?.asString ?? "",
                available: (dict["available"]?.asString ?? "true") == "true",
                serviceUsername: dict["service_username"]?.asString.map(decodeHEOSText)
            )
        }
    }

    public func parseSearchCriteria(_ response: HEOSResponse) -> [SearchCriteria] {
        response.payloadArray.compactMap { dict in
            guard let scid = dict["scid"]?.asInt,
                  let name = dict["name"]?.asString else { return nil }
            return SearchCriteria(scid: scid, name: decodeHEOSText(name))
        }
    }

    public func parseBrowseResult(_ response: HEOSResponse) -> BrowseResult {
        let items = parseBrowseItems(response)
        let returned = response.message["returned"].flatMap(Int.init)
        let count = response.message["count"].flatMap(Int.init)
        let options = parseServiceOptions(response.rawJSON["options"] ?? .null)
        if items.isEmpty {
            HEOSLogger.service.debug("Browse returned 0 items; message: \(response.message) payload: \(String(describing: response.payload))")
        }
        return BrowseResult(items: items, returned: returned, count: count, options: options)
    }

    public func parseNowPlayingMediaWithOptions(_ response: HEOSResponse) -> (media: NowPlayingMedia, options: [ServiceOption]) {
        let media = parseNowPlayingMedia(response)
        let options = parseServiceOptions(response.rawJSON["options"] ?? .null)
        return (media, options)
    }

    public func parseServiceOptions(_ json: JSONValue) -> [ServiceOption] {
        guard case .array(let items) = json else { return [] }
        var result: [ServiceOption] = []
        for item in items {
            guard case .object(let dict) = item else { continue }
            for (contextKey, value) in dict {
                guard let context = ServiceOption.Context(rawValue: contextKey),
                      case .array(let options) = value else { continue }
                for opt in options {
                    guard case .object(let optDict) = opt,
                          let id = optDict["id"]?.asInt,
                          case .string(let name) = optDict["name"] else { continue }
                    result.append(ServiceOption(context: context, id: id, name: name))
                }
            }
        }
        return result
    }

    public func parseBrowseItems(_ response: HEOSResponse) -> [BrowseItem] {
        response.payloadArray.compactMap { dict in
            guard let name = dict["name"]?.asString else { return nil }
            let playable = dict["playable"]?.asString == "yes"
            let browsable = dict["container"]?.asString == "yes"
            return BrowseItem(
                name: decodeHEOSText(name),
                imageURL: upgradeToHTTPS(dict["image_url"]?.asString ?? ""),
                type: MediaType(rawValue: dict["type"]?.asString ?? "song") ?? .song,
                cid: dict["cid"]?.asString,
                mid: dict["mid"]?.asString,
                sid: dict["sid"]?.asInt,
                playable: playable,
                browsable: browsable,
                artist: dict["artist"]?.asString.map(decodeHEOSText),
                album: dict["album"]?.asString.map(decodeHEOSText)
            )
        }
    }
}

public enum ParsedMessage: Sendable {
    case response(HEOSResponse)
    case event(HEOSEvent)
}

public enum HEOSParseError: Error, Sendable {
    case invalidJSON
    case missingHEOSBlock
    case missingCommand
    case missingResult
}
