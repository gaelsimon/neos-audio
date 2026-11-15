import SwiftUI
import NeosDomain

extension EnvironmentValues {
    /// The tab bar holds the mini player, so the pages leave it out.
    @Entry var miniPlayerInTabBar = false
    /// Written by the pages: only a tab's content knows where its tab view draws the tabs.
    @Entry var isSidebarShowing = Binding.constant(false)
}

/// Tabs on iPhone and a sidebar on iPad, from one declaration. A wide iPad lists every source in its sidebar; its
/// tab bar, an iPhone and a narrow iPad window reach them through the Library tab.
struct MobileTabView: View {
    enum Section: Hashable {
        case home
        case library
        case search
        case source(Int)
        case queue
    }

    let state: AppState
    let container: ViewModelContainer
    @State private var selection: Section = .home
    @State private var isSidebarShowing = false
    @Environment(\.showsPadChrome) private var showsPadChrome

    var body: some View {
        // The iPad keeps its player in the pages.
        if #available(iOS 26, *), !DeviceIdiom.isPad {
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
        let sources = SourceSections(
            sources: state.musicSources,
            signedIn: state.signedInUser != nil,
            hidden: container.homeVM.hiddenSIDs
        )
        return TabView(selection: $selection) {
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
            // The sidebar lists the sources itself. The tab stays while it is the page on screen.
            .hidden(isSidebarShowing && selection != .library)
            Tab(value: Section.search, role: .search) {
                PagedStack(state: state, container: container) { model in
                    MobileSearchView(state: state, container: container, model: model)
                }
            }

            TabSection("Library") {
                ForEach(sources.library) { entry in
                    sourceTab(entry.source, title: entry.title, icon: Image(systemName: entry.symbol))
                }
                Tab("Queue", systemImage: DS.Icons.queue, value: Section.queue) {
                    PagedStack(state: state, container: container, start: .queue) { model in
                        DestinationView(state: state, container: container, model: model)
                            .navigationTitle("Queue")
                    }
                }
            }
            .hidden(!showsPadChrome)
            .defaultVisibility(.hidden, for: .tabBar)
            TabSection("Services") {
                ForEach(sources.services) { source in
                    sourceTab(source, title: source.name, icon: SidebarIcon.image(for: source))
                }
            }
            .hidden(!showsPadChrome)
            .defaultVisibility(.hidden, for: .tabBar)
            TabSection("Local") {
                ForEach(sources.local) { source in
                    sourceTab(source, title: source.name, icon: SidebarIcon.image(for: source))
                }
            }
            .hidden(!showsPadChrome)
            .defaultVisibility(.hidden, for: .tabBar)
        }
        .tabViewStyle(.sidebarAdaptable)
        .environment(\.isSidebarShowing, $isSidebarShowing)
        .onChange(of: state.musicSources.map(\.sid)) { _, sids in
            // A source that went away takes its tab with it.
            if case .source(let sid) = selection, !sids.contains(sid) {
                selection = .home
            }
        }
        .onChange(of: showsPadChrome) { _, isWide in
            // A narrow window has no source tabs; the open one may be the one that goes.
            switch selection {
            case .source where !isWide, .queue where !isWide: selection = .library
            default: break
            }
        }
        // iPad only, and not under the player, which shows the queue itself; an iPhone opens it from the player.
        .inspector(isPresented: Binding(
            get: { showsPadChrome && state.isQueuePanelOpen && !state.isNowPlayingCanvasOpen },
            set: { state.isQueuePanelOpen = $0 }
        )) {
            QueuePanelView(state: state, viewModel: container.queuePanelVM)
        }
    }

    /// A source as a sidebar entry with a stack of its own.
    private func sourceTab(_ source: MusicSource, title: String, icon: Image) -> some TabContent<Section> {
        Tab(value: Section.source(source.sid)) {
            PagedStack(state: state, container: container, start: .root(of: source)) { model in
                DestinationView(state: state, container: container, model: model)
                    .navigationTitle(title)
            }
        } label: {
            Label { Text(title) } icon: { icon }
        }
    }
}

/// A sidebar draws a tab's image at its own size, so a service's logo is scaled down to a symbol's first.
@MainActor
private enum SidebarIcon {
    private static let side: CGFloat = 24
    private static var scaledLogos: [String: UIImage] = [:]

    static func image(for source: MusicSource) -> Image {
        guard let asset = ServiceBranding.iconAssetName(for: source.name), let logo = scaledLogo(named: asset) else {
            return Image(systemName: ServiceBranding.symbolName(for: source.name))
        }
        return Image(uiImage: logo)
    }

    private static func scaledLogo(named asset: String) -> UIImage? {
        if let scaled = scaledLogos[asset] { return scaled }
        guard let logo = UIImage(named: asset) else { return nil }
        let scale = side / max(logo.size.width, logo.size.height)
        let size = CGSize(width: logo.size.width * scale, height: logo.size.height * scale)
        let scaled = UIGraphicsImageRenderer(size: size)
            .image { _ in logo.draw(in: CGRect(origin: .zero, size: size)) }
            .withRenderingMode(.alwaysTemplate)
        scaledLogos[asset] = scaled
        return scaled
    }
}
