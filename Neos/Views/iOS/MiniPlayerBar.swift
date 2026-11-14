import SwiftUI

/// The player above the tabs on iPhone: what plays, play or pause, and next. A tap opens the full player.
struct MiniPlayerBar: View {
    let state: AppState
    let playerVM: PlayerViewModel

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            CachedAsyncImage(url: state.artwork(forMID: state.nowPlaying.mid, originalURL: state.nowPlaying.imageURL).base) {
                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .fill(DS.Colors.surfaceElevated)
                    .overlay {
                        Image(systemName: DS.Icons.musicNote)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(state.nowPlaying.displayedTitle)
                    .typography(.bodyMedium)
                    .lineLimit(1)
                if !state.nowPlaying.artist.isEmpty {
                    Text(state.nowPlaying.artist)
                        .typography(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the player")

            Button { playerVM.togglePlayPause() } label: {
                Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                    .font(DS.IconFont.xl)
                    .frame(width: DS.HitTarget.button, height: DS.HitTarget.button)
            }
            .accessibilityLabel(state.isPlaying ? "Pause" : "Play")

            Button { playerVM.next() } label: {
                Image(systemName: "forward.fill")
                    .font(DS.IconFont.lg)
                    .frame(width: DS.HitTarget.button, height: DS.HitTarget.button)
            }
            .accessibilityLabel("Next")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(.bar)
        .contentShape(Rectangle())
        .onTapGesture { state.isNowPlayingCanvasOpen = true }
    }
}
