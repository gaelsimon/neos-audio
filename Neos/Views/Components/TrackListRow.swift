import SwiftUI
import NeosDomain

func isLinkableArtist(_ name: String?) -> Bool {
    guard let name, !name.isEmpty else { return false }
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return false }
    let excluded = ["various artists", "unknown artist"]
    return !excluded.contains(trimmed.lowercased())
}

struct TrackListRow: View {
    let index: Int
    let name: String
    let artist: String?
    let album: String?
    let imageURL: String
    let isNowPlaying: Bool
    var showArtist: Bool = true
    var showAlbum: Bool = true
    var showArtwork: Bool = true
    var onAlbumTap: (() -> Void)?
    var onArtistTap: (() -> Void)?
    var isResolvingArtist: Bool = false
    var onPlayNext: (() -> Void)?
    var onAddToQueue: (() -> Void)?
    var onArtistView: (() -> Void)?
    var onAlbumView: (() -> Void)?
    var serviceOptions: [ServiceOption] = []
    var onServiceOption: ((ServiceOption) -> Void)?
    var externalLink: ExternalLinkMenu?
    var state: AppState?
    var imageKey: String?
    var onSetCustomImage: (() -> Void)?
    var onRemove: (() -> Void)?
    /// Off where the list removes a row by swiping it; the context menu keeps the action either way.
    var showsRemoveButton = true
    /// An iPhone row drops its number where the order means nothing; the columns of a wider row keep it.
    var numbersRow = true
    let onTap: () -> Void

    @State private var isHovered = false
    /// No room for columns: the artist goes under the title and the album goes.
    @Environment(\.isCompactLayout) private var isCompact

    private var showsArtistColumn: Bool { showArtist && !isCompact }
    private var showsAlbumColumn: Bool { showAlbum && !isCompact }

    private var effectiveImageURL: String {
        if let state, let imageKey {
            return state.resolvedImageURL(forMID: imageKey, originalURL: imageURL)
        }
        return imageURL
    }

