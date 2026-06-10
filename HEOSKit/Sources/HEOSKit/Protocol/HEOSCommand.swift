import Foundation

public enum HEOSCommand: Equatable, Sendable {
    // MARK: - System Commands
    case registerForChangeEvents(enable: OnOff)
    case checkAccount
    case signIn(username: String, password: String)
    case signOut
    case heartBeat
    case reboot
    case prettifyJSONResponse(enable: OnOff)

    // MARK: - Player Commands
    case getPlayers
    case getPlayerInfo(pid: Int)
    case getPlayState(pid: Int)
    case setPlayState(pid: Int, state: PlayState)
    case getNowPlayingMedia(pid: Int)
    case getVolume(pid: Int)
    case setVolume(pid: Int, level: Int)
    case volumeUp(pid: Int, step: Int = 5)
    case volumeDown(pid: Int, step: Int = 5)
    case getMute(pid: Int)
    case setMute(pid: Int, state: OnOff)
    case toggleMute(pid: Int)
    case getPlayMode(pid: Int)
    case setPlayMode(pid: Int, repeat: RepeatMode, shuffle: ShuffleMode)
    case getQueue(pid: Int, range: ClosedRange<Int>? = nil)
    case playQueueItem(pid: Int, qid: Int)
    case removeFromQueue(pid: Int, qids: [Int])
    case saveQueue(pid: Int, name: String)
    case clearQueue(pid: Int)
    case moveQueueItem(pid: Int, sourceQueueIDs: [Int], destinationQueueID: Int)
    case playNext(pid: Int)
    case playPrevious(pid: Int)
    case setQuickSelect(pid: Int, quickSelectID: Int)
    case playQuickSelect(pid: Int, quickSelectID: Int)
    case getQuickSelects(pid: Int, quickSelectID: Int? = nil)
    case checkUpdate(pid: Int)

    // MARK: - Group Commands
    case getGroups
    case getGroupInfo(gid: Int)
    case setGroup(playerIDs: [Int])
    case getGroupVolume(gid: Int)
    case setGroupVolume(gid: Int, level: Int)
    case groupVolumeUp(gid: Int, step: Int = 5)
    case groupVolumeDown(gid: Int, step: Int = 5)
    case getGroupMute(gid: Int)
    case setGroupMute(gid: Int, state: OnOff)
    case toggleGroupMute(gid: Int)

    // MARK: - Browse Commands
    case getMusicSources
    case getSourceInfo(sid: Int)
    case browseSource(sid: Int, range: ClosedRange<Int>? = nil)
    case browseSourceContainer(sid: Int, cid: String, range: ClosedRange<Int>? = nil)
    case getSearchCriteria(sid: Int)
    case search(sid: Int, searchString: String, searchCriteriaID: Int, range: ClosedRange<Int>? = nil)
    case playStation(pid: Int, sid: Int, cid: String, mid: String, name: String)
    case playPresetStation(pid: Int, preset: Int)
    case playInputSource(pid: Int, input: String, sourcePlayerID: Int? = nil)
    case playURL(pid: Int, url: String)
    case addContainerToQueue(pid: Int, sid: Int, cid: String, aid: AddCriteria)
    case addTrackToQueue(pid: Int, sid: Int, cid: String, mid: String, aid: AddCriteria)
    case renamePlaylist(sid: Int, cid: String, name: String)
    case deletePlaylist(sid: Int, cid: String)
    case retrieveMetadata(sid: Int, cid: String)
    case setServiceOption(sid: Int, option: Int, params: [String: String])

    /// The full HEOS command path (e.g. "player/get_play_state").
    /// Single source of truth; commandGroup and commandName derive from this.
    public var commandPath: String {
        switch self {
        // System
        case .registerForChangeEvents: return "system/register_for_change_events"
        case .checkAccount:            return "system/check_account"
        case .signIn:                  return "system/sign_in"
        case .signOut:                 return "system/sign_out"
        case .heartBeat:               return "system/heart_beat"
        case .reboot:                  return "system/reboot"
        case .prettifyJSONResponse:    return "system/prettify_json_response"
        // Player
        case .getPlayers:              return "player/get_players"
        case .getPlayerInfo:           return "player/get_player_info"
        case .getPlayState:            return "player/get_play_state"
        case .setPlayState:            return "player/set_play_state"
        case .getNowPlayingMedia:      return "player/get_now_playing_media"
        case .getVolume:               return "player/get_volume"
        case .setVolume:               return "player/set_volume"
        case .volumeUp:                return "player/volume_up"
        case .volumeDown:              return "player/volume_down"
        case .getMute:                 return "player/get_mute"
        case .setMute:                 return "player/set_mute"
        case .toggleMute:              return "player/toggle_mute"
        case .getPlayMode:             return "player/get_play_mode"
        case .setPlayMode:             return "player/set_play_mode"
        case .getQueue:                return "player/get_queue"
        case .playQueueItem:           return "player/play_queue"
        case .removeFromQueue:         return "player/remove_from_queue"
        case .saveQueue:               return "player/save_queue"
        case .clearQueue:              return "player/clear_queue"
        case .moveQueueItem:           return "player/move_queue_item"
        case .playNext:                return "player/play_next"
        case .playPrevious:            return "player/play_previous"
        case .setQuickSelect:          return "player/set_quickselect"
        case .playQuickSelect:         return "player/play_quickselect"
        case .getQuickSelects:         return "player/get_quickselects"
        case .checkUpdate:             return "player/check_update"
        // Group
        case .getGroups:               return "group/get_groups"
        case .getGroupInfo:            return "group/get_group_info"
        case .setGroup:                return "group/set_group"
        case .getGroupVolume:          return "group/get_volume"
        case .setGroupVolume:          return "group/set_volume"
        case .groupVolumeUp:           return "group/volume_up"
        case .groupVolumeDown:         return "group/volume_down"
        case .getGroupMute:            return "group/get_mute"
        case .setGroupMute:            return "group/set_mute"
        case .toggleGroupMute:         return "group/toggle_mute"
        // Browse
        case .getMusicSources:         return "browse/get_music_sources"
        case .getSourceInfo:           return "browse/get_source_info"
        case .browseSource,
             .browseSourceContainer:   return "browse/browse"
        case .getSearchCriteria:       return "browse/get_search_criteria"
        case .search:                  return "browse/search"
        case .playStation, .playURL:   return "browse/play_stream"
        case .playPresetStation:       return "browse/play_preset"
        case .playInputSource:         return "browse/play_input"
        case .addContainerToQueue,
             .addTrackToQueue:         return "browse/add_to_queue"
        case .renamePlaylist:          return "browse/rename_playlist"
        case .deletePlaylist:          return "browse/delete_playlist"
        case .retrieveMetadata:        return "browse/retrieve_metadata"
        case .setServiceOption:        return "browse/set_service_option"
        }
    }

    public var commandGroup: String {
        String(commandPath.prefix(while: { $0 != "/" }))
    }

    public var commandName: String {
        String(commandPath.drop(while: { $0 != "/" }).dropFirst())
    }
}
