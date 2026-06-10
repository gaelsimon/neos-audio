import Foundation

/// Shared `URLSession` with strict per-request and per-resource timeouts.
/// Used for artwork downloads and short-lived UPnP fetches so a hostile or
/// slow host on the LAN cannot stall callers for the default 60 seconds.
enum NeosURLSession {
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()
}
