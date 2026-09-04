import Foundation

/// Turns a SoundCloud track id into its public permalink, which HEOS never reports.
///
/// SoundCloud's own API needs credentials behind a paid Artist Pro plan, so it is not usable from a
/// distributed app. The embed page below needs no credential: it is the URL every SoundCloud player
/// on the web loads, and it stamps the track's permalink as its canonical address.
actor SoundCloudLinkResolver {
    static let shared = SoundCloudLinkResolver()

    private var cache: [String: URL] = [:]

    /// The permalink for a track id, or nil when the embed page does not answer. Cached for the session.
    func permalink(trackID: String) async -> URL? {
        if let cached = cache[trackID] { return cached }
        guard let resolved = await widgetCanonical(trackID: trackID) else { return nil }
        cache[trackID] = resolved
        return resolved
    }

    // MARK: - Endpoint

    private func widgetCanonical(trackID: String) async -> URL? {
        guard let reference = Self.apiReference(trackID: trackID),
              let url = URL(string: "https://w.soundcloud.com/player/?url=\(reference)"),
              let data = await Self.body(of: url) else { return nil }
        return Self.permalink(fromWidgetHTML: String(decoding: data, as: UTF8.self))
    }

    private static func apiReference(trackID: String) -> String? {
        "https://api.soundcloud.com/tracks/\(trackID)".addingPercentEncoding(withAllowedCharacters: .alphanumerics)
    }

    private static func body(of url: URL) async -> Data? {
        do {
            let (data, response) = try await NeosURLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return data
        } catch {
            return nil
        }
    }

    // MARK: - Parsing

    static func permalink(fromWidgetHTML html: String) -> URL? {
        guard let match = html.range(of: #"<link rel="canonical" href="[^"]+""#, options: .regularExpression) else { return nil }
        return soundCloudURL(html[match].split(separator: "\"").last.map(String.init))
    }

    /// The page hands us an address we are about to open, so it does not get to point elsewhere.
    private static func soundCloudURL(_ value: String?) -> URL? {
        guard let value, value.hasPrefix("https://soundcloud.com/"), let url = URL(string: value) else { return nil }
        return url
    }
}
