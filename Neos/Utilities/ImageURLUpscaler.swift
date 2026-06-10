import Foundation

enum ImageURLUpscaler {
    /// Returns a high-resolution variant of a streaming service image URL, or `nil` if the service is unrecognized.
    static func highResURL(from urlString: String) -> String? {
        guard !urlString.isEmpty else { return nil }

        let url = upgradeToHTTPS(urlString)

        // Tidal: resources.tidal.com/images/{id}/160x160.jpg → 1280x1280.jpg
        if url.contains("resources.tidal.com") || url.contains("resources.wimpmusic.com") {
            return url.replacingOccurrences(
                of: #"/\d+x\d+\."#,
                with: "/1280x1280.",
                options: .regularExpression
            )
        }

        // Tidal (legacy): images.osl.wimpmusic.com/im/im?w=160&h=160&... → w=1280&h=1280
        if url.contains("wimpmusic.com") || url.contains("tidal.com") {
            let upgraded = url
                .replacingOccurrences(of: #"[?&]w=\d+"#, with: "?w=1280", options: .regularExpression)
                .replacingOccurrences(of: #"[?&]h=\d+"#, with: "&h=1280", options: .regularExpression)
            if upgraded != url { return upgraded }
        }

        // Deezer: cdns-images.dzcdn.net/images/.../NxN-... → 1000x1000-...
        //         cdns-images.dzcdn.net/images/.../NxN.jpg → 1000x1000.jpg
        if url.contains("dzcdn.net") {
            let upgraded = url.replacingOccurrences(
                of: #"/\d+x\d+([-.])"#,
                with: "/1000x1000$1",
                options: .regularExpression
            )
            if upgraded != url { return upgraded }
        }

        // SoundCloud: i1.sndcdn.com/artworks-...t500x500.jpg → t500x500 is already decent,
        // but some use smaller sizes like t200x200 or t300x300
        if url.contains("sndcdn.com") {
            let upgraded = url.replacingOccurrences(
                of: #"-t\d+x\d+\."#,
                with: "-t500x500.",
                options: .regularExpression
            )
            if upgraded != url { return upgraded }
        }

        return nil
    }

    // MARK: - Private

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
