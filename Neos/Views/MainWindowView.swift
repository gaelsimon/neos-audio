import SwiftUI
import NeosDomain

struct MainWindowView: View {
    let state: AppState
    let container: ViewModelContainer
    @State private var showConnectedSplash = false
    /// Armed once per session, so only the first connect gets the splash.
    @State private var hasShownConnectedSplash = false

    private var playerVM: PlayerViewModel { container.playerVM }
    private var speakerVM: SpeakerListViewModel { container.speakerVM }
    private var queueVM: QueueViewModel { container.queueVM }
    private var browseVM: BrowseViewModel { container.browseVM }
    private var homeVM: HomeViewModel { container.homeVM }
    private var accountVM: AccountViewModel { container.accountVM }
    private var searchVM: SearchViewModel { container.searchVM }
    private var queuePanelVM: QueuePanelViewModel { container.queuePanelVM }
    private var settingsVM: SettingsViewModel { container.settingsVM }
    private var groupVM: GroupViewModel { container.groupVM }

    /// Splash, content, banner or discovery: an established session reconnects in place.
    private var presentation: ConnectionPresentation {
        ConnectionPresentation(
            connectionState: state.connectionState,
            hasEstablishedSession: state.hasEstablishedSession,
            isHoldingConnectedSplash: showConnectedSplash
        )
    }

