import Testing
@testable import NeosDomain

@Suite("ServiceCapabilities")
struct ServiceCapabilitiesTests {

    // MARK: - init(from:) detection

    @Test("init from criteria with Album sets canBrowseAlbums true")
    func testAlbumCriteriaDetected() {
        let criteria = [SearchCriteria(scid: 1, name: "Album")]
        let caps = ServiceCapabilities(from: criteria)
        #expect(caps.canBrowseAlbums == true)
    }

    @Test("init from criteria with Artist sets canBrowseArtists true")
    func testArtistCriteriaDetected() {
        let criteria = [SearchCriteria(scid: 2, name: "Artist")]
        let caps = ServiceCapabilities(from: criteria)
        #expect(caps.canBrowseArtists == true)
    }

    @Test("init from criteria with Albums (plural) sets canBrowseAlbums true via case-insensitive match")
    func testAlbumsPluralDetected() {
        let criteria = [SearchCriteria(scid: 3, name: "Albums")]
        let caps = ServiceCapabilities(from: criteria)
        #expect(caps.canBrowseAlbums == true)
    }

    @Test("init from criteria without Album or Artist returns both false")
    func testUnrelatedCriteria() {
        let criteria = [
            SearchCriteria(scid: 4, name: "Track"),
            SearchCriteria(scid: 5, name: "Playlist")
        ]
        let caps = ServiceCapabilities(from: criteria)
        #expect(caps.canBrowseAlbums == false)
        #expect(caps.canBrowseArtists == false)
    }

    @Test("init from empty criteria returns both false")
    func testEmptyCriteria() {
        let caps = ServiceCapabilities(from: [])
        #expect(caps.canBrowseAlbums == false)
        #expect(caps.canBrowseArtists == false)
    }

    // MARK: - Default init

    @Test("default init creates both capabilities as false")
    func testDefaultInit() {
        let caps = ServiceCapabilities()
        #expect(caps.canBrowseAlbums == false)
        #expect(caps.canBrowseArtists == false)
    }

    // MARK: - Equatable

    @Test("Equatable conformance works correctly")
    func testEquatable() {
        let a = ServiceCapabilities(canBrowseAlbums: true, canBrowseArtists: false)
        let b = ServiceCapabilities(canBrowseAlbums: true, canBrowseArtists: false)
        let c = ServiceCapabilities(canBrowseAlbums: false, canBrowseArtists: true)
        #expect(a == b)
        #expect(a != c)
    }
}
