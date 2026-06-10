import Testing
import Foundation
@testable import NeosDomain

@Suite("AudioService Protocol Conformance")
struct AudioServiceProtocolTests {

    // MARK: - Type Alignment

    @Test("Player has pid and name properties")
    func testPlayerProperties() {
        let player = Player(pid: 1, name: "Kitchen")
        #expect(player.pid == 1)
        #expect(player.name == "Kitchen")
    }

    @Test("QueueItem has qid property")
    func testQueueItemProperties() {
        let item = QueueItem(qid: 5, song: "Track")
        #expect(item.qid == 5)
    }

    @Test("BrowseResult has items, count, and returned properties")
    func testBrowseResultProperties() {
        let result = BrowseResult(items: [], returned: 10, count: 50)
        #expect(result.items.isEmpty)
        #expect(result.returned == 10)
        #expect(result.count == 50)
    }

    @Test("SpeakerGroup has gid and name properties")
    func testSpeakerGroupProperties() {
        let group = SpeakerGroup(gid: 3, name: "Stereo Pair", players: [])
        #expect(group.gid == 3)
        #expect(group.name == "Stereo Pair")
    }

    @Test("MusicSource has sid and name properties")
    func testMusicSourceProperties() {
        let source = MusicSource(sid: 7, name: "Spotify")
        #expect(source.sid == 7)
        #expect(source.name == "Spotify")
    }

    @Test("PositionInfo has duration and position computed properties")
    func testPositionInfoProperties() {
        let info = PositionInfo(track: 1, trackDuration: "0:03:30", relTime: "0:01:15")
        #expect(info.duration == 210.0)
        #expect(info.position == 75.0)
    }

    @Test("DiscoveredDevice has host and friendlyName properties")
    func testDiscoveredDeviceProperties() {
        let device = DiscoveredDevice(host: "192.168.1.10", friendlyName: "HEOS Bar")
        #expect(device.host == "192.168.1.10")
        #expect(device.friendlyName == "HEOS Bar")
    }

    @Test("TrackMetadata has optional quality properties")
    func testTrackMetadataProperties() {
        let metadata = TrackMetadata(sampleRate: 44100, bitDepth: 16, codec: "FLAC")
        #expect(metadata.sampleRate == 44100)
        #expect(metadata.bitDepth == 16)
        #expect(metadata.codec == "FLAC")

        let empty = TrackMetadata()
        #expect(empty.sampleRate == nil)
        #expect(empty.bitDepth == nil)
        #expect(empty.codec == nil)
    }

    @Test("SearchCriteria has scid, name, and id properties")
    func testSearchCriteriaProperties() {
        let criteria = SearchCriteria(scid: 1, name: "Artist")
        #expect(criteria.scid == 1)
        #expect(criteria.name == "Artist")
        #expect(criteria.id == 1)
    }

    // MARK: - Enum Completeness

    @Test("PlayState has play, pause, stop cases")
    func testPlayStateCases() {
        let cases: [PlayState] = [.play, .pause, .stop]
        #expect(cases.count == 3)
    }

    @Test("RepeatMode has off, onAll, onOne cases")
    func testRepeatModeCases() {
        let cases: [RepeatMode] = [.off, .onAll, .onOne]
        #expect(cases.count == 3)
    }

    @Test("ShuffleMode has off, on cases")
    func testShuffleModeCases() {
        let cases: [ShuffleMode] = [.off, .on]
        #expect(cases.count == 2)
    }

    @Test("AddCriteria has playNow, playNext, addToEnd, replaceAndPlay cases")
    func testAddCriteriaCases() {
        let cases: [AddCriteria] = [.playNow, .playNext, .addToEnd, .replaceAndPlay]
        #expect(cases.count == 4)
    }

    @Test("ConnectionState has disconnected, connecting, connected, reconnecting cases")
    func testConnectionStateCases() {
        let cases: [ConnectionState] = [.disconnected, .connecting, .connected, .reconnecting]
        #expect(cases.count == 4)
    }
}
