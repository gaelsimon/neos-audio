import SwiftUI
import NeosDomain
import AppKit

struct NowPlayingToolbar: View {
    let state: AppState
    let playerVM: PlayerViewModel
    let browseVM: BrowseViewModel
    let searchVM: SearchViewModel

    @State private var isArtworkHovered = false

    // MARK: - Cross-Link Navigation

    private var canBrowseAlbum: Bool {
        guard let sid = state.nowPlaying.sid,
              !state.nowPlaying.album.isEmpty,
              let caps = state.serviceCapabilities[sid] else { return false }
        return caps.canBrowseAlbums
    }

    private var canBrowseArtist: Bool {
        guard let sid = state.nowPlaying.sid,
              isLinkableArtist(state.nowPlaying.artist),
              let caps = state.serviceCapabilities[sid] else { return false }
        return caps.canBrowseArtists
    }

    private func navigateToAlbum() {
        guard let sid = state.nowPlaying.sid else { return }
        searchVM.dismissOverlay()
        browseVM.pushAlbumSearchNavigate(sid: sid, albumName: state.nowPlaying.album, artistHint: state.nowPlaying.artist)
    }

    private func navigateToArtist() {
        guard let sid = state.nowPlaying.sid else { return }
        searchVM.dismissOverlay()
        browseVM.pushArtistSearchNavigate(sid: sid, artistName: state.nowPlaying.artist)
    }

    // MARK: - Service Options

    @ViewBuilder private var serviceOptionButtons: some View {
        let options = state.nowPlayingOptions
        let thumbsUp = options.first { $0.id == ServiceOption.thumbsUpID }
        let thumbsDown = options.first { $0.id == ServiceOption.thumbsDownID }
        let addFav = options.first { $0.id == ServiceOption.addToFavoritesID }

        if thumbsUp != nil || thumbsDown != nil || addFav != nil {
            HStack(spacing: DS.Spacing.sm) {
                if let thumbsUp {
                    HoverButton(action: { playerVM.executeServiceOption(thumbsUp) }) { hovered in
                        Image(systemName: "hand.thumbsup")
                            .font(DS.IconFont.md)
                            .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                    }
                    .help(thumbsUp.name)
                }
                if let thumbsDown {
                    HoverButton(action: { playerVM.executeServiceOption(thumbsDown) }) { hovered in
                        Image(systemName: "hand.thumbsdown")
                            .font(DS.IconFont.md)
                            .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                    }
                    .help(thumbsDown.name)
                }
                if let addFav {
                    HoverButton(action: { playerVM.executeServiceOption(addFav) }) { hovered in
                        Image(systemName: "heart")
                            .font(DS.IconFont.md)
                            .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                    }
                    .help(addFav.name)
                }
            }
        }
    }

    // MARK: - Artwork

    @ViewBuilder private var artworkSection: some View {
        CachedAsyncImage(
            url: URL(string: state.resolvedImageURL(forMID: state.nowPlaying.mid, originalURL: state.nowPlaying.imageURL)),
            highResURL: ImageURLUpscaler.highResURL(from: state.nowPlaying.imageURL).flatMap(URL.init(string:))
        ) {
            Image(systemName: DS.Icons.musicNote)
                .typography(.bodyPrimary)
                .foregroundStyle(DS.Colors.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.Colors.surfaceElevated)
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
        .accessibilityIdentifier(AccessibilityID.Player.albumArt)
        .accessibilityLabel(canBrowseAlbum ? "Go to album: \(state.nowPlaying.album)" : "Album artwork")
        .overlay {
            if state.isLoadingTrack {
                RoundedRectangle(cornerRadius: DS.Radius.medium)
                    .fill(.black.opacity(0.5))
                Spinner(size: 16, lineWidth: 2, color: .white)
            }
        }
        .overlay {
            if isArtworkHovered {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.medium)
                        .fill(.black.opacity(0.35))
                    Image(systemName: DS.Icons.expandUp)
                        .font(DS.IconFont.bodyEmphasis)
                        .foregroundStyle(.white)
                }
            }
        }
        .onHover { isArtworkHovered = $0 }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Track Info

