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
    @ViewBuilder let root: (BrowseViewModel) -> Root

    @Environment(\.showsPadChrome) private var showsPadChrome
    @Environment(\.miniPlayerInTabBar) private var miniPlayerInTabBar
    @State private var rootModel: BrowseViewModel?
    @State private var pages: [BrowsePage] = []

    var body: some View {
        NavigationStack(path: $pages) {
            ZStack {
                if let rootModel {
                    root(rootModel)
                        .modifier(AccountToolbar(state: state, container: container))
                        // Explicit: with its tabs at the top, iPad would otherwise show no title.
                        .navigationBarTitleDisplayMode(.large)
                }
            }
            .navigationDestination(for: BrowsePage.self) { page in
                DestinationView(state: state, container: container, model: page.model)
                    .navigationTitle(page.model.currentLocationName)
                    // The artwork header carries the title, so the bar keeps a small one.
                    .navigationBarTitleDisplayMode(page.model.opensOnArtwork ? .inline : .large)
            }
        }
        // Before the player bar, so the toast shows above it.
        .overlay(alignment: .bottom) { ToastOverlay(state: state) }
        .safeAreaInset(edge: .bottom, spacing: 0) { playerBar }
        .onAppear {
            if rootModel == nil { rootModel = makeModel() }
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
        // A breadcrumb leads to a page already on the stack: go back to it instead of stacking it again.
        if let index = pages.lastIndex(where: { $0.location == location }) {
            pages.removeSubrange((index + 1)...)
            return
        }
        let model = makeModel()
        model.start(at: location)
        pages.append(BrowsePage(model: model, location: location))
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
