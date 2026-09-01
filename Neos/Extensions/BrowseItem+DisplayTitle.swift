import Foundation
import NeosDomain

extension String {
    /// Some sources name an item after its stream URL. Showing only the last segment made
    /// two stations with the same file name look like duplicates, so the URL is kept whole.
    var displayTitle: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension BrowseItem {
    var displayTitle: String { name.displayTitle }
}