    @ViewBuilder private var trackInfoSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(state.nowPlaying.song.isEmpty ? "Not Playing" : state.nowPlaying.song)
                .typography(.bodyMedium)
                .lineLimit(1)
                .accessibilityIdentifier(AccessibilityID.Player.songTitle)
            if let station = state.nowPlaying.station, !station.isEmpty {
                Text(station)
                    .typography(.secondary)
                    .lineLimit(1)
                    .accessibilityIdentifier(AccessibilityID.Player.artistName)
            } else if !state.nowPlaying.artist.isEmpty {
                if browseVM.isResolvingArtist {
                    HStack(spacing: DS.Spacing.xs) {
                        Spinner(size: 12, lineWidth: 1.5)
                        Text(state.nowPlaying.artist)
                            .typography(.secondary)
                            .lineLimit(1)
                    }
                    .accessibilityIdentifier(AccessibilityID.Player.artistName)
                } else if canBrowseArtist {
                    NowPlayingCrossLink(
                        text: state.nowPlaying.artist,
                        onTap: { navigateToArtist() }
                    )
                    .accessibilityIdentifier(AccessibilityID.Player.artistName)
                } else {
                    Text(state.nowPlaying.artist)
                        .typography(.secondary)
                        .lineLimit(1)
                        .accessibilityIdentifier(AccessibilityID.Player.artistName)
                }
            }
            if !state.nowPlaying.album.isEmpty, state.nowPlaying.station == nil {
                if canBrowseAlbum {
                    NowPlayingCrossLink(
                        text: state.nowPlaying.album,
                        onTap: { navigateToAlbum() }
                    )
                } else {
                    Text(state.nowPlaying.album)
                        .typography(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: 220, alignment: .leading)
    }

    // MARK: - Background

    @ViewBuilder private var toolbarBackground: some View {
        if state.isNowPlayingCanvasOpen {
            ZStack {
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(.black.opacity(0.45))
                RoundedRectangle(cornerRadius: DS.Radius.xl)
                    .fill(.ultraThinMaterial)
            }
            .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
        } else {
            ZStack(alignment: .top) {
                // Backdrop blur
                Rectangle().fill(.ultraThinMaterial)

                // Pseudo-element: transparent → black for depth
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.15)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Main: subtle grey gradient
                LinearGradient(
                    stops: [
                        .init(color: Color(white: 0.235, opacity: 0.35), location: 0),
                        .init(color: Color(white: 0.247, opacity: 0.35), location: 0.53),
                        .init(color: Color(white: 0.275, opacity: 0.35), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Top border
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 0.5)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Left: artwork + info (equal flex column, content leading)
                HStack(spacing: DS.Spacing.md) {
                    if !state.isNowPlayingCanvasOpen {
                        artworkSection
                    }

                    trackInfoSection
                }
                .clipped()
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .onTapGesture { state.isNowPlayingCanvasOpen.toggle() }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Center: controls stacked with progress below (fixed max width)
                VStack(spacing: DS.Spacing.sm) {
                    PlayerControlView(state: state, viewModel: playerVM, size: .bottomBar)

                    ToolbarProgressSection(state: state, playerVM: playerVM)
                }
                .frame(maxWidth: 550)

                // Right: service options + quality badge + volume (equal flex column, content trailing)
                HStack(spacing: DS.Spacing.md) {
                    serviceOptionButtons

                    if let quality = state.trackMetadata?.qualityDescription {
                        Text(quality)
                            .typography(.badge)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.vertical, DS.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.small)
                                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                            )
                            .accessibilityIdentifier(AccessibilityID.Player.qualityBadge)
                    }
                    VolumeControlView(state: state, viewModel: playerVM, style: .bottomBar)

                    HoverButton(action: { state.isQueuePanelOpen.toggle() }) { hovered in
                        Image(systemName: DS.Icons.queue)
                            .font(DS.IconFont.lg)
                            .foregroundStyle(
                                state.isQueuePanelOpen ? DS.Colors.accent :
                                hovered ? .white : DS.Colors.textSecondary
                            )
                    }
                    .help("Queue")
                    .accessibilityIdentifier(AccessibilityID.QueuePanel.toggleButton)
                    .accessibilityLabel("Toggle queue panel")
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal, state.isNowPlayingCanvasOpen ? DS.Spacing.xxl : DS.Spacing.xl)
            .padding(.vertical, state.isNowPlayingCanvasOpen ? DS.Spacing.xl : DS.Spacing.md)
        }
        .background { toolbarBackground }
        .padding(.horizontal, state.isNowPlayingCanvasOpen ? DS.Spacing.md : 0)
        .padding(.bottom, state.isNowPlayingCanvasOpen ? DS.Spacing.sm : 0)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.35), value: state.isNowPlayingCanvasOpen)
    }
}

// MARK: - Observation Island

/// Isolates progress-related AppState reads so that frequent
/// playbackPosition/lastProgressUpdate changes only re-render
/// the progress bar, not the entire toolbar.
private struct ToolbarProgressSection: View {
    let state: AppState
    let playerVM: PlayerViewModel

    var body: some View {
        ProgressBarView(
            playbackPosition: state.playbackPosition,
            playbackDuration: state.playbackDuration,
            lastProgressUpdate: state.lastProgressUpdate,
            isPlaying: state.isPlaying,
            nowPlayingMID: state.nowPlaying.mid,
            onSeek: { position in playerVM.seek(to: position) },
            showTrack: true,
            inlineTimeLabels: true
        )
    }
}

// MARK: - Now Playing Cross Link

private struct NowPlayingCrossLink: View {
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
