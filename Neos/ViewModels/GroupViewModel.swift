import Foundation
import NeosDomain

@Observable
@MainActor
final class GroupViewModel {
    private let service: any AudioService
    private let state: AppState
    private let groupVolumeTask = CancellableTaskHandle()
    @ObservationIgnored private var memberVolumeTasks: [Int: CancellableTaskHandle] = [:]
    private let memberVolumesLoadTask = CancellableTaskHandle()
    private let loadGroupsTask = CancellableTaskHandle()
    private let createGroupTask = CancellableTaskHandle()
    private let ungroupTask = CancellableTaskHandle()
    private let groupsTracker = RequestTracker()

    var selectedMemberPIDs: Set<Int> = []
    private(set) var isLoadingGroups = false
    private(set) var isCreatingGroup = false
    private(set) var isUngrouping = false

    /// The amp often fails or times out set_group while the group forms anyway; it settles within a second.
    private let groupSettleDelay: Duration

    init(service: any AudioService, state: AppState, groupSettleDelay: Duration = .seconds(1)) {
        self.service = service
        self.state = state
        self.groupSettleDelay = groupSettleDelay
    }

    func loadGroups() {
        let requestID = groupsTracker.next()
        isLoadingGroups = true
        loadGroupsTask.replace(with: Task {
            do {
                let groups = try await service.getGroups()
                guard groupsTracker.isCurrent(requestID), !Task.isCancelled else { return }
                state.groups = groups
            } catch {
                guard groupsTracker.isCurrent(requestID), !Task.isCancelled else { return }
                state.error = .groupFailed(error.localizedDescription)
            }
            guard groupsTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isLoadingGroups = false
        })
    }

    /// Re-reads players and groups from the device: the escape hatch when a speaker came back or a
    /// pair broke up and the device never said so.
    func refresh() {
        let requestID = groupsTracker.next()
        isLoadingGroups = true
        loadGroupsTask.replace(with: Task {
            do {
                try await service.refreshSpeakers()
            } catch {
                guard groupsTracker.isCurrent(requestID), !Task.isCancelled else { return }
                state.error = .groupFailed(error.localizedDescription)
            }
            guard groupsTracker.isCurrent(requestID), !Task.isCancelled else { return }
            isLoadingGroups = false
        })
    }

    func createGroup(leaderPID: Int) {
        let memberPIDs = Array(selectedMemberPIDs.filter { $0 != leaderPID })
        guard !memberPIDs.isEmpty else { return }
        isCreatingGroup = true
        createGroupTask.replace(with: Task {
            do {
                try await service.createGroup(leaderPID: leaderPID, memberPIDs: memberPIDs)
                guard !Task.isCancelled else { return }
                selectedMemberPIDs = []
                loadGroups()
            } catch {
                guard !Task.isCancelled else { return }
                if await groupsAfterSettling().contains(where: { $0.leads(leaderPID, over: memberPIDs) }) {
                    selectedMemberPIDs = []
                } else {
                    state.error = .groupFailed(error.localizedDescription)
                }
            }
            guard !Task.isCancelled else { return }
            isCreatingGroup = false
        })
    }

    func ungroup(pid: Int) {
        isUngrouping = true
        ungroupTask.replace(with: Task {
            do {
                try await service.ungroup(pid: pid)
                guard !Task.isCancelled else { return }
                loadGroups()
            } catch {
                guard !Task.isCancelled else { return }
                if await groupsAfterSettling().contains(where: { $0.leader?.pid == pid }) {
                    state.error = .groupFailed(error.localizedDescription)
                }
            }
            guard !Task.isCancelled else { return }
            isUngrouping = false
        })
    }

    /// Re-reads the groups once the amp has had time to apply a set_group it did not acknowledge.
    private func groupsAfterSettling() async -> [SpeakerGroup] {
        try? await Task.sleep(for: groupSettleDelay)
        guard !Task.isCancelled, let groups = try? await service.getGroups() else { return state.groups }
        state.groups = groups
        return groups
    }

    func setGroupVolume(gid: Int, level: Int) {
        groupVolumeTask.replace(with: Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            do {
                try await service.setGroupVolume(gid: gid, level: level)
            } catch {
                state.error = .groupFailed(error.localizedDescription)
            }
        })
    }

    /// Sets one speaker's volume, debounced per speaker so sliders never cancel each other.
    func setMemberVolume(pid: Int, level: Int) {
        let handle = memberVolumeTasks[pid] ?? CancellableTaskHandle()
        memberVolumeTasks[pid] = handle
        handle.replace(with: Task {
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            do {
                try await service.setVolume(pid: pid, level: level)
            } catch {
                state.error = .groupFailed(error.localizedDescription)
            }
        })
    }

    /// Fetches each member's current volume for the sliders.
    func loadMemberVolumes(for group: SpeakerGroup) {
        memberVolumesLoadTask.replace(with: Task {
            for player in group.players {
                guard !Task.isCancelled else { return }
                if let level = try? await service.getVolume(pid: player.pid) {
                    guard !Task.isCancelled else { return }
                    state.setPlayerVolume(pid: player.pid, level: level)
                }
            }
        })
    }

    func setAdjustingMemberVolume(pid: Int, _ adjusting: Bool) {
        state.setAdjustingVolume(pid: pid, adjusting)
    }
}

private extension SpeakerGroup {
    func leads(_ leaderPID: Int, over memberPIDs: [Int]) -> Bool {
        leader?.pid == leaderPID && memberPIDs.allSatisfy { pid in players.contains { $0.pid == pid } }
    }
}
