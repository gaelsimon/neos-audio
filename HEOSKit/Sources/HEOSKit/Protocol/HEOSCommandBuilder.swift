import Foundation

public struct HEOSCommandBuilder: Sendable {
    public init() {}

    public func build(_ command: HEOSCommand) -> String {
        let base = "heos://\(command.commandPath)"
        let params = buildParameters(command)

        if params.isEmpty {
            return base + "\r\n"
        }
        return base + "?" + params + "\r\n"
    }

    /// Maps each HEOSCommand case to its query parameter pairs. Intentionally kept as a single
    /// switch statement covering all 50+ commands; splitting would fragment a linear mapping.
    private func buildParameters(_ command: HEOSCommand) -> String { // swiftlint:disable:this function_body_length
        var pairs: [(String, String)] = []

        switch command {
        // System
        case .registerForChangeEvents(let enable):
            pairs.append(("enable", enable.rawValue))
        case .checkAccount, .signOut, .heartBeat, .reboot:
            break
        case .signIn(let username, let password):
            pairs.append(("un", encode(username)))
            pairs.append(("pw", encode(password)))
        case .prettifyJSONResponse(let enable):
            pairs.append(("enable", enable.rawValue))

        // Player
        case .getPlayers:
            break
        case .getPlayerInfo(let pid):
            pairs.append(("pid", "\(pid)"))
        case .getPlayState(let pid):
            pairs.append(("pid", "\(pid)"))
        case .setPlayState(let pid, let state):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("state", state.rawValue))
        case .getNowPlayingMedia(let pid):
            pairs.append(("pid", "\(pid)"))
        case .getVolume(let pid):
            pairs.append(("pid", "\(pid)"))
        case .setVolume(let pid, let level):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("level", "\(level)"))
        case .volumeUp(let pid, let step):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("step", "\(step)"))
        case .volumeDown(let pid, let step):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("step", "\(step)"))
        case .getMute(let pid):
            pairs.append(("pid", "\(pid)"))
        case .setMute(let pid, let state):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("state", state.rawValue))
        case .toggleMute(let pid):
            pairs.append(("pid", "\(pid)"))
        case .getPlayMode(let pid):
            pairs.append(("pid", "\(pid)"))
        case .setPlayMode(let pid, let repeatMode, let shuffle):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("repeat", repeatMode.rawValue))
            pairs.append(("shuffle", shuffle.rawValue))
        case .getQueue(let pid, let range):
            pairs.append(("pid", "\(pid)"))
            if let range {
                pairs.append(("range", "\(range.lowerBound),\(range.upperBound)"))
            }
        case .playQueueItem(let pid, let qid):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("qid", "\(qid)"))
        case .removeFromQueue(let pid, let qids):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("qid", qids.map(String.init).joined(separator: ",")))
        case .saveQueue(let pid, let name):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("name", encode(name)))
        case .clearQueue(let pid):
            pairs.append(("pid", "\(pid)"))
        case .moveQueueItem(let pid, let sqids, let dqid):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("sqid", sqids.map(String.init).joined(separator: ",")))
            pairs.append(("dqid", "\(dqid)"))
        case .playNext(let pid):
            pairs.append(("pid", "\(pid)"))
        case .playPrevious(let pid):
            pairs.append(("pid", "\(pid)"))
        case .setQuickSelect(let pid, let qsid):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("id", "\(qsid)"))
        case .playQuickSelect(let pid, let qsid):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("id", "\(qsid)"))
        case .getQuickSelects(let pid, let qsid):
            pairs.append(("pid", "\(pid)"))
            if let qsid {
                pairs.append(("id", "\(qsid)"))
            }
        case .checkUpdate(let pid):
            pairs.append(("pid", "\(pid)"))

        // Group
        case .getGroups:
            break
        case .getGroupInfo(let gid):
            pairs.append(("gid", "\(gid)"))
        case .setGroup(let playerIDs):
            pairs.append(("pid", playerIDs.map(String.init).joined(separator: ",")))
        case .getGroupVolume(let gid):
            pairs.append(("gid", "\(gid)"))
        case .setGroupVolume(let gid, let level):
            pairs.append(("gid", "\(gid)"))
            pairs.append(("level", "\(level)"))
        case .groupVolumeUp(let gid, let step):
            pairs.append(("gid", "\(gid)"))
            pairs.append(("step", "\(step)"))
        case .groupVolumeDown(let gid, let step):
            pairs.append(("gid", "\(gid)"))
            pairs.append(("step", "\(step)"))
        case .getGroupMute(let gid):
            pairs.append(("gid", "\(gid)"))
        case .setGroupMute(let gid, let state):
            pairs.append(("gid", "\(gid)"))
            pairs.append(("state", state.rawValue))
        case .toggleGroupMute(let gid):
            pairs.append(("gid", "\(gid)"))

        // Browse
        case .getMusicSources:
            break
        case .getSourceInfo(let sid):
            pairs.append(("sid", "\(sid)"))
        case .browseSource(let sid, let range):
            pairs.append(("sid", "\(sid)"))
            if let range {
                pairs.append(("range", "\(range.lowerBound),\(range.upperBound)"))
            }
        case .browseSourceContainer(let sid, let cid, let range):
            pairs.append(("sid", "\(sid)"))
            pairs.append(("cid", cid))
            if let range {
                pairs.append(("range", "\(range.lowerBound),\(range.upperBound)"))
            }
        case .getSearchCriteria(let sid):
            pairs.append(("sid", "\(sid)"))
        case .search(let sid, let searchString, let scid, let range):
            pairs.append(("sid", "\(sid)"))
            pairs.append(("search", encode(searchString)))
            pairs.append(("scid", "\(scid)"))
            if let range {
                pairs.append(("range", "\(range.lowerBound),\(range.upperBound)"))
            }
        case .playStation(let pid, let sid, let cid, let mid, let name):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("sid", "\(sid)"))
            if !cid.isEmpty {
                pairs.append(("cid", cid))
            }
            pairs.append(("mid", encode(mid)))
            pairs.append(("name", encode(name)))
        case .playPresetStation(let pid, let preset):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("preset", "\(preset)"))
        case .playInputSource(let pid, let input, let spid):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("input", input))
            if let spid {
                pairs.append(("spid", "\(spid)"))
            }
        case .playURL(let pid, let url):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("url", url))
        case .addContainerToQueue(let pid, let sid, let cid, let aid):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("sid", "\(sid)"))
            pairs.append(("cid", cid))
            pairs.append(("aid", "\(aid.rawValue)"))
        case .addTrackToQueue(let pid, let sid, let cid, let mid, let aid):
            pairs.append(("pid", "\(pid)"))
            pairs.append(("sid", "\(sid)"))
            pairs.append(("cid", cid))
            pairs.append(("mid", encode(mid)))
            pairs.append(("aid", "\(aid.rawValue)"))
        case .renamePlaylist(let sid, let cid, let name):
            pairs.append(("sid", "\(sid)"))
            pairs.append(("cid", cid))
            pairs.append(("name", encode(name)))
        case .deletePlaylist(let sid, let cid):
            pairs.append(("sid", "\(sid)"))
            pairs.append(("cid", cid))
        case .retrieveMetadata(let sid, let cid):
            pairs.append(("sid", "\(sid)"))
            pairs.append(("cid", cid))
        case .setServiceOption(let sid, let option, let params):
            pairs.append(("sid", "\(sid)"))
            pairs.append(("option", "\(option)"))
            for (key, value) in params.sorted(by: { $0.key < $1.key }) {
                pairs.append((key, encode(value)))
            }
        }

        return pairs.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
    }

    private func encode(_ value: String) -> String {
        // HEOS CLI is TCP, not HTTP; only protocol delimiters need encoding.
        // Spaces and other characters must be sent literally.
        value
            .replacingOccurrences(of: "%", with: "%25")
            .replacingOccurrences(of: "&", with: "%26")
            .replacingOccurrences(of: "=", with: "%3D")
    }
}
