import SwiftUI
import NeosDomain

struct DiscoveryView: View {
    let state: AppState
    @Bindable var speakerVM: SpeakerListViewModel
    @State private var showManualConnect = CommandLine.arguments.contains("--uitesting")

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    brandingHeader

                    if state.isDiscovering && state.visibleDiscoveredDevices.isEmpty {
                        discoveringState
                    } else if !state.visibleDiscoveredDevices.isEmpty {
                        devicesFoundState
                    } else {
                        noDevicesState
                    }

                    manualConnect
                }
                .frame(maxWidth: 500)
                .padding(DS.Spacing.xl)
                // Centred while it fits, scrolling once larger text makes it taller than the window.
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
        }
        .background(DS.Colors.background)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.Disconnected.view)
    }

    // MARK: - States

    @ViewBuilder
    private var discoveringState: some View {
        Spinner(size: 24, lineWidth: 3)
            .accessibilityIdentifier(AccessibilityID.Discovery.progressIndicator)

        Text("Looking for speakers on your network…")
            .typography(.secondary)
    }

    @ViewBuilder
    private var devicesFoundState: some View {
        Text("Select a speaker")
            .typography(.bodyPrimary, color: DS.Colors.textSecondary)

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250))], spacing: DS.Spacing.md) {
            ForEach(state.visibleDiscoveredDevices) { device in
                DiscoveredDeviceCard(device: device, name: state.displayName(for: device)) {
                    speakerVM.connectToDevice(device)
                }
            }
        }
        .accessibilityIdentifier(AccessibilityID.Discovery.deviceGrid)
    }

    @ViewBuilder
    private var noDevicesState: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("No Speakers Found")
                .typography(.bodyEmphasis)
                .accessibilityIdentifier(AccessibilityID.Disconnected.title)

            Group {
                Text("Make sure your HEOS device is powered on and connected to the same network as your \(DeviceIdiom.name).")
                Text("You can also try connecting directly using its IP address.")
            }
            .typography(.secondary)
            .multilineTextAlignment(.center)
            // A page short of room squeezes text first; this keeps every line.
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 380)

        if let error = state.discoveryError {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: DS.Icons.warning)
                    .foregroundStyle(.yellow)
                Text(error)
                    .typography(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Spacing.md)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: DS.Radius.medium))
        }

        Button { speakerVM.discover() } label: {
            Label("Scan Again", systemImage: DS.Icons.refresh)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityIdentifier(AccessibilityID.Sidebar.scanButton)
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
        .accessibilityHidden(true)
    }

    // MARK: - Manual Connect

    private var manualConnect: some View {
        VStack(spacing: DS.Spacing.sm) {
            TextActionButton(title: "Connect by IP", accessibilityID: AccessibilityID.Discovery.manualConnectToggle) {
                withAnimation(.easeInOut(duration: DS.Animation.viewTransition)) {
                    showManualConnect.toggle()
                }
            }

            if showManualConnect {
                HStack(spacing: DS.Spacing.sm) {
                    TextField("IP address", text: $speakerVM.manualHost)
                        .textFieldStyle(.roundedBorder)
                        .literalTextInput(.ipAddress)
                        .submitLabel(.go)
                        .frame(maxWidth: 200)
                        .onSubmit {
                            speakerVM.connectManual(host: speakerVM.manualHost)
                        }
                        .accessibilityIdentifier(AccessibilityID.Sidebar.manualIPField)
                    Button("Connect") {
                        speakerVM.connectManual(host: speakerVM.manualHost)
                    }
                    .buttonStyle(.bordered)
                    .disabled(speakerVM.manualHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier(AccessibilityID.Sidebar.manualConnectButton)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
