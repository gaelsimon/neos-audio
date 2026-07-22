import Foundation
import os

private let followerCacheLogger = Logger(subsystem: "com.galela.neos", category: "cache")

/// Persists serials of known stereo/surround followers to hide them from pre-connect discovery.
enum FollowerCache {
    private static let key = "knownFollowerSerials"

    static func save(_ serials: Set<String>) {
        do {
            let data = try JSONEncoder().encode(serials)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            followerCacheLogger.warning("Failed to encode follower cache: \(error.localizedDescription)")
        }
    }

    static func load() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            return try JSONDecoder().decode(Set<String>.self, from: data)
        } catch {
            followerCacheLogger.warning("Failed to decode follower cache: \(error.localizedDescription)")
            return []
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
