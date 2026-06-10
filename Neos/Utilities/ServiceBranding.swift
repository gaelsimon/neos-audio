import SwiftUI
import NeosDomain

enum ServiceBranding {

    // MARK: - Icon Assets

    private static let serviceIcons: [String: String] = [
        "amazon": "service-icon-amazon",
        "deezer": "service-icon-deezer",
        "spotify": "service-icon-spotify",
        "tidal": "service-icon-tidal",
        "soundcloud": "service-icon-soundcloud",
        "tunein": "service-icon-tunein",
        "qobuz": "service-icon-qobuz",
    ]

    // MARK: - Local Source SF Symbols

    private static let sfSymbolIcons: [String: String] = [
        // HEOS built-in sources
        "history": DS.Icons.history,
        "favorites": DS.Icons.radio,
        "playlists": DS.Icons.playlists,
        "playlist": DS.Icons.playlists,
        // Network media servers
        "music server": DS.Icons.server,
        "local music": DS.Icons.musicNoteHouse,
        "dlna": DS.Icons.server,
        "media server": DS.Icons.server,
        "nas": DS.Icons.server,
        // Physical inputs
        "aux": DS.Icons.cableConnector,
        "aux input": DS.Icons.cableConnector,
        "aux in": DS.Icons.cableConnector,
        "line in": DS.Icons.cableConnector,
        // CD / Phono / Recorder
        "cd": DS.Icons.opticalDisc,
        "phono": DS.Icons.recordingTape,
        "recorder": DS.Icons.recordingTape,
        // USB
        "usb": DS.Icons.usb,
        // Bluetooth
        "bluetooth": DS.Icons.bluetooth,
        // HDMI / TV
        "hdmi": DS.Icons.tv,
        "tv audio": DS.Icons.tv,
        "tv sound": DS.Icons.tv,
        // Optical / digital
        "optical": DS.Icons.fibreChannel,
        "digital": DS.Icons.fibreChannel,
        "coaxial": DS.Icons.fibreChannel,
        "spdif": DS.Icons.fibreChannel,
        // Radio services
        "radio": DS.Icons.radio,
        "pandora": DS.Icons.radio,
        "iheart": DS.Icons.radio,
        "sirius": DS.Icons.radio,
    ]

    // MARK: - Lookup

    /// Match a source name against a keyword dictionary using substring matching.
    private static func matchKeyword(in dict: [String: String], for sourceName: String) -> String? {
        let name = sourceName.lowercased()
        for (keyword, value) in dict where name.contains(keyword) {
            return value
        }
        return nil
    }

    static func iconAssetName(for sourceName: String) -> String? {
        matchKeyword(in: serviceIcons, for: sourceName)
    }

    /// Sources that should display a service indicator in browse headers:
    /// streaming services (custom icon assets) and music servers (SF Symbols).
    private static let serverKeywords: Set<String> = [
        "music server", "local music", "dlna", "media server", "nas",
    ]

    static func hasBrandIdentity(for sourceName: String) -> Bool {
        let name = sourceName.lowercased()
        if serviceIcons.keys.contains(where: { name.contains($0) }) { return true }
        if serverKeywords.contains(where: { name.contains($0) }) { return true }
        return false
    }

    // MARK: - Shared Label

    @ViewBuilder
    static func serviceLabel(
        for source: MusicSource,
        iconSize: CGFloat = DS.ImageSize.serviceIcon,
        style: DS.Font = .sectionHeader
    ) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            serviceIcon(for: source, size: iconSize)

            Text(source.name)
                .typography(style)
        }
    }

    // MARK: - Icon Only

    @ViewBuilder
    static func serviceIcon(for source: MusicSource, size: CGFloat = DS.ImageSize.serviceIcon) -> some View {
        if let iconAsset = iconAssetName(for: source.name) {
            Image(iconAsset)
                .resizable()
                .renderingMode(.original)
                .aspectRatio(contentMode: .fit)
                .padding(size * 0.15)
                .frame(width: size, height: size)
                .background(.black, in: RoundedRectangle(cornerRadius: DS.Radius.small))
                .iconGlassBorder()
        } else if let sfSymbol = sfSymbolIcon(for: source.name) {
            Image(systemName: sfSymbol)
                .font(DS.IconFont.scaled(size * 0.5))
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(width: size, height: size)
                .background(.black, in: RoundedRectangle(cornerRadius: DS.Radius.small))
                .iconGlassBorder()
        } else {
            CachedAsyncImage(url: URL(string: source.imageURL)) {
                Image(systemName: source.type == "music_service" ? DS.Icons.playlists : DS.Icons.speaker)
                    .font(DS.IconFont.scaled(size * 0.4))
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
            .iconGlassBorder()
        }
    }

    private static func sfSymbolIcon(for sourceName: String) -> String? {
        matchKeyword(in: sfSymbolIcons, for: sourceName)
    }

    /// Public per-item icon lookup for input cards.
    /// Falls back to "cable.connector" for unrecognized input names.
    static func sfSymbolIcon(forItemName name: String) -> String {
        matchKeyword(in: sfSymbolIcons, for: name) ?? DS.Icons.cableConnector
    }
}

// MARK: - Icon Border Modifier

private extension View {
    func iconGlassBorder() -> some View {
        self
            .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
    }
}
