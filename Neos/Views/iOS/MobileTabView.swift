import SwiftUI

extension EnvironmentValues {
    /// The tab bar holds the mini player, so the pages leave it out.
    @Entry var miniPlayerInTabBar = false
}

/// Tabs on iPhone and a sidebar on iPad, from one declaration.
struct MobileTabView: View {
    enum Section: Hashable {
        case home
        case library
        case search
    }

    let state: AppState
    let container: ViewModelContainer
    @State private var selection: Section = .home
    @Environment(\.showsPadChrome) private var showsPadChrome

    /// The device, not the window: the iPad keeps its player in the pages.
    private var isPhone: Bool { UIDevice.current.userInterfaceIdiom == .phone }

    var body: some View {
        if #available(iOS 26, *), isPhone {
            tabs
                .tabViewBottomAccessory {
                    MiniPlayerAccessory(state: state, playerVM: container.playerVM)
                        .disabled(!state.isConnected)
                }
                .tabBarMinimizeBehavior(.onScrollDown)
                .environment(\.miniPlayerInTabBar, true)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: Section.home) {
                PagedStack(state: state, container: container) { model in
                    DestinationView(state: state, container: container, model: model)
                        .navigationTitle("Home")
                }
            }
            Tab("Library", systemImage: "square.stack", value: Section.library) {
                PagedStack(state: state, container: container) { model in
                    LibraryView(state: state, container: container, model: model)
                }
            }
            Tab(value: Section.search, role: .search) {
                PagedStack(state: state, container: container) { model in
                    MobileSearchView(state: state, container: container, model: model)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        // iPad only, and not under the player, which shows the queue itself; an iPhone opens it from the player.
        .inspector(isPresented: Binding(
            get: { showsPadChrome && state.isQueuePanelOpen && !state.isNowPlayingCanvasOpen },
            set: { state.isQueuePanelOpen = $0 }
        )) {
            QueuePanelView(state: state, viewModel: container.queuePanelVM)
        }
    }
}
