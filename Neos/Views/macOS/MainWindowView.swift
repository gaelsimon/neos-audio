import SwiftUI
import NeosDomain

struct MainWindowView: View {
    let state: AppState
    let container: ViewModelContainer
    @State private var showConnectedSplash = false
    @State private var playerBarHeight: CGFloat = 0

    private var playerVM: PlayerViewModel { container.playerVM }
    private var speakerVM: SpeakerListViewModel { container.speakerVM }
    private var browseVM: BrowseViewModel { container.browseVM }
    private var homeVM: HomeViewModel { container.homeVM }
    private var searchVM: SearchViewModel { container.searchVM }
    private var queuePanelVM: QueuePanelViewModel { container.queuePanelVM }

    private var showsContent: Bool {
        ConnectionPresentation(
            connectionState: state.connectionState,
            hasEstablishedSession: state.hasEstablishedSession,
            isHoldingConnectedSplash: showConnectedSplash
        ).showsContent
    }

    var body: some View {
        ConnectionGate(state: state, speakerVM: speakerVM, isHoldingSplash: $showConnectedSplash) {
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
        }
        // The full-screen player covers the window, so VoiceOver must not reach what lies under it.
        .accessibilityHidden(state.isNowPlayingCanvasOpen)
        .overlay {
            if state.isNowPlayingCanvasOpen {
                NowPlayingCanvasView(state: state)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: state.isNowPlayingCanvasOpen)
        // The inspector keeps an inset set around it from the pages, so each side makes room for the bar itself.
        .safeAreaPadding(.bottom, playerBarHeight)
        // Beside the full-screen player too, and above the player bar, which keeps the window's width.
        .inspector(isPresented: Bindable(state).isQueuePanelOpen) {
            QueuePanelView(state: state, viewModel: queuePanelVM)
                .safeAreaPadding(.bottom, playerBarHeight)
                .inspectorColumnWidth(min: 320, ideal: 380, max: 480)
        }
        .overlay(alignment: .bottom) {
            playerBar
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { playerBarHeight = $0 }
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 660, minHeight: 500)
        .background(WindowAccessor())
        .onChange(of: browseVM.currentDestination) {
            state.isSearchFieldFocused = false
        }
        .onChange(of: browseVM.navigationTapCount) {
            state.isSearchFieldFocused = false
        }
    }

    // MARK: - Player Bar

    private var playerBar: some View {
        VStack(spacing: 0) {
            if showsContent && !showConnectedSplash {
                // Transport is dead while reconnecting; dim it rather than let commands time out.
                NowPlayingToolbar(state: state, playerVM: playerVM, browseVM: browseVM, searchVM: searchVM)
                    .disabled(!state.isConnected)
                    .opacity(state.isConnected ? 1 : 0.5)
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
                    DestinationView(state: state, container: container, model: browseVM)
                }
            }
            .id(browseVM.currentDestination.stableID)
            .transition(.opacity)
            .animation(.easeInOut(duration: DS.Animation.viewTransition), value: browseVM.currentDestination)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DS.Colors.background)
        }
        // On the container, not on the identity-switching Group: a rebuild there recreated the search field mid-typing.
        .safeAreaInset(edge: .top, spacing: 0) { TopBarView(state: state, container: container) }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) { ToastOverlay(state: state) }
    }
}
