import SwiftUI
import NeosDomain

struct NowPlayingBanner: View {
    let state: AppState
    var onSeek: ((TimeInterval) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DS.Spacing.md) {
                // Album Art
                CachedAsyncImage(
                    url: URL(string: state.resolvedImageURL(forMID: state.nowPlaying.mid, originalURL: state.nowPlaying.imageURL)),
                    highResURL: ImageURLUpscaler.highResURL(from: state.nowPlaying.imageURL).flatMap(URL.init(string:))
                ) {
                    Image(systemName: DS.Icons.musicNote)
                        .typography(.pageTitle)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary)
                }
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.medium))
                .accessibilityIdentifier(AccessibilityID.NowPlayingBanner.albumArt)

                // Song Info
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(state.nowPlaying.song.isEmpty ? "Not Playing" : state.nowPlaying.song)
                        .typography(.sectionHeader)
                        .lineLimit(1)
                        .accessibilityIdentifier(AccessibilityID.NowPlayingBanner.songTitle)

                    if let station = state.nowPlaying.station, !station.isEmpty {
                        Text(station)
                            .typography(.secondary)
                            .lineLimit(1)
                    } else if !state.nowPlaying.artist.isEmpty {
                        Text(state.nowPlaying.artist)
                            .typography(.secondary)
                            .lineLimit(1)
                            .accessibilityIdentifier(AccessibilityID.NowPlayingBanner.artistName)
                    }

                    if !state.nowPlaying.album.isEmpty {
                        Text(state.nowPlaying.album)
                            .typography(.secondary)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .lineLimit(1)
                            .accessibilityIdentifier(AccessibilityID.NowPlayingBanner.albumName)
                    }
                    if let quality = state.trackMetadata?.qualityDescription {
                        Text(quality)
                            .typography(.badge)
                            .foregroundStyle(DS.Colors.textTertiary)
                            .lineLimit(1)
                            .accessibilityIdentifier(AccessibilityID.NowPlayingBanner.qualityBadge)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)

            BannerProgressSection(state: state, onSeek: onSeek)
        }
    }
}

// MARK: - Observation Island

/// Isolates progress-related AppState reads so that frequent
/// playbackPosition/lastProgressUpdate changes only re-render
/// the progress bar, not the entire banner.
private struct BannerProgressSection: View {
    let state: AppState
    var onSeek: ((TimeInterval) -> Void)?

    var body: some View {
        ProgressBarView(
            playbackPosition: state.playbackPosition,
            playbackDuration: state.playbackDuration,
            lastProgressUpdate: state.lastProgressUpdate,
            isPlaying: state.isPlaying,
            nowPlayingMID: state.nowPlaying.mid,
            onSeek: onSeek
        )
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, state.playbackDuration > 0 ? DS.Spacing.sm : 0)
    }
}
