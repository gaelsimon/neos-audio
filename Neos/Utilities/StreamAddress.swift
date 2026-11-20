import Foundation

/// The readable parts of a stream's address, for a stream nothing else names.
enum StreamAddress {
    static func isAddress(_ text: String) -> Bool {
        text.hasPrefix("http://") || text.hasPrefix("https://")
    }

    /// A speaker reports one station over http on one play and https on the next.
    static func withoutScheme(_ address: String) -> String {
        if address.hasPrefix("https://") { return String(address.dropFirst(8)) }
        if address.hasPrefix("http://") { return String(address.dropFirst(7)) }
        return address
    }

    /// The file's name without its extension, or the host when the address stops there.
    static func title(of address: String) -> String {
        guard let url = URL(string: address) else { return address }
        let file = url.deletingPathExtension().lastPathComponent
        return file.isEmpty || file == "/" ? url.host ?? address : file
    }

    static func host(of address: String) -> String? {
        URL(string: address)?.host
    }
}
