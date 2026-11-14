import SwiftUI
import NeosDomain

struct NowPlayingCanvasView: View {
    let state: AppState
    /// What leads the header: the artist on the Mac; the speaker on iPhone and iPad, which name the artist under the artwork.
    enum HeaderLead {
        case artist
        case speaker(open: () -> Void)
    }

    var headerLead: HeaderLead = .artist

    private var dominantColors: [Color] { state.canvasDominantColors }
    private var artwork: NowPlayingArtwork { NowPlayingArtwork(state: state) }
    @Environment(\.isCompactLayout) private var isCompactLayout
    @FocusState private var isFocused: Bool

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            canvasHeader
                .padding(.horizontal, DS.Spacing.xl)
                .padding(.top, DS.Spacing.lg)

            Spacer(minLength: DS.Spacing.lg)

            heroArtwork
                .padding(.horizontal, isCompactLayout ? DS.Spacing.xl : DS.Spacing.xxxl)

            Spacer(minLength: DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            AmbientBackground(colors: dominantColors)
                .ignoresSafeArea()
        }
        .tracksArtworkColors(state)
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
            switch headerLead {
            case .speaker(let open):
                speakerButton(action: open)
            case .artist where !state.nowPlaying.artist.isEmpty:
                // Artist chip (Tidal style; pill with translucent background)
                HStack(spacing: DS.Spacing.md) {
                    CachedAsyncImage(url: artwork.trackURL) {
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
            case .artist:
                EmptyView()
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

    @ViewBuilder
    private func speakerButton(action: @escaping () -> Void) -> some View {
        if let target = state.playbackTargetName {
            Button(action: action) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: DS.Icons.speaker)
                    Text(target)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(DS.IconFont.sm)
                }
                .typography(.bodyMedium)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(.white.opacity(0.12), in: Capsule())
                .frame(minHeight: DS.HitTarget.button)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Playing on \(target)")
            .accessibilityHint("Shows the speakers")
        }
    }

    // MARK: - Hero Artwork

    private var heroArtwork: some View {
        CachedAsyncImage(url: artwork.baseURL ?? artwork.trackURL, highResURL: artwork.trackURL) {
            Image(systemName: DS.Icons.musicNote)
                .font(DS.IconFont.mega)
                .foregroundStyle(DS.Colors.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DS.Colors.surfaceElevated)
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 650)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.artworkLarge))
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: NowPlayingArtworkWidthKey.self, value: geo.size.width)
            }
        }
        .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
        .accessibilityIdentifier(AccessibilityID.NowPlayingCanvas.artwork)
    }
}

/// The artwork's width, so a player can line its controls up under it.
struct NowPlayingArtworkWidthKey: PreferenceKey {
    static let defaultValue: CGFloat? = nil

    static func reduce(value: inout CGFloat?, nextValue: () -> CGFloat?) {
        value = nextValue() ?? value
    }
}

// MARK: - Ambient Background

private struct AmbientBackground: View {
    let colors: [Color]

    var body: some View {
        (colors.first ?? DS.Colors.background)
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .top, endPoint: .bottom)
            }
    }
}
