import Testing
@testable import NeosDomain

@Suite("NeosDomain Models")
struct NeosDomainTests {

    @Test("Player id equals pid")
    func testPlayerIdEqualsPid() {
        let player = Player(pid: 42, name: "Living Room")
        #expect(player.id == 42)
        #expect(player.name == "Living Room")
    }

    @Test("TrackMetadata qualityDescription formats correctly")
    func testQualityDescription() {
        let metadata = TrackMetadata(
            sampleRate: 96000,
            bitDepth: 24,
            codec: "FLAC"
        )
        #expect(metadata.qualityDescription == "24-bit / 96 kHz FLAC")
    }

    @Test("TrackMetadata qualityDescription returns nil when no quality info")
    func testQualityDescriptionNil() {
        let metadata = TrackMetadata(genre: "Jazz")
        #expect(metadata.qualityDescription == nil)
    }

    @Test("ConnectionState has all expected cases")
    func testConnectionStateCases() {
        let states: [ConnectionState] = [.disconnected, .connecting, .connected, .reconnecting]
        #expect(states.count == 4)
    }
}