    private var textColumnWeights: [CGFloat] {
        TrackListColumnWeights.textColumnWeights(showArtist: showsArtistColumn, showAlbum: showsAlbumColumn)
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            if numbersRow || !isCompact {
                numberColumn
            }

            TrackListWeightedColumnsLayout(weights: textColumnWeights, spacing: DS.Spacing.sm) {
                titleColumn

                if showsArtistColumn {
                    artistColumn
                }

                if showsAlbumColumn {
                    albumColumn
                }
            }
            .frame(maxWidth: .infinity)

            actionMenu
                .opacity((isHovered || !DS.revealsControlsOnHover) && hasActions ? 1 : 0)

            if let onRemove, showsRemoveButton {
                HoverButton(action: onRemove) { hovered in
                    Image(systemName: DS.Icons.dismiss)
                        .typography(.secondary, color: hovered ? .white : nil)
                        .frame(width: DS.TrackList.actionWidth, height: DS.TrackList.actionWidth)
                }
                .opacity(isHovered || !DS.revealsControlsOnHover ? 1 : 0)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        // A floor, not a fixed height: larger text sizes on iPhone and iPad need the room.
        .frame(minHeight: DS.TrackList.rowHeight)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: DS.Radius.small))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onTap() }
        .onTapGesture(perform: onTap)
        .onHover { isHovered = $0 }
        .contextMenu(hasActions || onRemove != nil ? ContextMenu { menuItems } : nil)
        .accessibilityIdentifier(AccessibilityID.TrackList.row(index))
    }

    // MARK: - Action Menu

    private var hasQueueActions: Bool { onPlayNext != nil || onAddToQueue != nil }

    private var hasNavigationActions: Bool { onArtistView != nil || onAlbumView != nil }

    private var hasArtworkActions: Bool {
        onSetCustomImage != nil || state?.hasCustomStationImage(forMID: imageKey) == true
    }

    private var hasActions: Bool {
        hasQueueActions || hasNavigationActions || !serviceOptions.isEmpty
            || externalLink != nil || hasArtworkActions
    }

    @ViewBuilder
    private var actionMenu: some View {
        Menu {
            menuItems
        } label: {
            Image(systemName: "ellipsis")
                .typography(.secondary)
                .frame(minWidth: DS.TrackList.actionWidth, minHeight: DS.TrackList.actionWidth)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: DS.TrackList.actionWidth, height: DS.TrackList.actionWidth)
    }

    /// Shared by the hover "…" button and the right-click context menu.
    @ViewBuilder
    private var menuItems: some View {
        Group {
            if let onPlayNext {
                Button { onPlayNext() } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }
            }
            if let onAddToQueue {
                Button { onAddToQueue() } label: {
                    Label("Add to Queue", systemImage: "text.badge.plus")
                }
            }

            if hasQueueActions && hasNavigationActions {
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
                if hasQueueActions || hasNavigationActions {
                    Divider()
                }
                ForEach(serviceOptions) { option in
                    Button(option.name) { onServiceOption?(option) }
                }
            }

            externalLinkItems

            artworkItems

            if let onRemove {
                if hasActions {
                    Divider()
                }
                Button(role: .destructive) { onRemove() } label: {
                    Label("Remove from Queue", systemImage: DS.Icons.close)
                }
            }
        }
    }

    @ViewBuilder
    private var externalLinkItems: some View {
        if let externalLink {
            if hasQueueActions || hasNavigationActions || !serviceOptions.isEmpty {
                Divider()
            }
            ExternalLinkMenuItems(link: externalLink, state: state)
        }
    }

    @ViewBuilder
    private var artworkItems: some View {
        if hasArtworkActions {
            if hasQueueActions || hasNavigationActions || !serviceOptions.isEmpty || externalLink != nil {
                Divider()
            }
            if let onSetCustomImage {
                Button {
                    onSetCustomImage()
                } label: {
                    Label("Set Custom Artwork…", systemImage: "photo")
                }
            }
            if let imageKey, let state, state.hasCustomStationImage(forMID: imageKey) {
                Button(role: .destructive) {
                    state.removeCustomStationImage(forMID: imageKey)
                } label: {
                    Label("Remove Custom Artwork", systemImage: "photo.badge.x")
                }
            }
        }
    }

    // MARK: - Number Column

    private var numberColumn: some View {
        ZStack {
            if isHovered && !isNowPlaying {
                Image(systemName: DS.Icons.playing)
                    .font(DS.IconFont.body)
                    .foregroundStyle(.white)
            } else if isNowPlaying {
                Image(systemName: DS.Icons.speakerActive)
                    .font(DS.IconFont.body)
                    .foregroundStyle(DS.Colors.accent)
            } else {
                Text("\(index)")
                    .typography(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(width: DS.TrackList.numberWidth, alignment: .leading)
    }

    // MARK: - Title Column

    private var titleColumn: some View {
        HStack(spacing: DS.Spacing.md) {
            if showArtwork {
                CachedAsyncImage(url: URL(string: effectiveImageURL)) {
                    RoundedRectangle(cornerRadius: DS.Radius.small)
                        .fill(DS.Colors.surfaceElevated)
                        .overlay {
                            Image(systemName: DS.Icons.musicNote)
                                .font(DS.IconFont.sm)
                                .foregroundStyle(DS.Colors.textTertiary)
                        }
                }
                .frame(width: DS.ImageSize.trackListRow, height: DS.ImageSize.trackListRow)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
            }

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(name.displayTitle)
                    .typography(.bodyPrimary, color: isNowPlaying ? DS.Colors.accent : nil)
                    .lineLimit(1)
                    .accessibilityIdentifier(AccessibilityID.TrackList.title(index))

                if isCompact && showArtist, let artist, !artist.isEmpty {
                    Text(artist)
                        .typography(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(3)
    }

    // MARK: - Artist Column

    private var artistColumn: some View {
        Group {
            if isResolvingArtist {
                Spinner(size: 12, lineWidth: 1.5)
                    .frame(height: 16)
            } else {
                CrossLink(artist ?? "", action: onArtistTap)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(2)
    }

    // MARK: - Album Column

    private var albumColumn: some View {
        CrossLink(album ?? "", action: onAlbumTap)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(2)
    }

    // MARK: - Row Background

    private var rowBackground: Color {
        // iPhone and iPad mark the playing row by its orange title alone.
        #if os(macOS)
        if isNowPlaying {
            return DS.Colors.accent.opacity(0.08)
        }
        #endif
        if isHovered {
            return DS.Colors.surfaceElevated.opacity(0.5)
        }
        return .clear
    }
}
