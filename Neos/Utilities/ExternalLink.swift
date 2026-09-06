import Foundation
import NeosDomain

/// Public links to a streaming service, built from the identifiers HEOS already gives us.
enum ExternalLink {

    /// Services whose HEOS identifiers map to a public URL.
    enum Service: String {
        case tidal = "Tidal"
        case deezer = "Deezer"
        case soundCloud = "SoundCloud"
        case tuneIn = "TuneIn"
        case qobuz = "Qobuz"
        case amazonMusic = "Amazon Music"
    }

    /// Where a menu entry points. SoundCloud needs a network round trip first, since HEOS
    /// carries a track id and SoundCloud addresses tracks by permalink.
    enum Target: Equatable {
        case direct(app: URL?, web: URL)
        case soundCloudTrack(id: String, search: URL?)
        case stream(URL)

        /// False for raw stream URLs, which belong in the clipboard rather than a browser.
        var isOpenable: Bool {
            if case .stream = self { return false }
            return true
        }
    }

    /// The identifiers a HEOS item carries, whichever kind of row it came from.
    struct Item {
        var type: MediaType = .song
        var mid: String?
        var cid: String?
        var artist: String?
        var title: String?
        var imageURL: String = ""
    }

    // MARK: - Service Identification

    private static let nameKeywords: [(keyword: String, service: Service)] = [
        ("tidal", .tidal),
        ("deezer", .deezer),
        ("soundcloud", .soundCloud),
        ("tunein", .tuneIn),
        ("qobuz", .qobuz),
        ("amazon", .amazonMusic),
    ]

    /// Artwork hosts, the only clue on rows that carry no source id: queue entries,
    /// favorites and history all mix services under one HEOS source.
    private static let artworkHosts: [(host: String, service: Service)] = [
        ("tidal.com", .tidal),
        ("wimpmusic.com", .tidal),
        ("dzcdn.net", .deezer),
        ("deezer.com", .deezer),
        ("sndcdn.com", .soundCloud),
        ("tunein.com", .tuneIn),
        ("qobuz.com", .qobuz),
        ("images-amazon.com", .amazonMusic),
        ("media-amazon.com", .amazonMusic),
    ]

    /// The service behind an item: its source name when known, else its artwork host.
    static func service(sourceName: String?, imageURL: String) -> Service? {
        if let sourceName {
            let name = sourceName.lowercased()
            if let match = nameKeywords.first(where: { name.contains($0.keyword) }) {
                return match.service
            }
        }
        let artwork = imageURL.lowercased()
        return artworkHosts.first(where: { artwork.contains($0.host) })?.service
    }

    // MARK: - Target

    /// A link for this item, or nil when the service or the identifier is not one we can address.
    static func target(for item: Item, sourceName: String?) -> Target? {
        if let stream = streamURL(item.mid) { return .stream(stream) }

        let serviceTarget: Target? = switch service(sourceName: sourceName, imageURL: item.imageURL) {
        case .tidal: tidalTarget(item)
        case .deezer: deezerTarget(item)
        case .soundCloud: soundCloudTarget(item)
        case .tuneIn: tuneInTarget(item)
        case .qobuz: qobuzTarget(item)
        case .amazonMusic: amazonTarget(item)
        case nil: nil
        }
        if let serviceTarget { return serviceTarget }

        // Some amps name a URL favorite by its stream address instead of storing it as the media id.
        return streamURL(item.title).map { .stream($0) }
    }

    // MARK: - Per-Service Builders

    /// Only the track deep link is confirmed to land on the right page in TIDAL.app,
    /// so albums and playlists go to the web.
    private static func tidalTarget(_ item: Item) -> Target? {
        if item.type == .song, let id = digits(item.mid), let web = url("https://tidal.com/track/\(id)") {
            return .direct(app: URL(string: "tidal://track/\(id)"), web: web)
        }
        if let uuid = uuidLike(suffix(of: item.cid, after: "LIBPLAYLIST-")),
           let web = url("https://tidal.com/playlist/\(uuid)") {
            return .direct(app: nil, web: web)
        }
        if let id = digits(suffix(of: item.cid, after: "LIBALBUM-")), let web = url("https://tidal.com/album/\(id)") {
            return .direct(app: nil, web: web)
        }
        return nil
    }

    /// Deezer album containers arrive as `Albums-<id>`, where the id is the public album id.
    private static func deezerTarget(_ item: Item) -> Target? {
        let path: String? = if let track = digits(item.mid) {
            "track/\(track)"
        } else if let album = digits(suffix(of: item.cid, after: "Albums-")) {
            "album/\(album)"
        } else {
            nil
        }
        guard let path, let web = url("https://www.deezer.com/\(path)") else { return nil }
        return .direct(app: nil, web: web)
    }

