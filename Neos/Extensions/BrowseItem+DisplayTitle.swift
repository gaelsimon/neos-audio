import Foundation
import NeosDomain

extension String {
    /// Some sources name an item after its stream URL; show the bare host instead.
    var displayTitle: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let scheme = trimmed.lowercased()
        guard scheme.hasPrefix("http://") || scheme.hasPrefix("https://"),
              let host = URL(string: trimmed)?.host, !host.isEmpty else {
            return self
        }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

extension BrowseItem {
    var displayTitle: String { name.displayTitle }
}
