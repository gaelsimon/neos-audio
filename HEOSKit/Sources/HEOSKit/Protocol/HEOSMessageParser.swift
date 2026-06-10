import Foundation

public struct HEOSMessageParser: Sendable {
    public init() {}

    /// Parses a HEOS message string like "pid=123&state=play&level=50"
    public func parse(_ message: String) -> [String: String] {
        guard !message.isEmpty else { return [:] }

        var result: [String: String] = [:]
        let pairs = message.split(separator: "&", omittingEmptySubsequences: true)

        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = decode(String(parts[0]))
                let value = decode(String(parts[1]))
                result[key] = value
            } else if parts.count == 1 {
                result[String(parts[0])] = ""
            }
        }

        return result
    }

    /// Decodes HEOS URL-encoded characters
    private func decode(_ value: String) -> String {
        value
            .replacingOccurrences(of: "%2B", with: "+")
            .replacingOccurrences(of: "%20", with: " ")
            .replacingOccurrences(of: "%23", with: "#")
            .replacingOccurrences(of: "%3F", with: "?")
            .replacingOccurrences(of: "%3A", with: ":")
            .replacingOccurrences(of: "%2F", with: "/")
            .replacingOccurrences(of: "%26", with: "&")
            .replacingOccurrences(of: "%3D", with: "=")
            .replacingOccurrences(of: "%25", with: "%")
    }
}
