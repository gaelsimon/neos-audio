import SwiftUI
import NeosDomain

struct BrowseItemRow: View {
    let item: BrowseItem
    var isNowPlaying: Bool = false
    var isLoading: Bool = false
    var isAddingToQueue: Bool = false
    var onPlayNext: (() -> Void)?
    var onArtistView: (() -> Void)?
    var onAlbumView: (() -> Void)?
    var serviceOptions: [ServiceOption] = []
    var onServiceOption: ((ServiceOption) -> Void)?
    var state: AppState?
    var onSetCustomImage: (() -> Void)?
    let onTap: () -> Void
    let onAddToQueue: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            artworkThumbnail

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(item.name)
                    .typography(.bodyPrimary)
                    .foregroundStyle(isNowPlaying ? DS.Colors.accent : .primary)
                    .lineLimit(1)

                if let artist = item.artist, !artist.isEmpty {
                    Text(artist)
                        .typography(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            actionMenu
                .opacity(isHovered && hasActions ? 1 : 0)

            if item.playable {
                if isAddingToQueue {
                    Spinner(size: 12, lineWidth: 1.5)
                } else {
                    HoverButton(action: onAddToQueue) { hovered in
                        Image(systemName: DS.Icons.add)
                            .typography(.secondary)
                            .foregroundStyle(DS.Colors.accent.opacity(hovered ? 1.0 : 0.7))
                    }
                    .help("Add to queue")
                }
            }

            if isLoading && !item.browsable {
                Spinner(size: 16, lineWidth: 2)
            } else if isNowPlaying && !item.browsable {
                Image(systemName: DS.Icons.speakerActive)
                    .typography(.secondary)
                    .foregroundStyle(DS.Colors.accent)
            } else if item.browsable || item.isSubSource {
                Image(systemName: DS.Icons.forward)
                    .typography(.secondary)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            rowBackground,
            in: RoundedRectangle(cornerRadius: DS.Radius.small)
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { isHovered = $0 }
    }

    // MARK: - Action Menu

    private var hasActions: Bool {
        onPlayNext != nil || onArtistView != nil || onAlbumView != nil
            || !serviceOptions.isEmpty
            || onSetCustomImage != nil || state?.hasCustomStationImage(forMID: item.imageKey) == true
    }

    @ViewBuilder
    private var actionMenu: some View {
        Menu {
            if let onPlayNext {
                Button { onPlayNext() } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
            }

            if (onPlayNext != nil) && (onArtistView != nil || onAlbumView != nil) {
                Divider()
            }

            if let onArtistView {
                Button { onArtistView() } label: {
                    Label("Go to Artist", systemImage: "person")
                }
            }
            if let onAlbumView {
                Button { onAlbumView() } label: {
                    Label("Go to Album", systemImage: "square.stack")
                }
            }

            if !serviceOptions.isEmpty {
                if onPlayNext != nil || onArtistView != nil || onAlbumView != nil {
                    Divider()
                }
                ForEach(serviceOptions) { option in
                    Button(option.name) { onServiceOption?(option) }
                }
            }

            if (onPlayNext != nil || onArtistView != nil || onAlbumView != nil || !serviceOptions.isEmpty)
                && (onSetCustomImage != nil || state?.hasCustomStationImage(forMID: item.imageKey) == true) {
                Divider()
            }

            if let onSetCustomImage {
                Button {
                    onSetCustomImage()
                } label: {
                    Label("Set Custom Artwork…", systemImage: "photo")
                }
            }

            if let key = item.imageKey, let state, state.hasCustomStationImage(forMID: key) {
                Button(role: .destructive) {
                    state.removeCustomStationImage(forMID: key)
                } label: {
                    Label("Remove Custom Artwork", systemImage: "photo.badge.x")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .typography(.secondary)
                .foregroundStyle(DS.Colors.textSecondary)
                .frame(minWidth: 36, minHeight: 36)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var effectiveImageURL: String {
        if let state {
            return state.resolvedImageURL(forMID: item.imageKey, originalURL: item.imageURL)
        }
        return item.resolvedImageURL
    }

    // MARK: - Artwork Thumbnail

    private var artworkThumbnail: some View {
        ZStack {
            if item.type == .heosServer || item.type == .dlnaServer {
                Image(systemName: DS.Icons.server)
                    .font(DS.IconFont.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .frame(width: DS.ImageSize.listRow, height: DS.ImageSize.listRow)
                    .background(DS.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.small))
            } else {
                CachedAsyncImage(
                    url: URL(string: effectiveImageURL),
                    highResURL: ImageURLUpscaler.highResURL(from: item.imageURL).flatMap(URL.init(string:))
                ) {
                    Image(systemName: iconForType)
                        .font(DS.IconFont.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: DS.ImageSize.listRow, height: DS.ImageSize.listRow)
                        .background(DS.Colors.surfaceElevated)
                }
                .frame(width: DS.ImageSize.listRow, height: DS.ImageSize.listRow)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
            }

            if isHovered && item.playable {
                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .fill(.black.opacity(0.5))
                    .frame(width: DS.ImageSize.listRow, height: DS.ImageSize.listRow)
                Image(systemName: DS.Icons.playing)
                    .font(DS.IconFont.sm)
                    .foregroundStyle(.white)
            }
        }
    }

    private var rowBackground: Color {
        if isNowPlaying || isLoading {
            return DS.Colors.accent.opacity(0.08)
        } else if isHovered {
            return DS.Colors.surfaceElevated.opacity(0.5)
        }
        return .clear
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
