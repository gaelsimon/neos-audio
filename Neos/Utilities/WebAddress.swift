import Foundation

extension URL {
    /// An http or https address as it was typed or pasted.
    init?(webAddress text: String) {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        self = url
    }
}
