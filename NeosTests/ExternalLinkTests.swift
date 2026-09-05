import Foundation
import Testing
import NeosDomain
@testable import Neos

@Suite("ExternalLink Tests")
struct ExternalLinkTests {

    // MARK: - Helpers

    private func webURL(_ target: ExternalLink.Target?) -> String? {
        guard case .direct(_, let web) = target else { return nil }
        return web.absoluteString
    }

    private func appURL(_ target: ExternalLink.Target?) -> String? {
        guard case .direct(let app, _) = target else { return nil }
        return app?.absoluteString
    }

    // MARK: - Service Identification

    @Test func serviceComesFromTheSourceName() {
        #expect(ExternalLink.service(sourceName: "Tidal", imageURL: "") == .tidal)
        #expect(ExternalLink.service(sourceName: "SoundCloud", imageURL: "") == .soundCloud)
        #expect(ExternalLink.service(sourceName: "Amazon", imageURL: "") == .amazonMusic)
    }

    @Test func serviceFallsBackToTheArtworkHost() {
        let host = "https://i1.sndcdn.com/artworks-000212768416-dpowdm-t500x500.jpg"
        #expect(ExternalLink.service(sourceName: nil, imageURL: host) == .soundCloud)
        #expect(ExternalLink.service(sourceName: "Favorites", imageURL: host) == .soundCloud)
    }

    @Test func tidalArtworkHostsAreRecognized() {
        let wimp = "https://resources.wimpmusic.com/images/7db2a11e/eca4/640x640.jpg"
        #expect(ExternalLink.service(sourceName: nil, imageURL: wimp) == .tidal)
    }

    @Test func unknownServiceHasNoLink() {
        let item = ExternalLink.Item(mid: "12345", imageURL: "https://example.com/cover.jpg")
        #expect(ExternalLink.target(for: item, sourceName: "Local Music") == nil)
    }

    // MARK: - Tidal

    @Test func tidalTrackPrefersTheAppAndKeepsAWebFallback() {
        let item = ExternalLink.Item(type: .song, mid: "554283506")
        let target = ExternalLink.target(for: item, sourceName: "Tidal")
        #expect(appURL(target) == "tidal://track/554283506")
        #expect(webURL(target) == "https://tidal.com/track/554283506")
    }

    @Test func tidalPlaylistUsesTheContainerUUID() {
        let item = ExternalLink.Item(type: .playlist, cid: "LIBPLAYLIST-ee1f4f8c-e176-4f27-b6d2-6c5c62c71601")
        let target = ExternalLink.target(for: item, sourceName: "Tidal")
        #expect(webURL(target) == "https://tidal.com/playlist/ee1f4f8c-e176-4f27-b6d2-6c5c62c71601")
        #expect(appURL(target) == nil)
    }

    @Test func tidalAlbumUsesThePrefixedContainer() {
        let item = ExternalLink.Item(type: .album, cid: "LIBALBUM-558208630")
        #expect(webURL(ExternalLink.target(for: item, sourceName: "Tidal")) == "https://tidal.com/album/558208630")
    }

    @Test func anUnprefixedContainerIsNotATidalAlbumID() {
        let bare = ExternalLink.Item(type: .album, cid: "558208630")
        #expect(ExternalLink.target(for: bare, sourceName: "Tidal") == nil)

        let deezerShape = ExternalLink.Item(type: .album, cid: "Albums-11745220")
        #expect(ExternalLink.target(for: deezerShape, sourceName: "Tidal") == nil)
    }

    @Test func aPlaylistContainerThatIsNotAUUIDIsRefused() {
        let item = ExternalLink.Item(type: .playlist, cid: "LIBPLAYLIST-../../evil?x=1")
        #expect(ExternalLink.target(for: item, sourceName: "Tidal") == nil)
    }

    // MARK: - Deezer

    @Test func deezerTrackAndAlbum() {
        let track = ExternalLink.Item(type: .song, mid: "11206812")
        #expect(webURL(ExternalLink.target(for: track, sourceName: "Deezer")) == "https://www.deezer.com/track/11206812")

        let album = ExternalLink.Item(type: .album, cid: "Albums-11745220")
        #expect(webURL(ExternalLink.target(for: album, sourceName: "Deezer")) == "https://www.deezer.com/album/11745220")
    }

