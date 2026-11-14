/// HEOS calls every folder a container; its name is the only hint of what it holds.
enum FolderSymbol {
    private static let symbols: [(keyword: String, symbol: String)] = [
        ("album", DS.Icons.album),
        ("artist", DS.Icons.person),
        ("playlist", DS.Icons.playlists),
        ("track", DS.Icons.musicNote),
        ("song", DS.Icons.musicNote),
        ("genre", DS.Icons.genre),
        ("radio", DS.Icons.radio),
        ("station", DS.Icons.radio),
        ("podcast", "mic"),
        ("favorite", DS.Icons.heart),
        ("favourite", DS.Icons.heart),
    ]

    /// The symbol for a folder named after what it holds, or nil to keep the plain folder.
    static func name(for folderName: String) -> String? {
        let lowered = folderName.lowercased()
        return symbols.first { lowered.contains($0.keyword) }?.symbol
    }
}
