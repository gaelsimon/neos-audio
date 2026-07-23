import Foundation
import NeosDomain

@Observable
@MainActor
final class GroupViewModel {
    private let service: any AudioService
    private let state: AppState
    private let groupVolumeTask = CancellableTaskHandle()
    private let memberVolumeTask = CancellableTaskHandle()
    private let memberVolumesLoadTask = CancellableTaskHandle()
    private let loadGroupsTask = CancellableTaskHandle()
    private let createGroupTask = CancellableTaskHandle()
    private let ungroupTask = CancellableTaskHandle()
    private let groupsTracker = RequestTracker()

    var selectedMemberPIDs: Set<Int> = []
    private(set) var isLoadingGroups = false
    private(set) var isCreatingGroup = false
    private(set) var isUngrouping = false

    init(service: any AudioService, state: AppState) {
        self.service = service
        self.state = state
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
                state.error = .groupFailed(error.localizedDescription)
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
                state.error = .groupFailed(error.localizedDescription)
            }
            guard !Task.isCancelled else { return }
            isUngrouping = false
        })
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

    /// Sets one speaker's volume, debounced.
    func setMemberVolume(pid: Int, level: Int) {
        memberVolumeTask.replace(with: Task {
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
