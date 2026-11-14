import SwiftUI

/// The player above the tabs on iPhone: what plays and where, play or pause, and next. A tap opens the full player.
struct MiniPlayerBar: View {
    let state: AppState
    let playerVM: PlayerViewModel

    /// Named once there is a choice, as in the Mac's player bar.
    private var speakerName: String? {
        state.displayPlayers.count > 1 ? state.playbackTargetName : nil
    }

    /// The artwork's colour, already dark enough for white text; grey until it is known.
    private var cardColor: Color {
        let colors = state.canvasDominantColors
        guard colors != DominantColorExtractor.defaultColors, let color = colors.first else {
            return DS.Colors.surfaceElevated
        }
        return color
    }

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            artwork

            nowPlayingText
                .frame(maxWidth: .infinity, alignment: .leading)

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
        .padding(.leading, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.sm)
        .background(cardColor, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        .overlay(alignment: .bottom) {
            PlaybackLine(state: state)
                .padding(.horizontal, DS.Spacing.sm)
        }
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
        .onTapGesture { state.isNowPlayingCanvasOpen = true }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.bottom, DS.Spacing.xs)
        .background {
            // The page scrolls under the card; fade it out so none of it shows above the tabs.
            LinearGradient(colors: [.clear, DS.Colors.background], startPoint: .top, endPoint: .bottom)
        }
        .tracksArtworkColors(state)
    }

    private var artwork: some View {
        CachedAsyncImage(url: state.artwork(forMID: state.nowPlaying.mid, originalURL: state.nowPlaying.imageURL).base) {
            RoundedRectangle(cornerRadius: DS.Radius.small)
                .fill(DS.Colors.surfaceElevated)
                .overlay {
                    Image(systemName: DS.Icons.musicNote)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
        }
        .frame(width: DS.ImageSize.listRow, height: DS.ImageSize.listRow)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
    }

    /// Part of the tap that opens the player: a speaker line of its own would sit under the thumb aiming at the title.
    private var nowPlayingText: some View {
        let title = state.nowPlaying.displayedTitle
        let artist = state.nowPlaying.artist
        return VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            if let speakerName {
                // The speaker takes the second line, so the artist joins the title's.
                Group {
                    if artist.isEmpty {
                        Text(title)
                    } else {
                        Text("\(Text(title)) · \(Text(artist).fontWeight(.regular).foregroundStyle(DS.Colors.textSecondary))")
                    }
                }
                .foregroundStyle(.primary)
                .typography(.secondaryEmphasis)
                .lineLimit(1)

                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: DS.Icons.speaker)
                    Text(speakerName)
                        .lineLimit(1)
                }
                .foregroundStyle(DS.Colors.accent)
                .typography(.badge)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Playing on \(speakerName)")
            } else {
                Text(title)
                    .foregroundStyle(.primary)
                    .typography(.secondaryEmphasis)
                    .lineLimit(1)
                if !artist.isEmpty {
                    Text(artist)
                        .typography(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the player")
    }
}

/// How far the track has played, along the bottom of the mini player.
private struct PlaybackLine: View {
    let state: AppState

    var body: some View {
        TimelineView(.animation(minimumInterval: 1, paused: !state.isTimelineRunning)) { context in
            let fraction = PlaybackClock.fraction(
                reported: state.playbackPosition, duration: state.playbackDuration,
                reportedAt: state.lastProgressUpdate, isPlaying: state.isTimelineRunning, at: context.date
            )
            Capsule()
                .fill(.white.opacity(0.2))
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(.white)
                            .frame(width: geo.size.width * fraction)
                    }
                }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}
