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
}
