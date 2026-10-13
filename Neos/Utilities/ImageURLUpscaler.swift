import Foundation

enum ImageURLUpscaler {
    /// Tidal publishes its artwork at these sizes only.
    private static let tidalSizes = [160, 320, 640, 750, 1080, 1280]

    /// The service's variant with at least `pixels` per side and never smaller than the URL's own, or `nil` if the service is unrecognized.
    static func highResURL(from urlString: String, pixels: Int = 1280) -> String? {
        guard !urlString.isEmpty else { return nil }

        let url = upgradeToHTTPS(urlString)
        let wanted = max(pixels, sizeInURL(url))
        let tidal = tidalSizes.first { $0 >= wanted } ?? 1280
        let deezer = min(wanted, 1000)

        // Tidal: resources.tidal.com/images/{id}/160x160.jpg → 320x320.jpg
        if url.contains("resources.tidal.com") || url.contains("resources.wimpmusic.com") {
            return url.replacingOccurrences(
                of: #"/\d+x\d+\."#,
                with: "/\(tidal)x\(tidal).",
                options: .regularExpression
            )
        }

        // Tidal (legacy): images.osl.wimpmusic.com/im/im?w=160&h=160&... → w=320&h=320
        if url.contains("wimpmusic.com") || url.contains("tidal.com") {
            let upgraded = url
                .replacingOccurrences(of: #"[?&]w=\d+"#, with: "?w=\(tidal)", options: .regularExpression)
                .replacingOccurrences(of: #"[?&]h=\d+"#, with: "&h=\(tidal)", options: .regularExpression)
            if upgraded != url { return upgraded }
        }

        // Deezer: cdns-images.dzcdn.net/images/.../NxN-... → 1000x1000-...
        //         cdns-images.dzcdn.net/images/.../NxN.jpg → 1000x1000.jpg
        if url.contains("dzcdn.net") {
            let upgraded = url.replacingOccurrences(
                of: #"/\d+x\d+([-.])"#,
                with: "/\(deezer)x\(deezer)$1",
                options: .regularExpression
            )
            if upgraded != url { return upgraded }
        }

        // SoundCloud: i1.sndcdn.com/artworks-...-t200x200.jpg → t300x300 or t500x500
        if url.contains("sndcdn.com") {
            let upgraded = url.replacingOccurrences(
                of: #"-t\d+x\d+\."#,
                with: wanted <= 300 ? "-t300x300." : "-t500x500.",
                options: .regularExpression
            )
            if upgraded != url { return upgraded }
        }

        return nil
    }

    /// Same URL over https, unless it points at the local network where plaintext is expected.
    static func httpsURL(_ urlString: String) -> String {
        upgradeToHTTPS(urlString)
    }

    // MARK: - Private

    private static func sizeInURL(_ url: String) -> Int {
        guard let match = url.firstMatch(of: #/\/(\d+)x\d+[-.]|-t(\d+)x\d+\.|[?&]w=(\d+)/#),
              let digits = match.1 ?? match.2 ?? match.3 else { return 0 }
        return Int(digits) ?? 0
    }

    private static func upgradeToHTTPS(_ urlString: String) -> String {
        if urlString.hasPrefix("http://") && !isPrivateNetworkURL(urlString) {
            return "https://" + urlString.dropFirst(7)
        }
        return urlString
    }

    private static func isPrivateNetworkURL(_ urlString: String) -> Bool {
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
}
