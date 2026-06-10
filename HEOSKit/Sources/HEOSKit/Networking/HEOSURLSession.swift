import Foundation

/// Shared `URLSession` with strict per-request and per-resource timeouts.
/// Used when fetching device description XML during SSDP enrichment so an
/// unresponsive host on the LAN cannot stall discovery for the default 60 seconds.
enum HEOSURLSession {
    static let shared: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 10
        return URLSession(configuration: config)
    }()
}