    /// Qobuz addresses tracks only in its web player. Album containers are left alone: no
    /// captured `cid` shows what identifies them.
    private static func qobuzTarget(_ item: Item) -> Target? {
        guard let id = digits(item.mid), let web = url("https://open.qobuz.com/track/\(id)") else { return nil }
        return .direct(app: nil, web: web)
    }

    /// TuneIn station ids arrive as `s24939` or `s/24939`; the same source also holds
    /// plain URL streams, which have no TuneIn page.
    private static func tuneInTarget(_ item: Item) -> Target? {
        guard let mid = item.mid else { return nil }
        let station = mid.replacingOccurrences(of: "/", with: "")
        guard station.hasPrefix("s"), digits(String(station.dropFirst())) != nil,
              let web = url("https://tunein.com/radio/\(station)/") else { return nil }
        return .direct(app: nil, web: web)
    }

    private static func soundCloudTarget(_ item: Item) -> Target? {
        guard let id = digits(suffix(of: item.mid, after: "soundcloud:tracks:")) else { return nil }
        return .soundCloudTrack(id: id, search: searchURL(host: "soundcloud.com", item: item))
    }

    /// Amazon embeds an ASIN in its catalog paths, and the URL path has to match the ASIN's
    /// kind. Radio station ids are not ASINs, so those rows get no link.
    private static func amazonTarget(_ item: Item) -> Target? {
        let kind: String? = switch item.type {
        case .song: "tracks"
        case .album: "albums"
        default: nil
        }
        guard let kind,
              let asin = asin(in: item.mid) ?? asin(in: item.cid),
              let web = url("https://music.amazon.com/\(kind)/\(asin)") else { return nil }
        return .direct(app: nil, web: web)
    }

    // MARK: - Identifier Helpers

    /// A favorite pointing straight at a stream carries the URL itself, as its media id on
    /// some amps and as its name on others.
    private static func streamURL(_ value: String?) -> URL? {
        guard let value, value.hasPrefix("http://") || value.hasPrefix("https://") else { return nil }
        return URL(string: value)
    }

    private static func digits(_ value: String?) -> String? {
        guard let value, !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return value
    }

    /// Guards the one identifier that is not a plain number before it lands in a URL path.
    private static func uuidLike(_ value: String?) -> String? {
        guard let value, value.count == 36, value.allSatisfy({ $0.isHexDigit || $0 == "-" }) else { return nil }
        return value
    }

    private static func suffix(of value: String?, after prefix: String) -> String? {
        guard let value, value.hasPrefix(prefix) else { return nil }
        let tail = String(value.dropFirst(prefix.count))
        return tail.isEmpty ? nil : tail
    }

    private static func asin(in value: String?) -> String? {
        guard let value, let range = value.range(of: "B0[A-Z0-9]{8}", options: .regularExpression) else { return nil }
        return String(value[range])
    }

    /// Nil when the item carries no words to search for, which leaves resolution as the only path.
    private static func searchURL(host: String, item: Item) -> URL? {
        let terms = [item.artist, item.title]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !terms.isEmpty,
              let query = terms.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else { return nil }
        return url("https://\(host)/search?q=\(query)")
    }

    private static func url(_ string: String) -> URL? {
        URL(string: string)
    }
}

// MARK: - Menu Entry

/// One service link, named for the menu that shows it.
struct ExternalLinkMenu: Equatable {
    let serviceName: String
    let target: ExternalLink.Target

    /// A stream URL names no service, and only ever offers the clipboard.
    private init?(item: ExternalLink.Item, sourceName: String?) {
        guard let target = ExternalLink.target(for: item, sourceName: sourceName) else { return nil }
        self.target = target
        self.serviceName = ExternalLink.service(sourceName: sourceName, imageURL: item.imageURL)?.rawValue ?? ""
    }

    static func make(for item: BrowseItem, sourceName: String?) -> Self? {
        Self(
            item: ExternalLink.Item(
                type: item.type,
                mid: item.mid,
                cid: item.cid,
                artist: item.artist,
                title: item.name,
                imageURL: item.imageURL
            ),
            sourceName: sourceName
        )
    }

    /// Resolves the source name from the sid the row was loaded under, when there is one.
    static func make(for item: BrowseItem, sid: Int?, sources: [MusicSource]) -> Self? {
        make(for: item, sourceName: sources.first { $0.sid == (item.sid ?? sid) }?.name)
    }

    static func make(for item: QueueItem, sourceName: String?) -> Self? {
        Self(
            item: ExternalLink.Item(
                mid: item.mid,
                artist: item.artist,
                title: item.song,
                imageURL: item.imageURL
            ),
            sourceName: sourceName
        )
    }

    static func make(for media: NowPlayingMedia, sources: [MusicSource]) -> Self? {
        Self(
            item: ExternalLink.Item(
                type: media.type,
                mid: media.mid,
                artist: media.artist,
                title: media.song,
                imageURL: media.imageURL
            ),
            sourceName: sources.first { $0.sid == media.sid }?.name
        )
    }
}
