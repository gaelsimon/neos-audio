import SwiftUI
import NeosDomain

// MARK: - Discovery View

struct DiscoveryView: View {
    let state: AppState
    @Bindable var speakerVM: SpeakerListViewModel
    @State private var showManualConnect = CommandLine.arguments.contains("--uitesting")

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer()
                    .frame(maxHeight: 100)

                if state.isDiscovering && state.visibleDiscoveredDevices.isEmpty {
                    discoveringState
                } else if !state.visibleDiscoveredDevices.isEmpty {
                    devicesFoundState
                } else {
                    noDevicesState
                }

                Spacer()
                    .frame(maxHeight: 100)
            }
            .frame(maxWidth: .infinity, minHeight: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Disconnected.view)
    }

    // MARK: - State A: Discovering

    private var discoveringState: some View {
        VStack(spacing: DS.Spacing.xl) {
            brandingHeader

            Spinner(size: 24, lineWidth: 3)
                .accessibilityIdentifier(AccessibilityID.Discovery.progressIndicator)

            Text("Looking for players on your network...")
                .typography(.secondary)
                .foregroundStyle(DS.Colors.textSecondary)

            manualConnectToggle
        }
    }

    // MARK: - State B: Devices Found

    private var devicesFoundState: some View {
        VStack(spacing: DS.Spacing.xl) {
            brandingHeader

            Text("Select a player")
                .typography(.bodyPrimary)
                .foregroundStyle(DS.Colors.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: DS.Spacing.md) {
                ForEach(state.visibleDiscoveredDevices) { device in
                    DiscoveredDeviceCard(device: device) {
                        speakerVM.connectToDevice(device)
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Discovery.deviceGrid)

            manualConnectToggle
        }
        .frame(maxWidth: 500)
    }

    // MARK: - State C: No Devices Found

    private var noDevicesState: some View {
        VStack(spacing: DS.Spacing.xl) {
            brandingHeader

            Text("No Players Found")
                .typography(.bodyPrimary)
                .foregroundStyle(DS.Colors.textSecondary)
                .accessibilityIdentifier(AccessibilityID.Disconnected.title)

            VStack(spacing: DS.Spacing.sm) {
                Text("Make sure your HEOS device is powered on\nand connected to the same network as your Mac.")
                    .typography(.secondary)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)

                Text("You can also try connecting directly using its IP address.")
                    .typography(.secondary)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 380)
            .padding(.bottom, DS.Spacing.sm)

            if let error = state.discoveryError {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: DS.Icons.warning)
                        .foregroundStyle(.yellow)
                    Text(error)
                        .typography(.secondary)
                }
                .padding(DS.Spacing.md)
                .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.medium))
            }

            Button(action: { speakerVM.discover() }) {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: DS.Icons.refresh)
                        .typography(.badge)
                    Text("Scan for players")
                        .typography(.secondary)
                }
                .foregroundStyle(DS.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Sidebar.scanButton)

            manualConnectToggle
        }
        .frame(maxWidth: 500)
    }

    // MARK: - Branding Header

    private var brandingHeader: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: DS.Icons.speakerGroup)
                .font(DS.IconFont.jumbo)
                .foregroundStyle(.white.opacity(0.15))

            Image("NeosLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 28)
        }
    }

    // MARK: - Manual Connect

    private var manualConnectToggle: some View {
        VStack(spacing: DS.Spacing.sm) {
            Button(action: {
                withAnimation(.easeInOut(duration: DS.Animation.viewTransition)) {
                    showManualConnect.toggle()
                }
            }) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("Connect by IP")
                        .typography(.secondary)
                    Image(systemName: showManualConnect ? DS.Icons.expandUp : DS.Icons.expandDown)
                        .font(DS.IconFont.xs)
                }
                .foregroundStyle(DS.Colors.accent)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Discovery.manualConnectToggle)

            if showManualConnect {
                HStack(spacing: DS.Spacing.sm) {
                    TextField("IP address", text: $speakerVM.manualHost)
                        .textFieldStyle(.roundedBorder)
                        .typography(.secondary)
                        .frame(maxWidth: 200)
                        .onSubmit {
                            speakerVM.connectManual(host: speakerVM.manualHost)
                        }
                        .accessibilityIdentifier(AccessibilityID.Sidebar.manualIPField)
                    Button("Connect") {
                        speakerVM.connectManual(host: speakerVM.manualHost)
                    }
                    .typography(.secondary)
                    .disabled(speakerVM.manualHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier(AccessibilityID.Sidebar.manualConnectButton)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

}
