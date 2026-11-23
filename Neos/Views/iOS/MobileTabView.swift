import SwiftUI
import NeosDomain

extension EnvironmentValues {
    /// The tab bar holds the mini player, so the pages leave it out.
    @Entry var miniPlayerInTabBar = false
}

/// Tabs on iPhone and a sidebar on iPad, from one declaration. A wide iPad lists every source in its sidebar; its
/// tab bar, an iPhone and a narrow iPad window reach them through the Library tab.
struct MobileTabView: View {
    let state: AppState
    let container: ViewModelContainer
    @State private var selection: MobileTab = .home
    @Environment(\.showsPadChrome) private var showsPadChrome

    var body: some View {
        // The iPad keeps its player in the pages.
        if #available(iOS 26, *), !DeviceIdiom.isPad {
            tabs
                .tabViewBottomAccessory {
                    MiniPlayerAccessory(state: state, playerVM: container.playerVM)
                        .disabled(!state.isConnected)
                }
                // iOS 27 ends the search results under the mini player while their tab bar may shrink.
                .tabBarMinimizeBehavior(selection == .search ? .never : .onScrollDown)
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
        let shown = selection.showing(sourceTabs: showsPadChrome, sources: sources)
        return TabView(selection: $selection) {
            Tab("Home", systemImage: "house", value: MobileTab.home) {
                PagedStack(state: state, container: container, isSelected: selection == .home) { model in
                    DestinationView(state: state, container: container, model: model)
                        .navigationTitle("Home")
                }
            }
            Tab("Library", systemImage: "square.stack", value: MobileTab.library) {
                PagedStack(state: state, container: container, isSelected: selection == .library) { model in
                    LibraryView(state: state, container: container, model: model)
                }
            }
            Tab(value: MobileTab.search, role: .search) {
                PagedStack(state: state, container: container, isSelected: selection == .search) { model in
                    MobileSearchView(state: state, container: container, model: model)
                }
            }

            TabSection("Library") {
                ForEach(sources.library) { entry in
                    sourceTab(entry.source, title: entry.title, icon: Image(systemName: entry.symbol))
                }
                Tab("Queue", systemImage: DS.Icons.queue, value: MobileTab.queue) {
                    PagedStack(state: state, container: container, start: .queue, isSelected: selection == .queue) { model in
                        DestinationView(state: state, container: container, model: model)
                            .navigationTitle("Queue")
                    }
                }
            }
            .hidden(!showsPadChrome)
            // On the section: iPadOS 27 ignores it on the tabs inside.
            .tabPlacement(.sidebarOnly)
            TabSection("Services") {
                ForEach(sources.services) { source in
                    sourceTab(source, title: source.name, icon: SidebarIcon.image(for: source))
                }
            }
            .hidden(!showsPadChrome)
            .tabPlacement(.sidebarOnly)
            TabSection("Local") {
                ForEach(sources.local) { source in
                    sourceTab(source, title: source.name, icon: SidebarIcon.image(for: source))
                }
            }
            .hidden(!showsPadChrome)
            .tabPlacement(.sidebarOnly)
        }
        .tabViewStyle(.sidebarAdaptable)
        // A narrower window or a source going away takes the open tab with it. iOS 27 can crash on a selection
        // whose tab is hidden, and a binding that corrects it on the way in breaks the iPad's search there.
        .onChange(of: shown) { _, tab in selection = tab }
    }

    /// A source as a sidebar entry with a stack of its own.
    private func sourceTab(_ source: MusicSource, title: String, icon: Image) -> some TabContent<MobileTab> {
        Tab(value: MobileTab.source(source.sid)) {
            PagedStack(
                state: state, container: container, start: .root(of: source), isSelected: selection == .source(source.sid)
            ) { model in
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
