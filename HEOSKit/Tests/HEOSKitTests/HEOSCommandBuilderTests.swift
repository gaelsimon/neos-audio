import Testing
@testable import HEOSKit

@Suite("HEOSCommandBuilder Tests")
struct HEOSCommandBuilderTests {
    let builder = HEOSCommandBuilder()

    // MARK: - System Commands

    @Test func registerForChangeEventsOn() {
        let result = builder.build(.registerForChangeEvents(enable: .on))
        #expect(result == "heos://system/register_for_change_events?enable=on\r\n")
    }

    @Test func registerForChangeEventsOff() {
        let result = builder.build(.registerForChangeEvents(enable: .off))
        #expect(result == "heos://system/register_for_change_events?enable=off\r\n")
    }

    @Test func checkAccount() {
        let result = builder.build(.checkAccount)
        #expect(result == "heos://system/check_account\r\n")
    }

    @Test func signIn() {
        let result = builder.build(.signIn(username: "user@test.com", password: "pass123"))
        #expect(result == "heos://system/sign_in?un=user@test.com&pw=pass123\r\n")
    }

    @Test func signInWithSpecialChars() {
        let result = builder.build(.signIn(username: "user&name", password: "p=ss%wd"))
        #expect(result == "heos://system/sign_in?un=user%26name&pw=p%3Dss%25wd\r\n")
    }

    @Test func signOut() {
        let result = builder.build(.signOut)
        #expect(result == "heos://system/sign_out\r\n")
    }

    @Test func heartBeat() {
        let result = builder.build(.heartBeat)
        #expect(result == "heos://system/heart_beat\r\n")
    }

    @Test func reboot() {
        let result = builder.build(.reboot)
        #expect(result == "heos://system/reboot\r\n")
    }

    // MARK: - Player Commands

    @Test func getPlayers() {
        let result = builder.build(.getPlayers)
        #expect(result == "heos://player/get_players\r\n")
    }

    @Test func getPlayerInfo() {
        let result = builder.build(.getPlayerInfo(pid: 123))
        #expect(result == "heos://player/get_player_info?pid=123\r\n")
    }

    @Test func getPlayState() {
        let result = builder.build(.getPlayState(pid: 456))
        #expect(result == "heos://player/get_play_state?pid=456\r\n")
    }

    @Test func setPlayState() {
        let result = builder.build(.setPlayState(pid: 789, state: .play))
        #expect(result == "heos://player/set_play_state?pid=789&state=play\r\n")
    }

    @Test func setPlayStatePause() {
        let result = builder.build(.setPlayState(pid: 789, state: .pause))
        #expect(result == "heos://player/set_play_state?pid=789&state=pause\r\n")
    }

    @Test func getNowPlayingMedia() {
        let result = builder.build(.getNowPlayingMedia(pid: 100))
        #expect(result == "heos://player/get_now_playing_media?pid=100\r\n")
    }

    @Test func getVolume() {
        let result = builder.build(.getVolume(pid: 100))
        #expect(result == "heos://player/get_volume?pid=100\r\n")
    }

    @Test func setVolume() {
        let result = builder.build(.setVolume(pid: 100, level: 75))
        #expect(result == "heos://player/set_volume?pid=100&level=75\r\n")
    }

    @Test func volumeUp() {
        let result = builder.build(.volumeUp(pid: 100, step: 3))
        #expect(result == "heos://player/volume_up?pid=100&step=3\r\n")
    }

    @Test func volumeDown() {
        let result = builder.build(.volumeDown(pid: 100, step: 5))
        #expect(result == "heos://player/volume_down?pid=100&step=5\r\n")
    }

    @Test func getMute() {
        let result = builder.build(.getMute(pid: 100))
        #expect(result == "heos://player/get_mute?pid=100\r\n")
    }

    @Test func setMuteOn() {
        let result = builder.build(.setMute(pid: 100, state: .on))
        #expect(result == "heos://player/set_mute?pid=100&state=on\r\n")
    }

    @Test func toggleMute() {
        let result = builder.build(.toggleMute(pid: 100))
        #expect(result == "heos://player/toggle_mute?pid=100\r\n")
    }

    @Test func setPlayMode() {
        let result = builder.build(.setPlayMode(pid: 100, repeat: .onAll, shuffle: .on))
        #expect(result == "heos://player/set_play_mode?pid=100&repeat=on_all&shuffle=on\r\n")
    }

    @Test func getQueue() {
        let result = builder.build(.getQueue(pid: 100))
        #expect(result == "heos://player/get_queue?pid=100\r\n")
    }

    @Test func getQueueWithRange() {
        let result = builder.build(.getQueue(pid: 100, range: 0...9))
        #expect(result == "heos://player/get_queue?pid=100&range=0,9\r\n")
    }

    @Test func playQueueItem() {
        let result = builder.build(.playQueueItem(pid: 100, qid: 5))
        #expect(result == "heos://player/play_queue?pid=100&qid=5\r\n")
    }

    @Test func removeFromQueue() {
        let result = builder.build(.removeFromQueue(pid: 100, qids: [1, 3, 5]))
        #expect(result == "heos://player/remove_from_queue?pid=100&qid=1,3,5\r\n")
    }

    @Test func clearQueue() {
        let result = builder.build(.clearQueue(pid: 100))
        #expect(result == "heos://player/clear_queue?pid=100\r\n")
    }

    @Test func moveQueueItemSingle() {
        let result = builder.build(.moveQueueItem(pid: 100, sourceQueueIDs: [3], destinationQueueID: 1))
        #expect(result == "heos://player/move_queue_item?pid=100&sqid=3&dqid=1\r\n")
    }

