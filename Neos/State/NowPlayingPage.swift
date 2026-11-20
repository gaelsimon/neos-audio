import Foundation
import NeosDomain

/// The artist or the album of what plays, as a page the player can open.
enum NowPlayingPage: Equatable {
    case artist
    case album
}

extension AppState {
    /// Only a service that can browse artists or albums finds one by name.
    func canOpen(_ page: NowPlayingPage) -> Bool {
        guard let sid = nowPlaying.sid, let capabilities = serviceCapabilities[sid] else { return false }
        switch page {
        case .artist: return isLinkableArtist(nowPlaying.artist) && capabilities.canBrowseArtists
        case .album: return !nowPlaying.album.isEmpty && capabilities.canBrowseAlbums
        }
    }
}

extension BrowseViewModel {
    func open(_ page: NowPlayingPage) {
        guard let sid = state.nowPlaying.sid else { return }
        switch page {
        case .artist:
            pushArtistSearchNavigate(sid: sid, artistName: state.nowPlaying.artist)
        case .album:
            pushAlbumSearchNavigate(sid: sid, albumName: state.nowPlaying.album, artistHint: state.nowPlaying.artist)
        }
    }
}