    // MARK: - Qobuz

    @Test func qobuzTrackGoesToTheWebPlayer() {
        let item = ExternalLink.Item(type: .song, mid: "9140031")
        #expect(webURL(ExternalLink.target(for: item, sourceName: "Qobuz")) == "https://open.qobuz.com/track/9140031")
    }

    @Test func nonASCIIDigitsAreNotAnID() {
        let item = ExternalLink.Item(type: .song, mid: "٩١٤٠٠٣١")
        #expect(ExternalLink.target(for: item, sourceName: "Qobuz") == nil)
    }

    // MARK: - TuneIn

    @Test func tuneInStationAcceptsBothIDForms() {
        let slashed = ExternalLink.Item(type: .station, mid: "s/24939")
        #expect(webURL(ExternalLink.target(for: slashed, sourceName: "TuneIn")) == "https://tunein.com/radio/s24939/")

        let plain = ExternalLink.Item(type: .station, mid: "s24939")
        #expect(webURL(ExternalLink.target(for: plain, sourceName: "TuneIn")) == "https://tunein.com/radio/s24939/")
    }

    @Test func tuneInFavoriteWithoutAStationIDHasNoLink() {
        let item = ExternalLink.Item(type: .station, mid: "u32")
        #expect(ExternalLink.target(for: item, sourceName: "TuneIn") == nil)
    }

    // MARK: - SoundCloud

    @Test func soundCloudNeedsResolutionAndCarriesASearchFallback() {
        let item = ExternalLink.Item(
            type: .song,
            mid: "soundcloud:tracks:933453124",
            artist: "Soondclub",
            title: "LA FOULE REMIX"
        )
        guard case .soundCloudTrack(let id, let search) = ExternalLink.target(for: item, sourceName: "SoundCloud") else {
            Issue.record("expected a SoundCloud target")
            return
        }
        #expect(id == "933453124")
        #expect(search?.absoluteString == "https://soundcloud.com/search?q=Soondclub%20LA%20FOULE%20REMIX")
    }

    @Test func soundCloudRejectsAMediaIDThatIsNotATrack() {
        let item = ExternalLink.Item(type: .station, mid: "soundcloud:playlists:12345", title: "Mix")
        #expect(ExternalLink.target(for: item, sourceName: "SoundCloud") == nil)
    }

    /// A nameless track still resolves; only the search fallback is lost.
    @Test func soundCloudSurvivesAnItemWithNoWordsToSearchFor() {
        let item = ExternalLink.Item(type: .song, mid: "soundcloud:tracks:933453124")
        guard case .soundCloudTrack(let id, let search) = ExternalLink.target(for: item, sourceName: "SoundCloud") else {
            Issue.record("expected a SoundCloud target")
            return
        }
        #expect(id == "933453124")
        #expect(search == nil)
    }

    // MARK: - Amazon Music

    @Test func amazonPathMatchesTheKindOfASIN() {
        let track = ExternalLink.Item(type: .song, mid: "catalog/tracks/B0C9JSXGZG")
        #expect(webURL(ExternalLink.target(for: track, sourceName: "Amazon")) == "https://music.amazon.com/tracks/B0C9JSXGZG")

        let album = ExternalLink.Item(type: .album, cid: "catalog/albums/B0C9JZ5Y9T")
        #expect(webURL(ExternalLink.target(for: album, sourceName: "Amazon")) == "https://music.amazon.com/albums/B0C9JZ5Y9T")
    }

    @Test func amazonPlaylistsAreLeftAlone() {
        let item = ExternalLink.Item(type: .playlist, cid: "catalog/playlists/B0C9JZ5Y9T")
        #expect(ExternalLink.target(for: item, sourceName: "Amazon") == nil)
    }

    @Test func amazonStationIDIsNotAnASIN() {
        let item = ExternalLink.Item(type: .station, mid: "catalog/stations/A316JYMKQTS45I/#chunk")
        #expect(ExternalLink.target(for: item, sourceName: "Amazon") == nil)
    }

    // MARK: - Direct Streams