    @Test func moveQueueItemMultiple() {
        let result = builder.build(.moveQueueItem(pid: 100, sourceQueueIDs: [3, 5, 7], destinationQueueID: 1))
        #expect(result == "heos://player/move_queue_item?pid=100&sqid=3,5,7&dqid=1\r\n")
    }

    @Test func playNext() {
        let result = builder.build(.playNext(pid: 100))
        #expect(result == "heos://player/play_next?pid=100\r\n")
    }

    @Test func playPrevious() {
        let result = builder.build(.playPrevious(pid: 100))
        #expect(result == "heos://player/play_previous?pid=100\r\n")
    }

    // MARK: - Group Commands

    @Test func getGroups() {
        let result = builder.build(.getGroups)
        #expect(result == "heos://group/get_groups\r\n")
    }

    @Test func setGroup() {
        let result = builder.build(.setGroup(playerIDs: [111, 222, 333]))
        #expect(result == "heos://group/set_group?pid=111,222,333\r\n")
    }

    @Test func ungroupSinglePlayer() {
        let result = builder.build(.setGroup(playerIDs: [111]))
        #expect(result == "heos://group/set_group?pid=111\r\n")
    }

    @Test func getGroupVolume() {
        let result = builder.build(.getGroupVolume(gid: 999))
        #expect(result == "heos://group/get_volume?gid=999\r\n")
    }

    @Test func setGroupVolume() {
        let result = builder.build(.setGroupVolume(gid: 999, level: 50))
        #expect(result == "heos://group/set_volume?gid=999&level=50\r\n")
    }

    // MARK: - Browse Commands

    @Test func getMusicSources() {
        let result = builder.build(.getMusicSources)
        #expect(result == "heos://browse/get_music_sources\r\n")
    }

    @Test func browseSource() {
        let result = builder.build(.browseSource(sid: 1028))
        #expect(result == "heos://browse/browse?sid=1028\r\n")
    }

    @Test func browseSourceContainer() {
        let result = builder.build(.browseSourceContainer(sid: 5, cid: "albums"))
        #expect(result == "heos://browse/browse?sid=5&cid=albums\r\n")
    }

    @Test func search() {
        let result = builder.build(.search(sid: 2, searchString: "hello", searchCriteriaID: 1))
        #expect(result == "heos://browse/search?sid=2&search=hello&scid=1\r\n")
    }

    @Test func playPreset() {
        let result = builder.build(.playPresetStation(pid: 100, preset: 3))
        #expect(result == "heos://browse/play_preset?pid=100&preset=3\r\n")
    }

    @Test func addTrackToQueue() {
        let result = builder.build(.addTrackToQueue(pid: 100, sid: 5, cid: "album1", mid: "track1", aid: .playNow))
        #expect(result == "heos://browse/add_to_queue?pid=100&sid=5&cid=album1&mid=track1&aid=1\r\n")
    }

    @Test func addContainerToQueue() {
        let result = builder.build(.addContainerToQueue(pid: 100, sid: 5, cid: "album1", aid: .addToEnd))
        #expect(result == "heos://browse/add_to_queue?pid=100&sid=5&cid=album1&aid=3\r\n")
    }

    // MARK: - Command Properties

    @Test func systemCommandGroup() {
        #expect(HEOSCommand.heartBeat.commandGroup == "system")
        #expect(HEOSCommand.signOut.commandGroup == "system")
    }

    @Test func playerCommandGroup() {
        #expect(HEOSCommand.getPlayers.commandGroup == "player")
        #expect(HEOSCommand.playNext(pid: 1).commandGroup == "player")
    }

    @Test func groupCommandGroup() {
        #expect(HEOSCommand.getGroups.commandGroup == "group")
        #expect(HEOSCommand.setGroup(playerIDs: [1]).commandGroup == "group")
    }

    @Test func browseCommandGroup() {
        #expect(HEOSCommand.getMusicSources.commandGroup == "browse")
        #expect(HEOSCommand.browseSource(sid: 1).commandGroup == "browse")
        #expect(HEOSCommand.retrieveMetadata(sid: 1, cid: "a1").commandGroup == "browse")
        #expect(HEOSCommand.setServiceOption(sid: 1, option: 19, params: [:]).commandGroup == "browse")
    }

    @Test func retrieveMetadata() {
        let result = builder.build(.retrieveMetadata(sid: 5, cid: "album123"))
        #expect(result == "heos://browse/retrieve_metadata?sid=5&cid=album123\r\n")
    }

    @Test func setServiceOption() {
        let result = builder.build(.setServiceOption(sid: 5, option: 19, params: ["pid": "100"]))
        #expect(result == "heos://browse/set_service_option?sid=5&option=19&pid=100\r\n")
    }

    @Test func setServiceOptionMultipleParams() {
        let result = builder.build(.setServiceOption(sid: 5, option: 4, params: ["cid": "p1", "name": "My Playlist"]))
        #expect(result == "heos://browse/set_service_option?sid=5&option=4&cid=p1&name=My Playlist\r\n")
    }

    @Test func playStationWithURLMid() {
        let result = builder.build(.playStation(
            pid: 100, sid: 2, cid: "u32",
            mid: "https://icecast.radiofrance.fr/fip-hifi.aac",
            name: "FIP Radio"
        ))
        #expect(result == "heos://browse/play_stream?pid=100&sid=2&cid=u32&mid=https://icecast.radiofrance.fr/fip-hifi.aac&name=FIP Radio\r\n")
    }

    @Test func playStationSimpleMid() {
        let result = builder.build(.playStation(
            pid: 100, sid: 2, cid: "c123",
            mid: "s12345",
            name: "BBC Radio 1"
        ))
        #expect(result == "heos://browse/play_stream?pid=100&sid=2&cid=c123&mid=s12345&name=BBC Radio 1\r\n")
    }
}
