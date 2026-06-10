import Testing
import Foundation
@testable import HEOSKit

@Suite("HEOSResponseParser Tests")
struct HEOSResponseParserTests {
    let parser = HEOSResponseParser()

    // MARK: - Basic Parsing

    @Test func parseSuccessResponse() throws {
        let json = """
        {"heos":{"command":"player/get_play_state","result":"success","message":"pid=123&state=play"}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        #expect(response.command == "player/get_play_state")
        #expect(response.result == .success)
        #expect(response.message["pid"] == "123")
        #expect(response.message["state"] == "play")
        #expect(response.isSuccess)
    }

    @Test func parseFailureThrowsHEOSError() {
        let json = """
        {"heos":{"command":"player/set_volume","result":"fail","message":"eid=2&text=Invalid ID"}}
        """
        #expect(throws: HEOSError.self) {
            try parser.parse(Data(json.utf8))
        }
    }

    @Test func parseEvent() throws {
        let json = """
        {"heos":{"command":"event/player_state_changed","message":"pid=123&state=pause"}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .event(let event) = result else {
            Issue.record("Expected event")
            return
        }
        #expect(event.command == "event/player_state_changed")
        #expect(event.eventName == "player_state_changed")
        #expect(event.message["state"] == "pause")
    }

    @Test func parseInvalidJSON() {
        let data = Data("not json".utf8)
        #expect(throws: (any Error).self) {
            try parser.parse(data)
        }
    }