    @Test func aStreamFavoriteYieldsItsOwnURL() {
        let stream = "https://icecast.radiofrance.fr/francemusique-hifi.aac"
        let item = ExternalLink.Item(type: .station, mid: stream)
        let target = ExternalLink.target(for: item, sourceName: "Favorites")
        guard case .stream(let url) = target else {
            Issue.record("expected a stream target")
            return
        }
        #expect(url.absoluteString == stream)
        #expect(target?.isOpenable == false)
    }

    /// A recognised service wins over a title that merely looks like a URL.
    @Test func aTitleThatLooksLikeAURLDoesNotHijackARealLink() {
        let item = ExternalLink.Item(
            type: .song,
            mid: "soundcloud:tracks:933453124",
            title: "https://example.com/my-track-name"
        )
        guard case .soundCloudTrack = ExternalLink.target(for: item, sourceName: "SoundCloud") else {
            Issue.record("expected the SoundCloud target to win")
            return
        }
    }

    @Test func aFavoriteNamedByItsStreamURLAlsoYieldsAStream() {
        let stream = "https://icecast.radiofrance.fr/fip-hifi.aac"
        let item = BrowseItem(name: stream, type: .station, mid: "u32", playable: true)
        let menu = ExternalLinkMenu.make(for: item, sourceName: "Favorites")
        guard case .stream(let url) = menu?.target else {
            Issue.record("expected a stream target")
            return
        }
        #expect(url.absoluteString == stream)
        #expect(menu?.serviceName.isEmpty == true)
    }

    // MARK: - Menu Entries

    @Test func browseItemMenuNamesTheService() {
        let item = BrowseItem(
            name: "Get Lucky",
            imageURL: "https://static.qobuz.com/images/covers/87/70/0886443927087_600.jpg",
            type: .song,
            mid: "9140031",
            playable: true
        )
        let menu = ExternalLinkMenu.make(for: item, sourceName: nil)
        #expect(menu?.serviceName == "Qobuz")
        #expect(webURL(menu?.target) == "https://open.qobuz.com/track/9140031")
    }

    @Test func nowPlayingMenuResolvesTheSourceBySID() {
        let media = NowPlayingMedia(
            type: .song,
            song: "Don't Look Any Further",
            artist: "Meshell Ndegeocello",
            mid: "554283506",
            sid: 10
        )
        let sources = [MusicSource(sid: 10, name: "Tidal", type: "music_service")]
        let menu = ExternalLinkMenu.make(for: media, sources: sources)
        #expect(menu?.serviceName == "Tidal")
        #expect(appURL(menu?.target) == "tidal://track/554283506")
    }

    @Test func queueItemMenuFallsBackToItsArtwork() {
        let item = QueueItem(
            qid: 1,
            song: "Tendo",
            artist: "WONDERWHEEL Recordings",
            imageURL: "https://i1.sndcdn.com/artworks-fTRQ1iu6dzjjcqCV-oCNC8A-t500x500.jpg",
            mid: "soundcloud:tracks:2379312509"
        )
        #expect(ExternalLinkMenu.make(for: item, sourceName: nil)?.serviceName == "SoundCloud")
    }
}

@Suite("SoundCloudLinkResolver Tests")
struct SoundCloudLinkResolverTests {

    /// The `dns-prefetch` tags come first on the real page, so the match has to skip them.
    @Test func permalinkComesOutOfTheWidgetCanonicalTag() {
        let html = """
        <head><link rel="dns-prefetch" href="//api-widget.soundcloud.com">
        <link rel="dns-prefetch" href="//api.soundcloud.com">
        <link rel="canonical" href="https://soundcloud.com/senorpeludo/funk-meets-hip-hop-boomtown">
        <title>SoundCloud Widget</title></head>
        """
        let url = SoundCloudLinkResolver.permalink(fromWidgetHTML: html)
        #expect(url?.absoluteString == "https://soundcloud.com/senorpeludo/funk-meets-hip-hop-boomtown")
    }

    @Test func aCanonicalTagPointingElsewhereIsRejected() {
        let html = #"<link rel="canonical" href="https://evil.example.com/soundcloud.com/x">"#
        #expect(SoundCloudLinkResolver.permalink(fromWidgetHTML: html) == nil)
    }

    @Test func widgetPageWithoutACanonicalTagYieldsNothing() {
        #expect(SoundCloudLinkResolver.permalink(fromWidgetHTML: "<html><body>nope</body></html>") == nil)
    }
}
