import Foundation
import NeosDomain

extension String {
    /// Some sources name an item after its stream URL; show the segment that identifies the stream.
    var displayTitle: String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        let scheme = trimmed.lowercased()
        guard scheme.hasPrefix("http://") || scheme.hasPrefix("https://"),
              let url = URL(string: trimmed) else {
            return self
        }
        // The last path segment is what tells two streams on the same host apart.
        if let segment = url.pathComponents.last(where: { $0 != "/" && !$0.isEmpty }) {
            return segment
        }
        guard let host = url.host, !host.isEmpty else { return self }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }
}

extension BrowseItem {
    var displayTitle: String { name.displayTitle }
}
