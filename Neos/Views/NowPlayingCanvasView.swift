import SwiftUI
import NeosDomain

struct NowPlayingCanvasView: View {
    let state: AppState

    private var dominantColors: [Color] { state.canvasDominantColors }
    @FocusState private var isFocused: Bool

    private var nowPlayingResolvedImageURL: String {
        state.resolvedImageURL(forMID: state.nowPlaying.mid, originalURL: state.nowPlaying.imageURL)
    }

    // MARK: - Artwork URL

    /// The artwork already known to load: what the player bar shows.
    private var baseArtworkURL: URL? {
        guard !nowPlayingResolvedImageURL.isEmpty else { return nil }
        return URL(string: nowPlayingResolvedImageURL)
    }

    /// The track's own artwork, an upgrade over `baseArtworkURL` because it may fail to load.
    private var artworkURL: URL? {
        // A custom image is a deliberate choice; the track's own art must not replace it.
        if state.hasCustomStationImage(forMID: state.nowPlaying.mid) { return nil }
        let rawURL: String? = {
            if let uri = state.trackMetadata?.albumArtURI, !uri.isEmpty { return uri }
            if !nowPlayingResolvedImageURL.isEmpty { return nowPlayingResolvedImageURL }
            return nil
        }()
        guard let rawURL else { return nil }
        let resolved = ImageURLUpscaler.highResURL(from: rawURL) ?? ImageURLUpscaler.httpsURL(rawURL)
        return URL(string: resolved)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            canvasHeader
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)

            Spacer(minLength: DS.Spacing.lg)

            heroArtwork
                .padding(.horizontal, DS.Spacing.xxxl)

            Spacer(minLength: DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            AmbientBackground(colors: dominantColors)
                .ignoresSafeArea()
        }
        .task(id: nowPlayingResolvedImageURL) {
            await updateColors()
        }
        #if os(macOS)
        .focusable()
        .focusEffectDisabled()
        .focused($isFocused)
        .onKeyPress(.escape) {
            state.isNowPlayingCanvasOpen = false
            return .handled
        }
        .onAppear {
            DispatchQueue.main.async { isFocused = true }
        }
        #endif
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.NowPlayingCanvas.view)
    }

    // MARK: - Header

    private var canvasHeader: some View {
        HStack {
            // Artist chip (Tidal style; pill with translucent background)
            if !state.nowPlaying.artist.isEmpty {
                HStack(spacing: DS.Spacing.md) {
                    CachedAsyncImage(url: artworkURL) {
                        Image(systemName: DS.Icons.personCircleFill)
                            .font(DS.IconFont.xxxl)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    Text(state.nowPlaying.artist)
                        .typography(.sectionHeader)
                        .foregroundStyle(.white)
                        .accessibilityIdentifier(AccessibilityID.NowPlayingCanvas.artistName)
                }
                .padding(.trailing, DS.Spacing.lg)
                .padding(.leading, DS.Spacing.xs)
                .padding(.vertical, DS.Spacing.xs)
                .background(.white.opacity(0.12), in: Capsule())
            }

            Spacer()

            HoverButton(
                action: { state.isNowPlayingCanvasOpen = false },
                accessibilityID: AccessibilityID.NowPlayingCanvas.closeButton
            ) { hovered in
                Image(systemName: DS.Icons.expandDown)
                    .font(DS.IconFont.lgEmphasis)
                    .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(DS.Colors.surfaceElevated.opacity(hovered ? 1 : 0.6), in: Circle())
            }
            .accessibilityLabel("Close Player")
            #if os(iOS)
            // The Mac closes on Escape through the canvas's keyboard focus, which iOS cannot take.
            .keyboardShortcut(.cancelAction)
            #endif
        }
    }

    // MARK: - Hero Artwork

    private var heroArtwork: some View {
        CachedAsyncImage(url: baseArtworkURL ?? artworkURL, highResURL: artworkURL) {
            Image(systemName: DS.Icons.musicNote)
                .font(DS.IconFont.mega)
                .foregroundStyle(DS.Colors.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.Colors.surfaceElevated)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 650)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.artworkLarge))
        .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
        .accessibilityIdentifier(AccessibilityID.NowPlayingCanvas.artwork)
    }

    // MARK: - Color Extraction

    private func updateColors() async {
        guard let url = artworkURL else {
            withAnimation(.easeInOut(duration: 0.5)) {
                state.canvasDominantColors = DominantColorExtractor.defaultColors
            }
            return
        }

        // Same order as the view: the track's own image, then the one that always loads.
        var artwork: PlatformImage?
        for candidate in [url, baseArtworkURL].compactMap({ $0 }) {
            if let cached = await ImageCache.shared.load(candidate) {
                artwork = cached
                break
            }
            if let data = try? await NeosURLSession.shared.data(from: candidate).0,
               let downloaded = PlatformImage(data: data) {
                artwork = downloaded
                break
            }
        }

        guard let artwork else {
            withAnimation(.easeInOut(duration: 0.5)) {
                state.canvasDominantColors = DominantColorExtractor.defaultColors
            }
            return
        }

        let colors = await DominantColorExtractor.extractColors(from: artwork)
        withAnimation(.easeInOut(duration: 0.5)) {
            state.canvasDominantColors = colors
        }
    }
}

// MARK: - Ambient Background

private struct AmbientBackground: View {
    let colors: [Color]

    var body: some View {
        (colors.first ?? DS.Colors.background)
    }
}
