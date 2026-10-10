import Foundation
import NeosDomain

// Keyed by server name: whether HEOS keeps a server's sid across reboots is unverified.
@Observable
@MainActor
final class LocalServerPreferences {
    private static let hiddenKey = "localServers.hidden"
    private static let unsearchableKey = "localServers.unsearchable"

    private let defaults: UserDefaults
    private(set) var hiddenNames: Set<String>
    private(set) var unsearchableNames: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hiddenNames = Set(defaults.stringArray(forKey: Self.hiddenKey) ?? [])
        unsearchableNames = Set(defaults.stringArray(forKey: Self.unsearchableKey) ?? [])
    }

    var rememberedNames: Set<String> {
        hiddenNames.union(unsearchableNames)
    }

    func isShown(_ name: String) -> Bool {
        !hiddenNames.contains(name)
    }

    // A hidden server keeps its own search setting, so showing it again restores it.
    func isSearchable(_ name: String) -> Bool {
        isShown(name) && !unsearchableNames.contains(name)
    }

    func setShown(_ shown: Bool, for name: String) {
        hiddenNames = updated(hiddenNames, name, present: !shown, key: Self.hiddenKey)
    }

    func setSearchable(_ searchable: Bool, for name: String) {
        unsearchableNames = updated(unsearchableNames, name, present: !searchable, key: Self.unsearchableKey)
    }

    func shows(_ item: BrowseItem) -> Bool {
        !item.isMediaServer || isShown(item.name)
    }

    private func updated(_ names: Set<String>, _ name: String, present: Bool, key: String) -> Set<String> {
        var names = names
        if present { names.insert(name) } else { names.remove(name) }
        defaults.set(names.sorted(), forKey: key)
        return names
    }
}
