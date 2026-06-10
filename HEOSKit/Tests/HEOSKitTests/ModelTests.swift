import Testing
import Foundation
@testable import HEOSKit

@Suite("Model Tests")
struct ModelTests {

    @Test func playerIdentifiable() {
        let player = Player(pid: 42, name: "Test")
        #expect(player.id == 42)
    }

    @Test func playerEquality() {
        let p1 = Player(pid: 1, name: "A")
        let p2 = Player(pid: 1, name: "A")
        #expect(p1 == p2)
    }

    @Test func groupLeaderAndMembers() {
        let group = SpeakerGroup(gid: 1, name: "Group", players: [
            GroupPlayer(name: "Leader", pid: 10, role: .leader),
            GroupPlayer(name: "Member1", pid: 20, role: .member),
            GroupPlayer(name: "Member2", pid: 30, role: .member)
        ])
        #expect(group.leader?.pid == 10)
        #expect(group.members.count == 2)
    }

    @Test func queueItemIdentifiable() {
        let item = QueueItem(qid: 7, song: "Song")
        #expect(item.id == 7)
    }

    @Test func musicSourceIdentifiable() {
        let source = MusicSource(sid: 5, name: "Pandora")
        #expect(source.id == 5)
    }

    @Test func browseItemID() {
        let item1 = BrowseItem(name: "Track", mid: "m1")
        #expect(item1.id == "m1")

        let item2 = BrowseItem(name: "Folder", cid: "c1")
        #expect(item2.id == "c1")

        let item3 = BrowseItem(name: "Unnamed")
        #expect(item3.id == "Unnamed")
    }

    @Test func playStateRawValues() {
        #expect(PlayState.play.rawValue == "play")
        #expect(PlayState.pause.rawValue == "pause")
        #expect(PlayState.stop.rawValue == "stop")
    }

    @Test func repeatModeRawValues() {
        #expect(RepeatMode.off.rawValue == "off")
        #expect(RepeatMode.onAll.rawValue == "on_all")
        #expect(RepeatMode.onOne.rawValue == "on_one")
    }

    @Test func addCriteriaValues() {
        #expect(AddCriteria.playNow.rawValue == 1)
        #expect(AddCriteria.playNext.rawValue == 2)
        #expect(AddCriteria.addToEnd.rawValue == 3)
        #expect(AddCriteria.replaceAndPlay.rawValue == 4)
    }

    @Test func mediaTypeRawValues() {
        #expect(MediaType.song.rawValue == "song")
        #expect(MediaType.station.rawValue == "station")
        #expect(MediaType.dlnaServer.rawValue == "dlna_server")
    }

    @Test func discoveredDeviceID() {
        let device = DiscoveredDevice(host: "192.168.1.100", port: 1255)
        #expect(device.id == "192.168.1.100:1255")
    }

    @Test func heosErrorDescription() {
        let error = HEOSError(errorID: 2, text: "Invalid ID", command: "player/set_volume")
        #expect(error.description == "HEOSError(2): Invalid ID")
    }

    @Test func connectionStateValues() {
        #expect(ConnectionState.disconnected.rawValue == "disconnected")
        #expect(ConnectionState.connected.rawValue == "connected")
        #expect(ConnectionState.reconnecting.rawValue == "reconnecting")
    }

    @Test func nowPlayingMediaDefaults() {
        let media = NowPlayingMedia()
        #expect(media.song == "")
        #expect(media.type == .song)
        #expect(media.qid == nil)
    }

    @Test func networkTypeUnknown() {
        #expect(NetworkType(rawValue: "unknown") == .unknown)
        #expect(NetworkType(rawValue: "wifi") == .wifi)
        #expect(NetworkType(rawValue: "wired") == .wired)
    }

    @Test func playerControlField() {
        let player = Player(pid: 1, name: "Test", lineout: 2, control: 3)
        #expect(player.control == 3)

        let noControl = Player(pid: 2, name: "Test2")
        #expect(noControl.control == nil)
    }

    @Test func musicSourceServiceUsername() {
        let source = MusicSource(sid: 1, name: "Spotify", serviceUsername: "user@test.com")
        #expect(source.serviceUsername == "user@test.com")

        let noUsername = MusicSource(sid: 2, name: "Local")
        #expect(noUsername.serviceUsername == nil)
    }

    // MARK: - DiscoveredDevice Codable

    @Test func discoveredDeviceCodableRoundTrip() throws {
        let device = DiscoveredDevice(
            host: "192.168.8.219",
            port: 1255,
            friendlyName: "Marantz MODEL 40n",
            modelName: "MODEL 40n",
            modelNumber: "40n",
            serialNumber: "ABC123",
            location: "http://192.168.8.219:60006/upnp/desc/aios_device/aios_device.xml",
            firmwareVersion: "4.30.530",
            deviceID: "AIOS-00000001",
            networkID: "NET-001"
        )

        let data = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(DiscoveredDevice.self, from: data)

        #expect(decoded.host == device.host)
        #expect(decoded.port == device.port)
        #expect(decoded.friendlyName == device.friendlyName)
        #expect(decoded.modelName == device.modelName)
        #expect(decoded.modelNumber == device.modelNumber)
        #expect(decoded.serialNumber == device.serialNumber)
        #expect(decoded.location == device.location)
        #expect(decoded.firmwareVersion == device.firmwareVersion)
        #expect(decoded.deviceID == device.deviceID)
        #expect(decoded.networkID == device.networkID)
        #expect(decoded.id == device.id)
    }

    @Test func discoveredDeviceCodableWithDefaults() throws {
        let device = DiscoveredDevice(host: "10.0.0.5")

        let data = try JSONEncoder().encode(device)
        let decoded = try JSONDecoder().decode(DiscoveredDevice.self, from: data)

        #expect(decoded.host == "10.0.0.5")
        #expect(decoded.port == 1255)
        #expect(decoded.friendlyName == "")
        #expect(decoded.modelName == "")
        #expect(decoded.id == "10.0.0.5:1255")
    }
}
