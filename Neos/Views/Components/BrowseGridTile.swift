import SwiftUI
import NeosDomain

struct BrowseGridTile: View {
    let item: BrowseItem
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                GeometryReader { geo in
                    if item.type == .heosServer || item.type == .dlnaServer {
                        Rectangle()
                            .fill(DS.Colors.surfaceElevated)
                            .overlay {
                                Image(systemName: DS.Icons.server)
                                    .font(DS.IconFont.xxxl)
                                    .foregroundStyle(DS.Colors.textTertiary)
                            }
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
                    } else {
                        CachedAsyncImage(
                            url: URL(string: item.resolvedImageURL),
                            highResURL: ImageURLUpscaler.highResURL(from: item.imageURL).flatMap(URL.init(string:))
                        ) {
                            Rectangle()
                                .fill(DS.Colors.surfaceElevated)
                                .overlay {
                                    Image(systemName: iconForType)
                                        .font(DS.IconFont.xxxl)
                                        .foregroundStyle(DS.Colors.textTertiary)
                                }
                        }
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
                    }
                }
                .aspectRatio(1, contentMode: .fit)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .typography(.secondaryEmphasis)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let artist = item.artist, !artist.isEmpty {
                        Text(artist)
                            .typography(.secondary)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(height: 40, alignment: .top)
            }
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 0.8 : 1.0)
        .onHover { isHovered = $0 }
    }

    private var iconForType: String {
        switch item.type {
        case .song: DS.Icons.musicNote
        case .station: DS.Icons.radio
        case .album: DS.Icons.album
        case .artist: DS.Icons.person
        case .playlist: DS.Icons.playlists
        case .genre: DS.Icons.genre
        case .container: DS.Icons.folder
        case .dlnaServer, .heosServer: DS.Icons.server
        case .heosService, .musicService: DS.Icons.musicNoteTV
        }
    }
}
