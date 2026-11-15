import SwiftUI

/// Discovery, the connecting splash and the reconnecting banner around the connected app, on every platform.
struct ConnectionGate<Content: View>: View {
    let state: AppState
    let speakerVM: SpeakerListViewModel
    /// True for a moment after the session's first connection, while the splash says so.
    @Binding var isHoldingSplash: Bool
    @ViewBuilder let content: () -> Content

    /// Armed once per session, so only the first connect gets the splash.
    @State private var hasShownSplash = false

    private var presentation: ConnectionPresentation {
        ConnectionPresentation(
            connectionState: state.connectionState,
            hasEstablishedSession: state.hasEstablishedSession,
            isHoldingConnectedSplash: isHoldingSplash
        )
    }

    var body: some View {
        ZStack {
            if presentation.showsContent {
                content()
            } else if presentation.showsDiscovery {
                DiscoveryView(state: state, speakerVM: speakerVM)
                    .overlay(alignment: .bottom) { ToastOverlay(state: state) }
            }

            if presentation.showsSplash {
                splash
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Colors.background)
            }
        }
        .overlay(alignment: .top) {
            if presentation.showsReconnectingBanner {
                ReconnectingBanner(deviceName: deviceName, onChooseAnother: { speakerVM.disconnect() })
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: DS.Animation.standard), value: presentation.showsReconnectingBanner)
        .onChange(of: state.isConnected) { _, isConnected in
            guard isConnected else {
                isHoldingSplash = false
                return
            }
            // First connect only: a reconnection gets the banner, and a splash would hide the kept session.
            guard !hasShownSplash else { return }
            hasShownSplash = true
            isHoldingSplash = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                isHoldingSplash = false
            }
        }
        // Only a real disconnect closes panels; reconnecting -> disconnected never moves `isConnected`.
        .onChange(of: state.connectionState) { _, connectionState in
            guard connectionState == .disconnected else { return }
            hasShownSplash = false
            state.isQueuePanelOpen = false
            state.isNowPlayingCanvasOpen = false
        }
        .task {
            guard !CommandLine.arguments.contains("--skip-discovery") else { return }
            if state.connectionState == .disconnected && state.discoveredDevices.isEmpty && !state.isDiscovering {
                speakerVM.startContinuousDiscovery()
            }
        }
    }

    private var deviceName: String {
        state.selectedPlayerDisplayName
            ?? state.connectedDevice.map { state.displayName(for: $0) }
            ?? "Speaker"
    }

    /// Content updates in place, without fading.
    private var splash: some View {
        VStack(spacing: DS.Spacing.md) {
            if state.isConnected {
                Image(systemName: DS.Icons.speakerFill)
                    .font(.system(size: 28))
                    .foregroundStyle(DS.Colors.accent)

                Text("Connected to \(deviceName)")
                    .typography(.bodyEmphasis)
            } else {
                Spinner(size: 24, lineWidth: 3)

                Text("Connecting to \(deviceName)...")
                    .typography(.secondary)

                TextActionButton(title: "Scan for other devices") {
                    speakerVM.disconnect()
                }
            }
        }
    }
}
