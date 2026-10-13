import Testing
@testable import Neos

@Suite("ImageURLUpscaler Tests")
struct ImageURLUpscalerTests {

    // MARK: - Tidal

    @Test func tidalURLUpgradesToHighRes() {
        let input = "https://resources.tidal.com/images/abc123/160x160.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == "https://resources.tidal.com/images/abc123/1280x1280.jpg")
    }

    @Test func tidalWimpURLUpgradesToHighRes() {
        let input = "https://resources.wimpmusic.com/images/abc123/320x320.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == "https://resources.wimpmusic.com/images/abc123/1280x1280.jpg")
    }

    @Test func tidalHTTPUpgradedToHTTPS() {
        let input = "http://resources.tidal.com/images/abc123/160x160.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == "https://resources.tidal.com/images/abc123/1280x1280.jpg")
    }

    // MARK: - Deezer

    @Test func deezerURLUpgradesToHighRes() {
        let input = "https://cdns-images.dzcdn.net/images/cover/abc123/250x250-000000-80-0-0.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == "https://cdns-images.dzcdn.net/images/cover/abc123/1000x1000-000000-80-0-0.jpg")
    }

    @Test func deezerHTTPUpgradedToHTTPS() {
        let input = "http://cdns-images.dzcdn.net/images/cover/abc123/120x120-000000-80-0-0.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == "https://cdns-images.dzcdn.net/images/cover/abc123/1000x1000-000000-80-0-0.jpg")
    }

    @Test func deezerSimpleDimensionURLUpgradesToHighRes() {
        let input = "https://cdns-images.dzcdn.net/images/cover/abc123/264x264.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == "https://cdns-images.dzcdn.net/images/cover/abc123/1000x1000.jpg")
    }

    @Test func deezerAlreadyHighResReturnsNil() {
        let input = "https://cdns-images.dzcdn.net/images/cover/abc123/1000x1000.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == nil)
    }

    // MARK: - Size per view

    @Test func tidalPicksTheSmallestPublishedSizeCoveringTheView() {
        let input = "https://resources.tidal.com/images/abc123/160x160.jpg"
        let result = ImageURLUpscaler.highResURL(from: input, pixels: 400)
        #expect(result == "https://resources.tidal.com/images/abc123/640x640.jpg")
    }

    @Test func tidalStopsAtItsLargestPublishedSize() {
        let input = "https://resources.tidal.com/images/abc123/160x160.jpg"
        let result = ImageURLUpscaler.highResURL(from: input, pixels: 2000)
        #expect(result == "https://resources.tidal.com/images/abc123/1280x1280.jpg")
    }

    @Test func tidalKeepsALargerSourceForASmallView() {
        let input = "https://resources.tidal.com/images/abc123/640x640.jpg"
        let result = ImageURLUpscaler.highResURL(from: input, pixels: 160)
        #expect(result == "https://resources.tidal.com/images/abc123/640x640.jpg")
    }

    @Test func tidalLegacyQueryUsesTheViewSize() {
        let input = "https://images.osl.wimpmusic.com/im/im?w=160&h=160&albumid=1"
        let result = ImageURLUpscaler.highResURL(from: input, pixels: 320)
        #expect(result == "https://images.osl.wimpmusic.com/im/im?w=320&h=320&albumid=1")
    }

    @Test func deezerUsesTheViewSize() {
        let input = "https://cdns-images.dzcdn.net/images/cover/abc123/250x250-000000-80-0-0.jpg"
        let result = ImageURLUpscaler.highResURL(from: input, pixels: 400)
        #expect(result == "https://cdns-images.dzcdn.net/images/cover/abc123/400x400-000000-80-0-0.jpg")
    }

    @Test func deezerStopsAt1000() {
        let input = "https://cdns-images.dzcdn.net/images/cover/abc123/250x250.jpg"
        let result = ImageURLUpscaler.highResURL(from: input, pixels: 1280)
        #expect(result == "https://cdns-images.dzcdn.net/images/cover/abc123/1000x1000.jpg")
    }

    @Test func deezerSourceAlreadyLargeEnoughReturnsNil() {
        let input = "https://cdns-images.dzcdn.net/images/cover/abc123/500x500-000000-80-0-0.jpg"
        let result = ImageURLUpscaler.highResURL(from: input, pixels: 320)
        #expect(result == nil)
    }

    @Test func soundCloudSmallViewGetsT300() {
        let input = "https://i1.sndcdn.com/artworks-abc123-t200x200.jpg"
        let result = ImageURLUpscaler.highResURL(from: input, pixels: 160)
        #expect(result == "https://i1.sndcdn.com/artworks-abc123-t300x300.jpg")
    }

    @Test func soundCloudLargeViewGetsT500() {
        let input = "https://i1.sndcdn.com/artworks-abc123-t200x200.jpg"
        let result = ImageURLUpscaler.highResURL(from: input, pixels: 400)
        #expect(result == "https://i1.sndcdn.com/artworks-abc123-t500x500.jpg")
    }

    @Test func soundCloudT500SourceIsKeptForASmallView() {
        let input = "https://i1.sndcdn.com/artworks-abc123-t500x500.jpg"
        let result = ImageURLUpscaler.highResURL(from: input, pixels: 160)
        #expect(result == nil)
    }

    // MARK: - Unknown / Unsupported

    @Test func unknownServiceReturnsNil() {
        let input = "https://cdn.spotify.com/images/abc.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == nil)
    }

    @Test func emptyStringReturnsNil() {
        let result = ImageURLUpscaler.highResURL(from: "")
        #expect(result == nil)
    }

    // MARK: - LAN URLs

    @Test func lanIP192IsNotUpgraded() {
        let input = "http://192.168.1.100:9000/albumart/123.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == nil)
    }

    @Test func lanIP10IsNotUpgraded() {
        let input = "http://10.0.1.50:8200/art/123.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == nil)
    }

    @Test func localHostnameIsNotUpgraded() {
        let input = "http://mynas.local:9000/icon.png"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result == nil)
    }

    // MARK: - HTTPS passthrough

    @Test func httpsURLStaysHTTPS() {
        let input = "https://resources.tidal.com/images/abc/160x160.jpg"
        let result = ImageURLUpscaler.highResURL(from: input)
        #expect(result?.hasPrefix("https://") == true)
    }

    // MARK: - Scheme upgrade for unrecognized hosts

    @Test func unknownHostKeepsItsHTTPSUpgrade() {
        // App Transport Security blocks plaintext http, and station artwork rarely
        // lives on a service the upscaler recognizes.
        #expect(ImageURLUpscaler.httpsURL("http://art.example.com/wefunk.jpg")
            == "https://art.example.com/wefunk.jpg")
    }

    @Test func httpsURLLeavesTheLocalNetworkAlone() {
        #expect(ImageURLUpscaler.httpsURL("http://192.168.8.219:8200/art.jpg")
            == "http://192.168.8.219:8200/art.jpg")
        #expect(ImageURLUpscaler.httpsURL("http://mynas.local:9000/icon.png")
            == "http://mynas.local:9000/icon.png")
    }
}
