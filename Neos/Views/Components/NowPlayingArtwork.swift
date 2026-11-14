import SwiftUI

/// The now-playing artwork as the player shows it, and the colours drawn from it.
@MainActor
struct NowPlayingArtwork {
    let state: AppState

    var resolvedURL: String {
        state.resolvedImageURL(forMID: state.nowPlaying.mid, originalURL: state.nowPlaying.imageURL)
    }

    /// The artwork already known to load: what the player bar shows.
    var baseURL: URL? {
        guard !resolvedURL.isEmpty else { return nil }
        return URL(string: resolvedURL)
    }

    /// The track's own artwork, an upgrade over `baseURL` because it may fail to load.
    var trackURL: URL? {
        // A custom image is a deliberate choice; the track's own art must not replace it.
        if state.hasCustomStationImage(forMID: state.nowPlaying.mid) { return nil }
        let rawURL: String? = {
            if let uri = state.trackMetadata?.albumArtURI, !uri.isEmpty { return uri }
            if !resolvedURL.isEmpty { return resolvedURL }
            return nil
        }()
        guard let rawURL else { return nil }
        let resolved = ImageURLUpscaler.highResURL(from: rawURL) ?? ImageURLUpscaler.httpsURL(rawURL)
        return URL(string: resolved)
    }

    func updateColors() async {
        guard let url = trackURL else {
            withAnimation(.easeInOut(duration: 0.5)) {
                state.canvasDominantColors = DominantColorExtractor.defaultColors
            }
            return
        }

        // Same order as the view: the track's own image, then the one that always loads.
        var artwork: PlatformImage?
        for candidate in [url, baseURL].compactMap({ $0 }) {
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

extension View {
    /// Keeps `canvasDominantColors` in step with the track while this view is on screen.
    func tracksArtworkColors(_ state: AppState) -> some View {
        let artwork = NowPlayingArtwork(state: state)
        return task(id: artwork.resolvedURL) { await artwork.updateColors() }
    }
}
