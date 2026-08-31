import Foundation
import os

private let followerCacheLogger = Logger(subsystem: "com.galela.neos", category: "cache")

/// Persists serials of known stereo/surround followers to hide them from pre-connect discovery.
enum FollowerCache {
    private static let key = "knownFollowerSerials"
    private static let followerNamesKey = "knownFollowerNames"
    private static let pairNamesKey = "knownPairNames"

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

    /// Follower names, used when a discovery entry carries no serial.
    static func saveFollowerNames(_ names: Set<String>) {
        do {
            let data = try JSONEncoder().encode(names)
            UserDefaults.standard.set(data, forKey: followerNamesKey)
        } catch {
            followerCacheLogger.warning("Failed to encode follower names: \(error.localizedDescription)")
        }
    }

    static func loadFollowerNames() -> Set<String> {
        guard let data = UserDefaults.standard.data(forKey: followerNamesKey) else { return [] }
        do {
            return try JSONDecoder().decode(Set<String>.self, from: data)
        } catch {
            followerCacheLogger.warning("Failed to decode follower names: \(error.localizedDescription)")
            return []
        }
    }

    /// Leader serial and leader name → pair room name, so discovery can name a pair before connecting.
    static func savePairNames(_ names: [String: String]) {
        do {
            let data = try JSONEncoder().encode(names)
            UserDefaults.standard.set(data, forKey: pairNamesKey)
        } catch {
            followerCacheLogger.warning("Failed to encode pair names: \(error.localizedDescription)")
        }
    }

    static func loadPairNames() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: pairNamesKey) else { return [:] }
        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            followerCacheLogger.warning("Failed to decode pair names: \(error.localizedDescription)")
            return [:]
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: followerNamesKey)
        UserDefaults.standard.removeObject(forKey: pairNamesKey)
    }
}
