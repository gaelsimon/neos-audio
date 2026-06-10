import SwiftUI
import NeosDomain
import AppKit

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
    var onAlbumTap: (() -> Void)?
    var onArtistTap: (() -> Void)?
    var isResolvingArtist: Bool = false
    var onPlayNext: (() -> Void)?
    var onAddToQueue: (() -> Void)?
    var onArtistView: (() -> Void)?
    var onAlbumView: (() -> Void)?
    var serviceOptions: [ServiceOption] = []
    var onServiceOption: ((ServiceOption) -> Void)?
    var state: AppState?
    var imageKey: String?
    var onSetCustomImage: (() -> Void)?
    let onTap: () -> Void

    @State private var isHovered = false

    private var effectiveImageURL: String {
        if let state, let imageKey {
            return state.resolvedImageURL(forMID: imageKey, originalURL: imageURL)
        }
        return imageURL
    }

    private var textColumnWeights: [CGFloat] {
        TrackListColumnWeights.textColumnWeights(showArtist: showArtist, showAlbum: showAlbum)
    }

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            numberColumn

            TrackListWeightedColumnsLayout(weights: textColumnWeights, spacing: DS.Spacing.sm) {
                titleColumn

                if showArtist {
                    artistColumn
                }

                if showAlbum {
                    albumColumn
                }
            }
            .frame(maxWidth: .infinity)

            actionMenu
                .opacity(isHovered && hasActions ? 1 : 0)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .frame(height: DS.TrackList.rowHeight)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: DS.Radius.small))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { isHovered = $0 }
        .accessibilityIdentifier(AccessibilityID.TrackList.row(index))
    }

    // MARK: - Action Menu

    private var hasActions: Bool {
        onPlayNext != nil || onAddToQueue != nil || onArtistView != nil || onAlbumView != nil
            || !serviceOptions.isEmpty
            || onSetCustomImage != nil || state?.hasCustomStationImage(forMID: imageKey) == true
    }

    @ViewBuilder
    private var actionMenu: some View {
        Menu {
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

            if (onPlayNext != nil || onAddToQueue != nil) && (onArtistView != nil || onAlbumView != nil) {
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
                if onPlayNext != nil || onAddToQueue != nil || onArtistView != nil || onAlbumView != nil {
                    Divider()
                }
                ForEach(serviceOptions) { option in
                    Button(option.name) { onServiceOption?(option) }
                }
            }

            if (onPlayNext != nil || onAddToQueue != nil || onArtistView != nil || onAlbumView != nil || !serviceOptions.isEmpty)
                && (onSetCustomImage != nil || state?.hasCustomStationImage(forMID: imageKey) == true) {
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

            Text(name)
                .typography(.bodyPrimary)
                .foregroundStyle(isNowPlaying ? DS.Colors.accent : .primary)
                .lineLimit(1)
                .accessibilityIdentifier(AccessibilityID.TrackList.title(index))
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
            } else if let onArtistTap {
                ArtistLinkText(artist: artist ?? "", onTap: onArtistTap)
            } else {
                Text(artist ?? "")
                    .typography(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(2)
    }

    // MARK: - Album Column

    private var albumColumn: some View {
        Group {
            if let onAlbumTap {
                AlbumLinkText(album: album ?? "", onTap: onAlbumTap)
            } else {
                Text(album ?? "")
                    .typography(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .layoutPriority(2)
    }

    // MARK: - Row Background

    private var rowBackground: Color {
        if isNowPlaying {
            return DS.Colors.accent.opacity(0.08)
        } else if isHovered {
            return DS.Colors.surfaceElevated.opacity(0.5)
        }
        return .clear
    }
}

// MARK: - Cross-Link Text

private struct AlbumLinkText: View {
    let album: String
    let onTap: () -> Void

    var body: some View {
        CrossLinkText(text: album, onTap: onTap)
    }
}

private struct ArtistLinkText: View {
    let artist: String
    let onTap: () -> Void

    var body: some View {
        CrossLinkText(text: artist, onTap: onTap)
    }
}

private struct CrossLinkText: View {
    let text: String
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        Text(text)
            .typography(.secondary)
            .foregroundStyle(isHovered ? DS.Colors.accent : DS.Colors.textSecondary)
            .lineLimit(1)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onDisappear {
                if isHovered {
                    NSCursor.pop()
                    isHovered = false
                }
            }
            .onTapGesture(perform: onTap)
            .accessibilityAddTraits(.isLink)
    }
}
