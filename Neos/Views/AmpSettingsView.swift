import SwiftUI
import NeosDomain

struct AmpSettingsView: View {
    let state: AppState
    @Bindable var speakerVM: SpeakerListViewModel
    @Bindable var groupVM: GroupViewModel

    @State private var selectedLeaderPID: Int?
    @State private var renamingGroupID: Int?
    @State private var groupNameDraft = ""

    var body: some View {
        Form {
            playersSection
            groupSections
            newGroupSection
            connectionSection
        }
        .settingsForm()
        .pageHeading("Speakers")
        .accessibilityIdentifier(AccessibilityID.AmpSettings.view)
        .task {
            groupVM.loadGroups()
        }
    }

    // MARK: - Section

    private func formSection<Content: View, Accessory: View>(
        header: String?,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        Section {
            content()
        } header: {
            if let header {
                HStack {
                    Text(header)
                    Spacer()
                    accessory()
                }
            }
        }
    }

    // MARK: - Players Section

    private var playersSection: some View {
        formSection(header: nil) {
            if state.players.isEmpty {
                Text("No speakers found.")
                    .typography(.secondary)
            } else {
                ForEach(state.displayPlayers) { player in
                    playerRow(player)
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

                    Text(state.displayName(for: player))
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

            // Power is wired to the device the session is on, so only its row gets the button.
            if player.ip == state.connectedDevice?.host {
                HoverButton(
                    action: { speakerVM.togglePower() },
                    accessibilityID: AccessibilityID.AmpSettings.powerButton
                ) { hovered in
                    Image(systemName: DS.Icons.power)
                        .font(DS.IconFont.lg)
                        .foregroundStyle(hovered ? DS.Colors.accent : DS.Colors.textTertiary)
                }
                .help(state.isPoweredOn ? "Turn Off" : "Turn On")
            }
        }
        // As tall as the power button's target, so rows with and without one line up.
        .frame(minHeight: DS.HitTarget.button)
        .accessibilityIdentifier(AccessibilityID.AmpSettings.playerRow(player.pid))
        .accessibilityValue(player.pid == state.selectedPlayerID ? "selected" : "unselected")
    }

    private func playerIcon(for player: Player) -> String {
        let isGrouped = state.groups.contains { group in
            group.players.contains { $0.pid == player.pid }
        }
        return isGrouped ? DS.Icons.speakerGrouped : DS.Icons.speaker
    }

    // MARK: - Groups

    /// One section per group; the first carries the heading, as does the note when there is none.
    @ViewBuilder
    private var groupSections: some View {
        if state.groups.isEmpty {
            formSection(header: "Speaker Groups", accessory: { refreshButton }) {
                Text("No active groups.")
                    .typography(.secondary)
            }
        } else {
            ForEach(state.groups) { group in
                formSection(
                    header: group.id == state.groups.first?.id ? "Speaker Groups" : nil,
                    accessory: { refreshButton }
                ) {
                    groupRows(group)
                }
            }
        }
    }

    private var refreshButton: some View {
        HoverButton(action: { groupVM.refresh() }) { hovered in
            Image(systemName: DS.Icons.refresh)
                .typography(.bodyPrimary, color: hovered ? .white : DS.Colors.textSecondary)
        }
        .disabled(groupVM.isLoadingGroups)
        .help("Re-read players and groups from the device")
        .accessibilityLabel("Refresh")
        .accessibilityIdentifier(AccessibilityID.Group.refreshButton)
    }

    @ViewBuilder
    private func groupRows(_ group: SpeakerGroup) -> some View {
        groupTitle(group)
            .onAppear { groupVM.loadMemberVolumes(for: group) }

        ForEach(group.players, id: \.pid) { player in
            LevelRow(
                name: state.displayName(for: player),
                icon: player.role == .leader ? DS.Icons.star : DS.Icons.speaker,
                iconColor: player.role == .leader ? DS.Colors.accent : DS.Colors.textSecondary,
                level: state.playerVolumes[player.pid],
                label: "Speaker volume",
                onDragging: { groupVM.setAdjustingMemberVolume(pid: player.pid, $0) }
            ) { groupVM.setMemberVolume(pid: player.pid, level: $0) }
        }

        LevelRow(
            name: "All Speakers", icon: DS.Icons.speakerActive, iconColor: DS.Colors.textSecondary,
            level: state.groupVolumes[group.gid], label: "Group volume"
        ) { groupVM.setGroupVolume(gid: group.gid, level: $0) }

        Button(role: .destructive) {
            groupVM.ungroup(pid: group.gid)
        } label: {
            if groupVM.isUngrouping {
                Spinner(size: 16, lineWidth: 2)
            } else {
                Text("Ungroup")
            }
        }
        .disabled(groupVM.isUngrouping)
        .accessibilityIdentifier(AccessibilityID.Group.ungroupButton(group.gid))
    }

    @ViewBuilder
    private func groupTitle(_ group: SpeakerGroup) -> some View {
        if renamingGroupID == group.gid {
            TextField("Group name", text: $groupNameDraft)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)
                .onChange(of: groupNameDraft) { _, draft in
                    groupNameDraft = String(draft.prefix(GroupViewModel.maxGroupNameLength))
                }
                .onSubmit {
                    groupVM.renameGroup(group, to: groupNameDraft)
                    renamingGroupID = nil
                }
                #if os(macOS)
                .onExitCommand { renamingGroupID = nil }
                #endif
                .accessibilityIdentifier(AccessibilityID.Group.nameField(group.gid))
        } else {
            HStack(spacing: DS.Spacing.sm) {
                Text(state.displayName(for: group))
                    .typography(.bodyMedium)
                    .lineLimit(1)
                HoverButton(action: {
                    groupNameDraft = state.displayName(for: group)
                    renamingGroupID = group.gid
                }) { hovered in
                    Image(systemName: DS.Icons.rename)
                        .font(DS.IconFont.sm)
                        .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                }
                .help("Rename group")
                .accessibilityIdentifier(AccessibilityID.Group.renameButton(group.gid))
            }
        }
    }

    // MARK: - New Group

    @ViewBuilder
    private var newGroupSection: some View {
        if state.players.count >= 2 {
            Section {
                Picker("Music from", selection: leaderBinding) {
                    ForEach(state.players) { player in
                        Text(state.displayName(for: player)).tag(player.pid)
                    }
                }
                .accessibilityIdentifier(AccessibilityID.Group.leaderPicker)

                ForEach(state.players) { player in
                    if player.pid != leaderPID {
                        Toggle(state.displayName(for: player), isOn: memberBinding(for: player.pid))
                            #if os(macOS)
                            .toggleStyle(.checkbox)
                            #endif
                            .tint(DS.Colors.accent)
                            .accessibilityIdentifier(AccessibilityID.Group.memberToggle(player.pid))
                    }
                }

                Button {
                    guard let leaderPID else { return }
                    groupVM.createGroup(leaderPID: leaderPID)
                } label: {
                    if groupVM.isCreatingGroup {
                        Spinner(size: 16, lineWidth: 2)
                    } else {
                        Text("Create Group")
                    }
                }
                .disabled(!canCreate || groupVM.isCreatingGroup)
                .accessibilityIdentifier(AccessibilityID.Group.createButton)
            } header: {
                Text("New Group")
            } footer: {
                Text("Choose where the music comes from, then the speakers that play it too.")
            }
        } else {
            Section("New Group") {
                Text("Need 2+ speakers to create groups.")
                    .typography(.secondary)
                    .accessibilityIdentifier(AccessibilityID.Group.emptyState)
            }
        }
    }

    // MARK: - Connection Section

    private var connectionSection: some View {
        formSection(header: "Connection") {
            if let device = state.connectedDevice {
                LabeledContent {
                    Text(device.host)
                } label: {
                    Label {
                        Text(connectionDisplayName(device))
                    } icon: {
                        Image(systemName: DS.Icons.speakerFill)
                            .foregroundStyle(DS.Colors.accent)
                    }
                }

                Button("Disconnect") { speakerVM.disconnect() }
                    .accessibilityIdentifier(AccessibilityID.Sidebar.disconnectButton)
            } else {
                Text("Not connected to any device.")
                    .typography(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func connectionDisplayName(_ device: DiscoveredDevice) -> String {
        if !device.friendlyName.isEmpty, device.friendlyName != device.host {
            return state.displayName(for: device)
        }
        return state.selectedPlayer.map { state.displayName(for: $0) } ?? device.host
    }

    /// Before the user touches the picker it shows the playing speaker; the form must agree.
    private var leaderPID: Int? {
        selectedLeaderPID ?? state.selectedPlayerID ?? state.players.first?.pid
    }

    private var canCreate: Bool {
        guard let leaderPID else { return false }
        let members = groupVM.selectedMemberPIDs.filter { $0 != leaderPID }
        return !members.isEmpty
    }

    private var leaderBinding: Binding<Int> {
        Binding(
            get: { leaderPID ?? 0 },
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

/// A speaker's or a group's volume as a form row. It follows the amp's `level` whenever the user is not dragging.
private struct LevelRow: View {
    let name: String
    let icon: String
    let iconColor: Color
    let level: Int?
    let label: String
    var onDragging: (Bool) -> Void = { _ in }
    let onChange: (Int) -> Void

    @State private var value: Double = 0
    @State private var isDragging = false
    @Environment(\.isCompactLayout) private var isCompact

    var body: some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    title
                    slider
                }
            } else {
                HStack(spacing: DS.Spacing.md) {
                    title
                        .frame(width: 160, alignment: .leading)
                    slider
                }
            }
        }
        .onAppear { sync() }
        .onChange(of: level) { sync() }
    }

    private var title: some View {
        Label {
            Text(name)
                .lineLimit(1)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
        }
    }

    private var slider: some View {
        HStack(spacing: DS.Spacing.sm) {
            Slider(
                value: Binding(get: { value }, set: { newValue in
                    value = newValue
                    onChange(Int(newValue.rounded()))
                }),
                in: 0...100
            ) {
                Text(label)
            } onEditingChanged: { editing in
                isDragging = editing
                onDragging(editing)
            }
            .labelsHidden()
            .tint(DS.Colors.accent)

            Text("\(Int(value.rounded()))")
                .typography(.secondary)
                .monospacedDigit()
                .frame(width: 32, alignment: .trailing)
                .accessibilityHidden(true)
        }
    }

    private func sync() {
        guard !isDragging, let level else { return }
        value = Double(level)
    }
}
