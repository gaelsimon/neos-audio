import SwiftUI
import NeosDomain

struct AmpSettingsView: View {
    let state: AppState
    @Bindable var speakerVM: SpeakerListViewModel
    @Bindable var groupVM: GroupViewModel

    @State private var selectedLeaderPID: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                Text("Amp Settings")
                    .typography(.pageTitle)
                    .padding(.bottom, DS.Spacing.sm)

                playersSection
                groupsSection
                connectionSection
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.top, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.xxxl)
            .frame(maxWidth: 640, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .accessibilityIdentifier(AccessibilityID.AmpSettings.view)
        .task {
            groupVM.loadGroups()
        }
    }

    // MARK: - Section Card

    private func sectionCard<Content: View>(
        header: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(header)
                .typography(.sectionHeader)

            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                content()
            }
            .padding(DS.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.large))
        }
    }

    // MARK: - Players Section

    private var playersSection: some View {
        sectionCard(header: "Players") {
            if state.players.isEmpty {
                Text("No players found.")
                    .typography(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(state.players) { player in
                        playerRow(player)
                        if player.id != state.players.last?.id {
                            Divider().opacity(0.2)
                        }
                    }
                }
            }
        }
    }

    private func playerRow(_ player: Player) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Button {
                speakerVM.selectPlayer(player)
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: playerIcon(for: player))
                        .font(DS.IconFont.lg)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .frame(width: 24)

                    Text(player.name)
                        .typography(.bodyPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    if player.pid == state.selectedPlayerID {
                        Image(systemName: DS.Icons.checkmark)
                            .font(DS.IconFont.bodyEmphasis)
                            .foregroundStyle(DS.Colors.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                speakerVM.togglePower()
            } label: {
                Image(systemName: DS.Icons.power)
                    .font(DS.IconFont.lg)
                    .foregroundStyle(state.isPoweredOn ? DS.Colors.accent : DS.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .help(state.isPoweredOn ? "Turn Off" : "Turn On")
            .accessibilityIdentifier(AccessibilityID.AmpSettings.powerButton)
        }
        .padding(.vertical, DS.Spacing.md)
        .accessibilityIdentifier(AccessibilityID.AmpSettings.playerRow(player.pid))
        .accessibilityValue(player.pid == state.selectedPlayerID ? "selected" : "unselected")
    }

    private func playerIcon(for player: Player) -> String {
        let isGrouped = state.groups.contains { group in
            group.players.contains { $0.pid == player.pid }
        }
        return isGrouped ? DS.Icons.speakerGrouped : DS.Icons.speaker
    }

    // MARK: - Groups Section

    private var groupsSection: some View {
        sectionCard(header: "Speaker Groups") {
            existingGroupsList
            createGroupForm
        }
    }

    @ViewBuilder
    private var existingGroupsList: some View {
        if state.groups.isEmpty {
            Text("No active groups.")
                .typography(.secondary)
        } else {
            ForEach(state.groups) { group in
                groupCard(group)
            }
        }
    }

    private func groupCard(_ group: SpeakerGroup) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(group.name)
                .typography(.bodyMedium)

            ForEach(group.players, id: \.pid) { player in
                HStack(spacing: DS.Spacing.sm) {
                    if player.role == .leader {
                        Image(systemName: DS.Icons.star)
                            .font(DS.IconFont.sm)
                            .foregroundStyle(DS.Colors.accent)
                    } else {
                        Image(systemName: DS.Icons.speaker)
                            .font(DS.IconFont.sm)
                            .foregroundStyle(DS.Colors.textSecondary)
                    }
                    Text(player.name)
                        .typography(.secondary)
                    if player.role == .leader {
                        Text("(leader)")
                            .typography(.secondary)
                    }
                }
            }

            groupVolumeSlider(group)

            HStack {
                Spacer()
                Button {
                    groupVM.ungroup(pid: group.gid)
                } label: {
                    if groupVM.isUngrouping {
                        Spinner(size: 16, lineWidth: 2)
                    } else {
                        Text("Ungroup")
                            .typography(.secondary)
                            .foregroundStyle(.red)
                    }
                }
                .buttonStyle(.plain)
                .disabled(groupVM.isUngrouping)
                .accessibilityIdentifier(AccessibilityID.Group.ungroupButton(group.gid))
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Colors.surfaceContainer, in: RoundedRectangle(cornerRadius: DS.Radius.medium))
    }

    // MARK: - Group Volume Slider

    @State private var groupVolume: Double = 50
    @State private var isDraggingVolume = false

    private func groupVolumeSlider(_ group: SpeakerGroup) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: DS.Icons.speakerActive)
                .font(DS.IconFont.sm)
                .foregroundStyle(DS.Colors.textSecondary)

            GeometryReader { geo in
                let width = geo.size.width
                let fraction = groupVolume / 100

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)

                    Capsule()
                        .fill(DS.Colors.accent)
                        .frame(width: max(0, fraction * width), height: 4)
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingVolume = true
                            let clamped = max(0, min(1, value.location.x / width))
                            groupVolume = clamped * 100
                            groupVM.setGroupVolume(gid: group.gid, level: Int(groupVolume))
                        }
                        .onEnded { _ in
                            isDraggingVolume = false
                        }
                )
            }
            .frame(height: 14)

            Text("\(Int(groupVolume))")
                .typography(.secondary)
                .monospacedDigit()
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: - Create Group

    @ViewBuilder
    private var createGroupForm: some View {
        if state.players.count >= 2 {
            Divider().opacity(0.3)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Create Group")
                    .typography(.bodyMedium)

                HStack {
                    Text("Leader:")
                        .typography(.secondary)
                    Picker("", selection: leaderBinding) {
                        ForEach(state.players) { player in
                            Text(player.name).tag(player.pid)
                        }
                    }
                    .labelsHidden()
                    .accessibilityIdentifier(AccessibilityID.Group.leaderPicker)
                }

                ForEach(state.players) { player in
                    if player.pid != selectedLeaderPID {
                        Toggle(isOn: memberBinding(for: player.pid)) {
                            HStack(spacing: DS.Spacing.sm) {
                                Image(systemName: DS.Icons.speaker)
                                    .font(DS.IconFont.md)
                                    .foregroundStyle(DS.Colors.textSecondary)
                                Text(player.name)
                                    .typography(.bodyPrimary)
                            }
                        }
                        .toggleStyle(.checkbox)
                        .accessibilityIdentifier(AccessibilityID.Group.memberToggle(player.pid))
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        guard let leaderPID = selectedLeaderPID else { return }
                        groupVM.createGroup(leaderPID: leaderPID)
                    } label: {
                        if groupVM.isCreatingGroup {
                            Spinner(size: 16, lineWidth: 2)
                        } else {
                            Text("Create Group")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!canCreate || groupVM.isCreatingGroup)
                    .accessibilityIdentifier(AccessibilityID.Group.createButton)
                }
            }
        } else {
            Text("Need 2+ speakers to create groups.")
                .typography(.secondary)
                .foregroundStyle(DS.Colors.textTertiary)
                .accessibilityIdentifier(AccessibilityID.Group.emptyState)
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        sectionCard(header: "Connection") {
            if let device = state.connectedDevice {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: DS.Icons.speakerFill)
                        .font(DS.IconFont.xxxl)
                        .foregroundStyle(DS.Colors.accent)

                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(connectionDisplayName(device))
                            .typography(.bodyMedium)
                        Text(device.host)
                            .typography(.secondary)
                            .foregroundStyle(DS.Colors.textTertiary)
                    }

                    Spacer()

                    Button(action: { speakerVM.disconnect() }) {
                        Text("Disconnect")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier(AccessibilityID.Sidebar.disconnectButton)
                }
            } else {
                Text("Not connected to any device.")
                    .typography(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func connectionDisplayName(_ device: DiscoveredDevice) -> String {
        if !device.friendlyName.isEmpty, device.friendlyName != device.host {
            return device.friendlyName
        }
        return state.selectedPlayer?.name ?? device.host
    }

    private var canCreate: Bool {
        guard let leaderPID = selectedLeaderPID else { return false }
        let members = groupVM.selectedMemberPIDs.filter { $0 != leaderPID }
        return !members.isEmpty
    }

    private var leaderBinding: Binding<Int> {
        Binding(
            get: { selectedLeaderPID ?? (state.players.first?.pid ?? 0) },
            set: { newValue in
                selectedLeaderPID = newValue
                groupVM.selectedMemberPIDs.remove(newValue)
            }
        )
    }

    private func memberBinding(for pid: Int) -> Binding<Bool> {
        Binding(
            get: { groupVM.selectedMemberPIDs.contains(pid) },
            set: { isSelected in
                if isSelected {
                    groupVM.selectedMemberPIDs.insert(pid)
                } else {
                    groupVM.selectedMemberPIDs.remove(pid)
                }
            }
        )
    }
}
