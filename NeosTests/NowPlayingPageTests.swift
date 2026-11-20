import XCTest
@testable import Neos
import NeosDomain

@MainActor
final class NowPlayingPageTests: XCTestCase {
    private func state(artist: String = "The Velvet Hours", album: String = "Midnight Opera",
                       capabilities: ServiceCapabilities? = ServiceCapabilities(canBrowseAlbums: true, canBrowseArtists: true)) -> AppState {
        let state = AppState()
        state.playback.nowPlaying = NowPlayingMedia(song: "Paper Lanterns", album: album, artist: artist, sid: 7)
        if let capabilities { state.setServiceCapabilities(sid: 7, capabilities: capabilities) }
        return state
    }

    func testTheArtistOpensWhenTheServiceBrowsesArtists() {
        XCTAssertTrue(state().canOpen(.artist))
    }

    func testTheAlbumOpensWhenTheServiceBrowsesAlbums() {
        XCTAssertTrue(state().canOpen(.album))
    }

    func testVariousArtistsIsNoArtistToOpen() {
        XCTAssertFalse(state(artist: "Various Artists").canOpen(.artist))
    }

    func testATrackWithoutAnAlbumHasNoAlbumToOpen() {
        XCTAssertFalse(state(album: "").canOpen(.album))
    }

    func testAServiceThatCannotBrowseAlbumsOpensNone() {
        XCTAssertFalse(state(capabilities: ServiceCapabilities(canBrowseArtists: true)).canOpen(.album))
    }

    func testAServiceNotYetDescribedOpensNothing() {
        XCTAssertFalse(state(capabilities: nil).canOpen(.artist))
    }
}
