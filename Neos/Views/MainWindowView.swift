import SwiftUI
import NeosDomain

struct MainWindowView: View {
    let state: AppState
    let container: ViewModelContainer
    @State private var isSearchFocused = false
    @State private var showConnectedSplash = false

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

    /// Whether the splash overlay is showing (connecting or brief "connected" hold).
    private var showSplash: Bool {
        showConnectedSplash ||
        state.connectionState == .connecting ||
        state.connectionState == .reconnecting
    }

    var body: some View {
        ZStack {
            // Main content always in tree underneath
            if state.isConnected {
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
            } else if !showSplash {
                DiscoveryView(state: state, speakerVM: speakerVM)
                    .overlay(alignment: .bottom) {
                        toastOverlay
                            .animation(.easeInOut(duration: DS.Animation.standard), value: state.toast)
                    }
            }

            // Single splash overlay; covers everything while visible
            if showSplash {
                connectionSplash
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DS.Colors.background)
            }
        }
        .overlay {
            if state.isNowPlayingCanvasOpen {
                NowPlayingCanvasView(state: state)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: state.isNowPlayingCanvasOpen)
        .safeAreaInset(edge: .bottom) {
            if state.isConnected && !showConnectedSplash {
                NowPlayingToolbar(state: state, playerVM: playerVM, browseVM: browseVM, searchVM: searchVM)
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
            if isConnected {
                showConnectedSplash = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1.5))
                    showConnectedSplash = false
                }
            } else {
                showConnectedSplash = false
                state.isQueuePanelOpen = false
                state.isNowPlayingCanvasOpen = false
            }
        }
        .onChange(of: browseVM.currentDestination) {
            isSearchFocused = false
        }
        .onChange(of: browseVM.navigationTapCount) {
            if searchVM.isOverlayVisible {
                // Push already happened; origin is one before current
                searchVM.suspendForNavigation(originHistoryIndex: browseVM.currentHistoryIndex - 1)
            }
            isSearchFocused = false
        }
        .task {
            guard !CommandLine.arguments.contains("--skip-discovery") else { return }
            if state.connectionState == .disconnected && state.discoveredDevices.isEmpty && !state.isDiscovering {
                speakerVM.startContinuousDiscovery()
            }
        }
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
            topBar

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
        .overlay(alignment: .bottom) {
            toastOverlay
                .animation(.easeInOut(duration: DS.Animation.standard), value: state.toast)
        }
        .animation(.easeInOut(duration: DS.Animation.standard), value: state.toast)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: DS.Spacing.md) {
            // Back / Forward arrows
            HStack(spacing: DS.Spacing.xs) {
                navArrowButton(
                    icon: DS.Icons.back,
                    enabled: canGoBack,
                    accessibilityID: AccessibilityID.TopBar.backButton,
                    action: { handleBack() }
                )

                navArrowButton(
                    icon: DS.Icons.forward,
                    enabled: browseVM.canGoForward,
                    accessibilityID: AccessibilityID.TopBar.forwardButton,
                    action: { handleForward() }
                )
            }

            Spacer()

            searchField

            // Speaker indicator
            speakerIndicator

            // Profile button
            profileButton
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.sm)
        .frame(height: 48)
        .background(DS.Colors.background)
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: DS.Icons.search)
                .font(DS.IconFont.body)
                .foregroundStyle(DS.Colors.textSecondary)
            NoRingTextField(
                placeholder: "Search",
                text: Binding(
                    get: { searchVM.query },
                    set: { searchVM.onQueryChanged($0) }
                ),
                isFocused: $isSearchFocused,
                accessibilityID: AccessibilityID.TopBar.searchField
            )
            .accessibilityIdentifier(AccessibilityID.TopBar.searchField)
            if !searchVM.query.isEmpty {
                HoverButton(action: { searchVM.clearSearch() }) { hovered in
                    Image(systemName: DS.Icons.close)
                        .font(DS.IconFont.mdEmphasis)
                        .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                }
                .accessibilityIdentifier(AccessibilityID.Search.clearButton)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .frame(width: 380, height: 40)
        .contentShape(Capsule())
        .background(DS.Colors.surfaceElevated, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(isSearchFocused ? 0.6 : 0), lineWidth: 1)
                .allowsHitTesting(false)
        )
        .animation(.easeInOut(duration: DS.Animation.quick), value: isSearchFocused)
        .onChange(of: isSearchFocused) { _, focused in
            if focused && !searchVM.query.isEmpty && !searchVM.serviceResults.isEmpty {
                searchVM.activateOverlay()
            }
        }
        .overlay(alignment: .topLeading) {
            if isSearchFocused && searchVM.query.isEmpty && !searchVM.recentQueries.isEmpty {
                SearchHistoryOverlay(
                    queries: searchVM.recentQueries,
                    onSelect: { query in
                        isSearchFocused = false
                        searchVM.onQueryChanged(query)
                    },
                    onClear: {
                        searchVM.clearHistory()
                    }
                )
                .frame(width: 380)
                .offset(y: 48)
                .zIndex(10)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: DS.Animation.quick), value: isSearchFocused)
            }
        }
    }

    // MARK: - Speaker Indicator

    private var speakerIndicator: some View {
        let isActive = browseVM.currentDestination == .ampSettings
        return HoverButton(action: {
            searchVM.dismissOverlay()
            if isActive {
                browseVM.goBack()
            } else {
                if browseVM.currentDestination == .settings { browseVM.goBack() }
                browseVM.navigateToAmpSettings()
            }
        }) { hovered in
            HStack(spacing: 6) {
                Image(systemName: DS.Icons.speakerFill)
                    .font(DS.IconFont.sm)
                    .foregroundStyle(DS.Colors.accent)

                Text(state.selectedPlayer?.name ?? "No Player")
                    .typography(.secondary)
                    .foregroundStyle(isActive ? DS.Colors.accent : hovered ? .white : .white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: 180, minHeight: 32, alignment: .leading)
            .background(
                isActive ? DS.Colors.accent.opacity(0.12) : .clear,
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive ? DS.Colors.accent : hovered ? DS.Colors.accent.opacity(0.6) : DS.Colors.accent.opacity(0.4),
                        lineWidth: 1
                    )
            )
        }
        .accessibilityIdentifier(AccessibilityID.Sidebar.ampCard)
    }

    private var profileButton: some View {
        let isActive = browseVM.currentDestination == .settings
        return HoverButton(action: {
            searchVM.dismissOverlay()
            if isActive {
                browseVM.goBack()
            } else {
                if browseVM.currentDestination == .ampSettings { browseVM.goBack() }
                browseVM.navigateToSettings()
            }
        }) { hovered in
            Image(systemName: DS.Icons.personCircle)
                .font(DS.IconFont.hero)
                .foregroundStyle(isActive ? DS.Colors.accent : hovered ? .white : Color.white.opacity(0.7))
        }
        .accessibilityIdentifier(AccessibilityID.TopBar.profileButton)
    }

    // MARK: - Navigation Arrow

    private func navArrowButton(icon: String, enabled: Bool, accessibilityID: String, action: @escaping () -> Void) -> some View {
        HoverButton(action: action) { hovered in
            Image(systemName: icon)
                .font(DS.IconFont.lgEmphasis)
                .foregroundStyle(
                    !enabled ? Color.gray.opacity(0.3) :
                    hovered ? Color.white : Color.secondary
                )
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(hovered && enabled ? Color.white.opacity(0.1) : .clear)
                )
        }
        .disabled(!enabled)
        .accessibilityIdentifier(accessibilityID)
    }

    // MARK: - Navigation

    private var canGoBack: Bool {
        searchVM.isOverlayVisible || searchVM.hasSuspendedSearch || browseVM.canGoBack
    }

    private func handleBack() {
        if searchVM.isOverlayVisible {
            searchVM.dismissOverlay()
            return
        }
        browseVM.goBack()
        searchVM.tryRestore(atHistoryIndex: browseVM.currentHistoryIndex)
    }

    private func handleForward() {
        if searchVM.isOverlayVisible {
            searchVM.suspendForNavigation(originHistoryIndex: browseVM.currentHistoryIndex)
        }
        browseVM.goForward()
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

// MARK: - Window Accessor

/// Makes the NSWindow titlebar transparent so canvas background fills edge-to-edge.
private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
