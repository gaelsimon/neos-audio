import Foundation
import NeosDomain
import os

private let groupNameLogger = Logger(subsystem: "com.galela.neos", category: "cache")

/// Persists the short names chosen for speaker sets, so a set grouped again keeps its name.
enum GroupNameStore {
    private static let defaultsKey = "groupAliases"

    /// A group is the same set of speakers whichever one leads it.
    static func key(for group: SpeakerGroup) -> String {
        group.players.map(\.pid).sorted().map(String.init).joined(separator: ",")
    }

    static func save(_ aliases: [String: String], in defaults: UserDefaults = .standard) {
        do {
            let data = try JSONEncoder().encode(aliases)
            defaults.set(data, forKey: defaultsKey)
        } catch {
            groupNameLogger.warning("Failed to encode group names: \(error.localizedDescription)")
        }
    }

    static func load(from defaults: UserDefaults = .standard) -> [String: String] {
        guard let data = defaults.data(forKey: defaultsKey) else { return [:] }
        do {
            return try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            groupNameLogger.warning("Failed to decode group names: \(error.localizedDescription)")
            return [:]
        }
    }
}
