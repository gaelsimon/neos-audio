import Foundation
import NeosDomain

extension String {
    /// Some sources name an item after its stream URL. Showing only the last segment made
    /// two stations with the same file name look like duplicates, so the URL is kept whole.
    var displayTitle: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    /// "128 kbps mp3", which a speaker sends in place of a name while a stream buffers.
    var isBitrateLabel: Bool {
        range(of: #"^\d+ kbps \w+$"#, options: .regularExpression) != nil
    }
}

extension BrowseItem {
    var displayTitle: String { name.displayTitle }
}
