import SwiftUI

/// One place of a tab's navigation, with the model that loads and keeps its content.
final class BrowsePage: Hashable {
    let model: BrowseViewModel
    let location: BrowseLocation

    init(model: BrowseViewModel, location: BrowseLocation) {
        self.model = model
        self.location = location
    }

    static func == (lhs: BrowsePage, rhs: BrowsePage) -> Bool { lhs === rhs }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

/// A tab's navigation stack. Every place gets a page of its own, so going back shows the previous page as it was.
struct PagedStack<Root: View>: View {
    let state: AppState
    let container: ViewModelContainer
    /// Where the first page opens, for a tab that is one source; nil for a page that needs no place.
    var start: BrowseLocation?
    @ViewBuilder let root: (BrowseViewModel) -> Root

    @Environment(\.showsPadChrome) private var showsPadChrome
    @Environment(\.miniPlayerInTabBar) private var miniPlayerInTabBar
    @Environment(\.tabBarPlacement) private var tabBarPlacement
    @Environment(\.isSidebarShowing) private var isSidebarShowing
    @State private var rootModel: BrowseViewModel?
    @State private var pages: [BrowsePage] = []
    @State private var playerBarHeight: CGFloat = 0

    var body: some View {
        NavigationStack(path: $pages) {
            ZStack {
                if let rootModel {
                    root(rootModel)
                        .modifier(AccountToolbar(state: state, container: container))
                        // Explicit: with its tabs at the top, iPad would otherwise show no title.
                        .navigationBarTitleDisplayMode(.large)
                        .safeAreaPadding(.bottom, playerBarHeight)
                }
            }
            .navigationDestination(for: BrowsePage.self) { page in
                DestinationView(state: state, container: container, model: page.model)
                    .navigationTitle(page.model.currentLocationName)
                    // The artwork header carries the title, so the bar keeps a small one.
                    .navigationBarTitleDisplayMode(page.model.opensOnArtwork ? .inline : .large)
                    .safeAreaPadding(.bottom, playerBarHeight)
            }
        }
        // An inset around the stack never reaches its pages, so each page makes room for the bar itself.
        .overlay(alignment: .bottom) {
            VStack(spacing: 0) {
                ToastOverlay(state: state)
                playerBar
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(AccessibilityID.Player.bar)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { playerBarHeight = $0 }
            }
        }
        .modifier(QueueInspector(state: state, container: container, isInstalled: QueueInspector.belongsInsideTabs))
        .onChange(of: tabBarPlacement == .sidebar, initial: true) { _, isShowing in
            isSidebarShowing.wrappedValue = isShowing
        }
        .onAppear {
            guard rootModel == nil else { return }
            let model = makeModel()
            if let start { model.start(at: start) }
            rootModel = model
        }
    }

    @ViewBuilder
    private var playerBar: some View {
        if showsPadChrome {
            NowPlayingToolbar(
                state: state, playerVM: container.playerVM,
                browseVM: rootModel ?? container.browseVM, searchVM: container.searchVM
            )
            .disabled(!state.isConnected)
        } else if !miniPlayerInTabBar {
            MiniPlayerBar(state: state, playerVM: container.playerVM)
                .disabled(!state.isConnected)
        }
    }

    private func makeModel() -> BrowseViewModel {
        let model = container.makeBrowseModel()
        model.openPage = { location in open(location) }
        return model
    }

    private func open(_ location: BrowseLocation) {
        switch PageMove(opening: location, root: start, stack: pages.map(\.location)) {
        case .backToRoot:
            pages.removeAll()
        case .back(let index):
            pages.removeSubrange((index + 1)...)
        case .push:
            let model = makeModel()
            model.start(at: location)
            pages.append(BrowsePage(model: model, location: location))
        }
    }
}

/// The queue beside the pages of a wide iPad. Around the tab view, iPadOS 26 empties the sidebar while it is open;
/// inside a tab, iPadOS 18 no longer brings the Library back to its list. Each system gets the place that works there.
struct QueueInspector: ViewModifier {
    static let belongsInsideTabs: Bool = {
        if #available(iOS 26, *) { true } else { false }
    }()

    let state: AppState
    let container: ViewModelContainer
    let isInstalled: Bool
    @Environment(\.showsPadChrome) private var showsPadChrome

    func body(content: Content) -> some View {
        if isInstalled {
            // Not under the player, which shows the queue itself; an iPhone opens it from the player.
            content.inspector(isPresented: Binding(
                get: { showsPadChrome && state.isQueuePanelOpen && !state.isNowPlayingCanvasOpen },
                set: { state.isQueuePanelOpen = $0 }
            )) {
                QueuePanelView(state: state, viewModel: container.queuePanelVM)
            }
        } else {
            content
        }
    }
}

/// The speaker and settings buttons of each tab's first page, opening as sheets.
private struct AccountToolbar: ViewModifier {
    enum Sheet: String, Identifiable {
        case speakers
        case settings

        var id: String { rawValue }
    }

    let state: AppState
    let container: ViewModelContainer
    @State private var sheet: Sheet?

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { sheet = .speakers } label: {
                        Label("Speakers", systemImage: DS.Icons.speaker)
                    }
                    Button { sheet = .settings } label: {
                        Label("Settings", systemImage: DS.Icons.personCircle)
                    }
                }
            }
            .sheet(item: $sheet) { sheet in
                switch sheet {
                case .speakers:
                    SpeakersSheet(state: state, container: container)
                case .settings:
                    DoneSheet(title: "Settings") {
                        AccountSettingsView(
                            state: state, accountVM: container.accountVM, settingsVM: container.settingsVM,
                            homeVM: container.homeVM, localServersVM: container.localServersVM
                        )
                    }
                }
            }
    }
}