    var body: some View {
        ZStack {
            // Main content always in tree underneath
            if presentation.showsContent {
                HStack(spacing: 0) {
                    SidebarView(
                        state: state,
                        browseVM: browseVM,
                        hiddenSIDs: homeVM.hiddenSIDs,
                        isSearchActive: searchVM.isOverlayVisible
                    )
                    .frame(width: DS.Sidebar.expandedWidth)

                    connectedContent
                        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if presentation.showsDiscovery {
                DiscoveryView(state: state, speakerVM: speakerVM)
                    .overlay(alignment: .bottom) {
                        toastOverlay
                            .animation(.easeInOut(duration: DS.Animation.standard), value: state.toast)
                    }
            }

            // Single splash overlay; covers everything while visible
            if presentation.showsSplash {
                connectionSplash
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Colors.background)
            }
        }
        .overlay(alignment: .top) {
            if presentation.showsReconnectingBanner {
                ReconnectingBanner(
                    deviceName: reconnectingDeviceName,
                    onChooseAnother: { speakerVM.disconnect() }
                )
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: DS.Animation.standard), value: presentation.showsReconnectingBanner)
        .overlay {
            if state.isNowPlayingCanvasOpen {
                NowPlayingCanvasView(state: state)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: state.isNowPlayingCanvasOpen)
        .safeAreaInset(edge: .bottom) {
            if presentation.showsContent && !showConnectedSplash {
                // Transport is dead while reconnecting; dim it rather than let commands time out.
                NowPlayingToolbar(state: state, playerVM: playerVM, browseVM: browseVM, searchVM: searchVM)
                    .disabled(!state.isConnected)
                    .opacity(state.isConnected ? 1 : 0.5)
            }
        }
        // Single queue panel; adapts layout to canvas vs normal mode
        .overlay(alignment: .trailing) {
            if state.isQueuePanelOpen {
                ZStack(alignment: .trailing) {
                    QueuePanelView(state: state, viewModel: queuePanelVM)
                        .frame(width: state.isNowPlayingCanvasOpen ? 380 + DS.Spacing.md * 2 : 380)
                        .padding(.top, state.isNowPlayingCanvasOpen ? 60 : 48)
                        .padding(.bottom, state.isNowPlayingCanvasOpen ? 120 : 108)
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: DS.Animation.standard), value: state.isQueuePanelOpen)
        .animation(.easeInOut(duration: 0.35), value: state.isNowPlayingCanvasOpen)
        .frame(minWidth: 660, minHeight: 500)
        .preferredColorScheme(.dark)
        .background(WindowAccessor())
        .onChange(of: state.isConnected) { _, isConnected in
            guard isConnected else {
                showConnectedSplash = false
                return
            }
            // The splash belongs to the first connect only: a reconnection is announced by the
            // banner, and covering the session for 1.5 s would undo the point of keeping it up.
            guard !hasShownConnectedSplash else { return }
            hasShownConnectedSplash = true
            showConnectedSplash = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                showConnectedSplash = false
            }
        }
        // A reconnection keeps panels open; only a real disconnect closes them, and that
        // transition is reconnecting -> disconnected, which never moves `isConnected`.
        .onChange(of: state.connectionState) { _, connectionState in
            guard connectionState == .disconnected else { return }
            hasShownConnectedSplash = false
            state.isQueuePanelOpen = false
            state.isNowPlayingCanvasOpen = false
        }
        .onChange(of: browseVM.currentDestination) {
            state.isSearchFieldFocused = false
        }
        .onChange(of: browseVM.navigationTapCount) {
            state.isSearchFieldFocused = false
        }
        .task {
            guard !CommandLine.arguments.contains("--skip-discovery") else { return }
            if state.connectionState == .disconnected && state.discoveredDevices.isEmpty && !state.isDiscovering {
                speakerVM.startContinuousDiscovery()
            }
        }
    }

    private var reconnectingDeviceName: String {
        state.selectedPlayerDisplayName
            ?? state.connectedDevice.map { state.displayName(for: $0) }
            ?? "Speaker"
    }

    // MARK: - Connection Splash

    /// Single splash view; content updates in place, no fading.
    private var connectionSplash: some View {
        let deviceName = state.selectedPlayer?.name
            ?? state.connectedDevice?.friendlyName
            ?? "Speaker"

        return VStack(spacing: DS.Spacing.md) {
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
                    .foregroundStyle(DS.Colors.textSecondary)

                Button("Scan for other devices") {
                    speakerVM.disconnect()
                }
                .buttonStyle(.plain)
                .typography(.secondary)
                .foregroundStyle(DS.Colors.accent)
                .padding(.top, DS.Spacing.sm)
            }
        }
    }

    // MARK: - Connected Content

    private var connectedContent: some View {
        VStack(spacing: 0) {
            Group {
                if searchVM.isOverlayVisible {
                    SearchResultsView(
                        state: state,
                        searchVM: searchVM,
                        browseVM: browseVM,
                        service: searchVM.service
                    )
                    .onExitCommand { searchVM.dismissOverlay() }
                } else {
                    switch browseVM.currentDestination {
                    case .home:
                        HomeView(state: state, homeVM: homeVM, browseVM: browseVM)
                    case .browse:
                        BrowseContentView(state: state, browseVM: browseVM)
                    case .queue:
                        QueueView(state: state, viewModel: queueVM, browseVM: browseVM)
                    case .settings:
                        AccountSettingsView(state: state, accountVM: accountVM, settingsVM: settingsVM, homeVM: homeVM)
                    case .ampSettings:
                        AmpSettingsView(state: state, speakerVM: speakerVM, groupVM: groupVM)
                    }
                }
            }
            .id(browseVM.currentDestination.stableID)
            .transition(.opacity)
            .animation(.easeInOut(duration: DS.Animation.viewTransition), value: browseVM.currentDestination)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Push content left when queue panel is open (normal mode only)
            .padding(.trailing, !state.isNowPlayingCanvasOpen && state.isQueuePanelOpen ? 380 : 0)
            .animation(.easeInOut(duration: DS.Animation.standard), value: state.isQueuePanelOpen)
            .background(DS.Colors.background)
        }
        // On the container, not on the identity-switching Group: a rebuild there recreated the search field mid-typing.
        .safeAreaInset(edge: .top, spacing: 0) { TopBarView(state: state, container: container) }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) {
            toastOverlay
                .animation(.easeInOut(duration: DS.Animation.standard), value: state.toast)
        }
        .animation(.easeInOut(duration: DS.Animation.standard), value: state.toast)
    }

    // MARK: - Toast

    @ViewBuilder
    private var toastOverlay: some View {
        if let toast = state.toast {
            ToastView(message: toast)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, DS.Spacing.lg)
                .id(toast.id)
        }
    }
}