    @Test func parseMissingHEOSBlock() {
        let json = """
        {"other":"data"}
        """
        #expect(throws: HEOSParseError.self) {
            try parser.parse(Data(json.utf8))
        }
    }

    // MARK: - Payload Parsing

    @Test func parsePlayers() throws {
        let json = """
        {"heos":{"command":"player/get_players","result":"success","message":""},\
        "payload":[{"name":"Living Room","pid":123,"model":"HEOS 1","version":"1.520.200",\
        "ip":"192.168.1.100","network":"wifi","lineout":0,"serial":"ABC123"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }

        let players = parser.parsePlayers(response)
        #expect(players.count == 1)
        #expect(players[0].pid == 123)
        #expect(players[0].name == "Living Room")
        #expect(players[0].model == "HEOS 1")
        #expect(players[0].ip == "192.168.1.100")
        #expect(players[0].network == .wifi)
    }

    @Test func parseMultiplePlayers() throws {
        let json = """
        {"heos":{"command":"player/get_players","result":"success","message":""},\
        "payload":[{"name":"Living Room","pid":100,"model":"HEOS 1","version":"1.0",\
        "ip":"192.168.1.10","network":"wifi","lineout":0,"serial":"S1"},\
        {"name":"Kitchen","pid":200,"model":"HEOS 3","version":"1.0",\
        "ip":"192.168.1.20","network":"wired","lineout":1,"serial":"S2","gid":100}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }

        let players = parser.parsePlayers(response)
        #expect(players.count == 2)
        #expect(players[1].name == "Kitchen")
        #expect(players[1].network == .wired)
        #expect(players[1].gid == 100)
    }

    @Test func parseGroups() throws {
        let json = """
        {"heos":{"command":"group/get_groups","result":"success","message":""},\
        "payload":[{"name":"Group 1","gid":100,\
        "players":[{"name":"Leader","pid":111,"role":"leader"},\
        {"name":"Member","pid":222,"role":"member"}]}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }

        let groups = parser.parseGroups(response)
        #expect(groups.count == 1)
        #expect(groups[0].name == "Group 1")
        #expect(groups[0].gid == 100)
        #expect(groups[0].players.count == 2)
        #expect(groups[0].leader?.pid == 111)
        #expect(groups[0].members.count == 1)
        #expect(groups[0].members[0].pid == 222)
    }

    @Test func parseNowPlayingMedia() throws {
        let json = """
        {"heos":{"command":"player/get_now_playing_media","result":"success","message":"pid=123"},\
        "payload":{"type":"song","song":"Test Song","album":"Test Album","artist":"Test Artist",\
        "image_url":"http://example.com/img.jpg","album_id":"a1","mid":"m1","qid":5,"sid":100}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }

        let media = parser.parseNowPlayingMedia(response)
        #expect(media.song == "Test Song")
        #expect(media.album == "Test Album")
        #expect(media.artist == "Test Artist")
        #expect(media.imageURL == "https://example.com/img.jpg")
        #expect(media.qid == 5)
        #expect(media.type == .song)
    }

    @Test func parseQueueItems() throws {
        let json = """
        {"heos":{"command":"player/get_queue","result":"success","message":"pid=123"},\
        "payload":[{"qid":1,"song":"Song 1","album":"Album","artist":"Artist",\
        "image_url":"http://img1.jpg","mid":"m1","album_id":"a1"},\
        {"qid":2,"song":"Song 2","album":"Album","artist":"Artist",\
        "image_url":"http://img2.jpg","mid":"m2","album_id":"a2"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }

        let items = parser.parseQueueItems(response)
        #expect(items.count == 2)
        #expect(items[0].qid == 1)
        #expect(items[0].song == "Song 1")
        #expect(items[1].qid == 2)
    }

    @Test func parseMusicSources() throws {
        let json = """
        {"heos":{"command":"browse/get_music_sources","result":"success","message":""},\
        "payload":[{"sid":1,"name":"Pandora","image_url":"http://pandora.jpg","type":"music_service","available":"true"},\
        {"sid":2,"name":"TuneIn","image_url":"http://tunein.jpg","type":"music_service","available":"false"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }

        let sources = parser.parseMusicSources(response)
        #expect(sources.count == 2)
        #expect(sources[0].name == "Pandora")
        #expect(sources[0].available == true)
        #expect(sources[1].name == "TuneIn")
        #expect(sources[1].available == false)
    }

    @Test func parseBrowseItems() throws {
        let json = """
        {"heos":{"command":"browse/browse","result":"success","message":"sid=1028"},\
        "payload":[{"name":"My Playlist","image_url":"http://img.jpg","type":"playlist",\
        "cid":"p1","playable":"yes","container":"yes"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }

        let items = parser.parseBrowseItems(response)
        #expect(items.count == 1)
        #expect(items[0].name == "My Playlist")
        #expect(items[0].playable == true)
        #expect(items[0].browsable == true)
        #expect(items[0].cid == "p1")
    }

    @Test func parseBrowseItemsWithAlbum() throws {
        let json = """
        {"heos":{"command":"browse/browse","result":"success","message":"sid=1028"},\
        "payload":[{"name":"Test Song","image_url":"http://img.jpg","type":"song",\
        "mid":"m1","playable":"yes","container":"no","artist":"Test Artist","album":"Test Album"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }

        let items = parser.parseBrowseItems(response)
        #expect(items.count == 1)
        #expect(items[0].album == "Test Album")
        #expect(items[0].artist == "Test Artist")
    }

    @Test func parseBrowseItemsWithoutAlbum() throws {
        let json = """
        {"heos":{"command":"browse/browse","result":"success","message":"sid=1028"},\
        "payload":[{"name":"My Playlist","image_url":"http://img.jpg","type":"playlist",\
        "cid":"p1","playable":"yes","container":"yes"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }

        let items = parser.parseBrowseItems(response)
        #expect(items.count == 1)
        #expect(items[0].album == nil)
    }

    @Test func parsePlayerWithUnknownNetwork() throws {
        let json = """
        {"heos":{"command":"player/get_players","result":"success","message":""},\
        "payload":[{"name":"External","pid":99,"model":"Controller","version":"1.0",\
        "ip":"192.168.1.50","network":"unknown","lineout":0,"serial":"EXT1"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        let players = parser.parsePlayers(response)
        #expect(players[0].network == .unknown)
    }

    @Test func parsePlayerWithControlField() throws {
        let json = """
        {"heos":{"command":"player/get_players","result":"success","message":""},\
        "payload":[{"name":"Amp","pid":50,"model":"HEOS Amp","version":"1.0",\
        "ip":"192.168.1.60","network":"wired","lineout":2,"serial":"AMP1","control":3}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        let players = parser.parsePlayers(response)
        #expect(players[0].control == 3)
        #expect(players[0].lineout == 2)
    }

    @Test func parseMusicSourceWithServiceUsername() throws {
        let json = """
        {"heos":{"command":"browse/get_music_sources","result":"success","message":""},\
        "payload":[{"sid":5,"name":"Spotify","image_url":"http://spotify.jpg",\
        "type":"music_service","available":"true","service_username":"user@example.com"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        let sources = parser.parseMusicSources(response)
        #expect(sources[0].serviceUsername == "user@example.com")
    }

    @Test func parseBrowseResultWithPagination() throws {
        let json = """
        {"heos":{"command":"browse/browse","result":"success",\
        "message":"sid=1028&returned=5&count=20"},\
        "payload":[{"name":"Track 1","image_url":"","type":"song","mid":"m1","playable":"yes","container":"no"}],\
        "options":[{"browse":[{"id":20,"name":"Remove from HEOS Favorites"}]}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        let browseResult = parser.parseBrowseResult(response)
        #expect(browseResult.items.count == 1)
        #expect(browseResult.returned == 5)
        #expect(browseResult.count == 20)
        #expect(!browseResult.options.isEmpty)
        #expect(browseResult.options[0].context == .browse)
        #expect(browseResult.options[0].id == ServiceOption.removeFromFavoritesID)
        #expect(browseResult.options[0].name == "Remove from HEOS Favorites")
    }

    @Test func parseBrowseResultWithoutPagination() throws {
        let json = """
        {"heos":{"command":"browse/browse","result":"success","message":"sid=1028"},\
        "payload":[{"name":"Track 1","image_url":"","type":"song","mid":"m1","playable":"yes","container":"no"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        let browseResult = parser.parseBrowseResult(response)
        #expect(browseResult.items.count == 1)
        #expect(browseResult.returned == nil)
        #expect(browseResult.count == nil)
        #expect(browseResult.options.isEmpty)
    }

    @Test func parsePlayerWithUnrecognizedNetworkFallsToUnknown() throws {
        let json = """
        {"heos":{"command":"player/get_players","result":"success","message":""},\
        "payload":[{"name":"Future","pid":77,"model":"HEOS X","version":"2.0",\
        "ip":"192.168.1.70","network":"bluetooth","lineout":0,"serial":"FUT1"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        let players = parser.parsePlayers(response)
        #expect(players[0].network == .unknown)
    }

    // MARK: - Edge Cases

    @Test func parseEmptyPayload() throws {
        let json = """
        {"heos":{"command":"player/clear_queue","result":"success","message":"pid=123"}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        #expect(response.payloadArray.isEmpty)
    }

    @Test func parseResponseWithNoMessage() throws {
        let json = """
        {"heos":{"command":"player/get_players","result":"success","message":""}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        #expect(response.message.isEmpty)
    }

    @Test func parseUnderProcessMessage() throws {
        // Per spec 3.2: message is literal "command under process" (no = delimiter),
        // so the message parser stores it as a key with empty value
        let json = """
        {"heos":{"command":"browse/browse","result":"success","message":"command under process"}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        #expect(response.isUnderProcess)
    }

    @Test func normalResponseIsNotUnderProcess() throws {
        let json = """
        {"heos":{"command":"player/get_players","result":"success","message":"pid=123"}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else {
            Issue.record("Expected response")
            return
        }
        #expect(!response.isUnderProcess)
    }

    @Test func parseEventWithPID() throws {
        let json = """
        {"heos":{"command":"event/player_volume_changed","message":"pid=456&level=50&mute=off"}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .event(let event) = result else {
            Issue.record("Expected event")
            return
        }
        #expect(event.eventName == "player_volume_changed")
        #expect(event.message["pid"] == "456")
        #expect(event.message["level"] == "50")
        #expect(event.message["mute"] == "off")
    }

    @Test func parsePlaybackErrorEvent() throws {
        let json = """
        {"heos":{"command":"event/player_playback_error","message":"pid=123&error=Could Not Download"}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .event(let event) = result else {
            Issue.record("Expected event")
            return
        }
        #expect(event.eventName == "player_playback_error")
        #expect(event.message["pid"] == "123")
        #expect(event.message["error"] == "Could Not Download")
    }

    @Test func parseGroupVolumeChangedEvent() throws {
        let json = """
        {"heos":{"command":"event/group_volume_changed","message":"gid=789&level=30&mute=on"}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .event(let event) = result else {
            Issue.record("Expected event")
            return
        }
        #expect(event.eventName == "group_volume_changed")
        #expect(event.message["gid"] == "789")
        #expect(event.message["level"] == "30")
        #expect(event.message["mute"] == "on")
    }

    // MARK: - HTTPS Upgrade

    // MARK: - HEOS Text Decoding

    @Test func browseItemDecodesPercentEncodedName() throws {
        let json = """
        {"heos":{"command":"browse/browse","result":"success","message":"sid=1028"},\
        "payload":[{"name":"Hip-Hop %26 R%26B","image_url":"http://img.jpg","type":"playlist",\
        "cid":"p1","playable":"yes","container":"yes"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let items = parser.parseBrowseItems(response)
        #expect(items[0].name == "Hip-Hop & R&B")
    }

    @Test func browseItemDecodesArtistAndAlbum() throws {
        let json = """
        {"heos":{"command":"browse/browse","result":"success","message":"sid=1028"},\
        "payload":[{"name":"Track","image_url":"","type":"song","mid":"m1","playable":"yes",\
        "container":"no","artist":"Rock %26 Roll","album":"Greatest %3D Best"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let items = parser.parseBrowseItems(response)
        #expect(items[0].artist == "Rock & Roll")
        #expect(items[0].album == "Greatest = Best")
    }

    @Test func nowPlayingDecodesAllTextFields() throws {
        let json = """
        {"heos":{"command":"player/get_now_playing_media","result":"success","message":"pid=1"},\
        "payload":{"type":"station","song":"Rock %26 Roll","album":"100%25 Hits",\
        "artist":"AC%2FDC","image_url":"https://img.jpg","album_id":"a1","mid":"m1",\
        "qid":1,"sid":100,"station":"Rock %26 Pop Radio"}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let media = parser.parseNowPlayingMedia(response)
        #expect(media.song == "Rock & Roll")
        #expect(media.album == "100% Hits")
        #expect(media.station == "Rock & Pop Radio")
    }

    @Test func queueItemsDecodeEncodedFields() throws {
        let json = """
        {"heos":{"command":"player/get_queue","result":"success","message":"pid=1"},\
        "payload":[{"qid":1,"song":"R%26B Jam","album":"Top %26 Best","artist":"DJ %26 MC",\
        "image_url":"https://img.jpg","mid":"m1","album_id":"a1"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let items = parser.parseQueueItems(response)
        #expect(items[0].song == "R&B Jam")
        #expect(items[0].album == "Top & Best")
        #expect(items[0].artist == "DJ & MC")
    }

    @Test func doubleEncodeProducesLiteralPercent26() throws {
        // %2526 → first pass: %25→% gives %26, then %26→& would double-decode.
        // But because %25 is decoded LAST, %2526 → %26 (literal), not &
        let json = """
        {"heos":{"command":"browse/browse","result":"success","message":"sid=1028"},\
        "payload":[{"name":"100%2526 Pure","image_url":"","type":"song","mid":"m1",\
        "playable":"yes","container":"no"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let items = parser.parseBrowseItems(response)
        #expect(items[0].name == "100%26 Pure")
    }

    @Test func playerNameDecodesEncoding() throws {
        let json = """
        {"heos":{"command":"player/get_players","result":"success","message":""},\
        "payload":[{"name":"Tom %26 Jerry%27s Room","pid":1,"model":"HEOS 1","version":"1.0",\
        "ip":"192.168.1.10","network":"wifi","lineout":0,"serial":"S1"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let players = parser.parsePlayers(response)
        #expect(players[0].name == "Tom & Jerry%27s Room")
    }

    @Test func musicSourceDecodesNameAndUsername() throws {
        let json = """
        {"heos":{"command":"browse/get_music_sources","result":"success","message":""},\
        "payload":[{"sid":1,"name":"Rock %26 Pop","image_url":"https://img.jpg",\
        "type":"music_service","available":"true","service_username":"user%3Dtest"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let sources = parser.parseMusicSources(response)
        #expect(sources[0].name == "Rock & Pop")
        #expect(sources[0].serviceUsername == "user=test")
    }

    @Test func plainTextPassesThroughUnchanged() throws {
        let json = """
        {"heos":{"command":"browse/browse","result":"success","message":"sid=1028"},\
        "payload":[{"name":"Normal Playlist Name","image_url":"","type":"playlist",\
        "cid":"p1","playable":"yes","container":"yes"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let items = parser.parseBrowseItems(response)
        #expect(items[0].name == "Normal Playlist Name")
    }

    @Test func testUpgradeToHTTPSPreservesLANIP192() throws {
        let json = """
        {"heos":{"command":"player/get_now_playing_media","result":"success","message":"pid=1"},\
        "payload":{"type":"song","song":"NAS Track","album":"NAS Album","artist":"NAS Artist",\
        "image_url":"http://192.168.1.100:9000/albumart/123.jpg","album_id":"","mid":"m1","qid":1,"sid":5555}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let media = parser.parseNowPlayingMedia(response)
        #expect(media.imageURL == "http://192.168.1.100:9000/albumart/123.jpg")
    }

    @Test func testUpgradeToHTTPSPreservesLANIP10() throws {
        let json = """
        {"heos":{"command":"browse/browse","result":"success","message":"sid=5555"},\
        "payload":[{"name":"Track","image_url":"http://10.0.1.50:8200/art/123.jpg","type":"song",\
        "mid":"m1","playable":"yes","container":"no"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let items = parser.parseBrowseItems(response)
        #expect(items[0].imageURL == "http://10.0.1.50:8200/art/123.jpg")
    }

    @Test func testUpgradeToHTTPSPreservesLANIP172() throws {
        let json = """
        {"heos":{"command":"player/get_queue","result":"success","message":"pid=1"},\
        "payload":[{"qid":1,"song":"Track","album":"Album","artist":"Artist",\
        "image_url":"http://172.16.0.5:8200/art/1.jpg","mid":"m1","album_id":""}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let items = parser.parseQueueItems(response)
        #expect(items[0].imageURL == "http://172.16.0.5:8200/art/1.jpg")
    }

    @Test func testUpgradeToHTTPSPreservesLocalHostname() throws {
        let json = """
        {"heos":{"command":"browse/get_music_sources","result":"success","message":""},\
        "payload":[{"sid":5555,"name":"NAS","image_url":"http://mynas.local:9000/icon.png",\
        "type":"dlna_server","available":"true"}]}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let sources = parser.parseMusicSources(response)
        #expect(sources[0].imageURL == "http://mynas.local:9000/icon.png")
    }

    @Test func testUpgradeToHTTPSStillUpgradesCDNUrls() throws {
        let json = """
        {"heos":{"command":"player/get_now_playing_media","result":"success","message":"pid=1"},\
        "payload":{"type":"song","song":"Stream Track","album":"Album","artist":"Artist",\
        "image_url":"http://cdn.tidal.com/artwork/123.jpg","album_id":"a1","mid":"m1","qid":1,"sid":100}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let media = parser.parseNowPlayingMedia(response)
        #expect(media.imageURL == "https://cdn.tidal.com/artwork/123.jpg")
    }

    @Test func testUpgradeToHTTPSReturnsHTTPSUnchanged() throws {
        let json = """
        {"heos":{"command":"player/get_now_playing_media","result":"success","message":"pid=1"},\
        "payload":{"type":"song","song":"Track","album":"Album","artist":"Artist",\
        "image_url":"https://already.secure.com/img.jpg","album_id":"a1","mid":"m1","qid":1,"sid":100}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let media = parser.parseNowPlayingMedia(response)
        #expect(media.imageURL == "https://already.secure.com/img.jpg")
    }

    @Test func testUpgradeToHTTPSReturnsEmptyUnchanged() throws {
        let json = """
        {"heos":{"command":"player/get_now_playing_media","result":"success","message":"pid=1"},\
        "payload":{"type":"song","song":"Track","album":"Album","artist":"Artist",\
        "image_url":"","album_id":"a1","mid":"m1","qid":1,"sid":100}}
        """
        let result = try parser.parse(Data(json.utf8))
        guard case .response(let response) = result else { Issue.record("Expected response"); return }
        let media = parser.parseNowPlayingMedia(response)
        #expect(media.imageURL == "")
    }
}
