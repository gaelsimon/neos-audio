import SwiftUI
import NeosDomain

struct SidebarView: View {
    let state: AppState
    let browseVM: BrowseViewModel
    let hiddenSIDs: Set<Int>
    var isSearchActive: Bool = false

    private var sections: SourceSections {
        SourceSections(sources: state.musicSources, signedIn: state.signedInUser != nil, hidden: hiddenSIDs)
    }

    /// No row is selected while search results cover the page.
    private var shownSelection: SidebarItem? {
        isSearchActive ? nil : SidebarItem(destination: browseVM.currentDestination, browseStack: browseVM.browseStack)
    }

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: { shownSelection },
            // Opening the shown row again would push a duplicate page and drop the forward history.
            set: { item in
                guard let item, item != shownSelection else { return }
                open(item)
            }
        )
    }

    var body: some View {
        let sections = sections
        VStack(spacing: 0) {
            sidebarLogo
                .padding(.horizontal, DS.Sidebar.logoInset)
                .padding(.bottom, DS.Spacing.sm)

            List(selection: selection) {
                row(.home, title: "Home", identifier: AccessibilityID.Sidebar.home) {
                    ServiceBranding.symbolTile(DS.Icons.home, size: DS.ImageSize.sidebarIcon)
                }

                if !sections.services.isEmpty {
                    Section {
                        ForEach(sections.services) { sourceRow($0) }
                    } header: {
                        Text("Services").accessibilityIdentifier(AccessibilityID.Sidebar.servicesSection)
                    }
                }

                if !sections.local.isEmpty {
                    Section("Local") {
                        ForEach(sections.local) { sourceRow($0) }
                    }
                }

                Section {
                    ForEach(sections.library) { entry in
                        row(.source(entry.id), title: entry.title, identifier: AccessibilityID.Sidebar.source(entry.id)) {
                            ServiceBranding.symbolTile(entry.symbol, size: DS.ImageSize.sidebarIcon)
                        }
                    }
                    row(.queue, title: "Queue", identifier: AccessibilityID.Sidebar.queue) {
                        ServiceBranding.symbolTile(DS.Icons.queue, size: DS.ImageSize.sidebarIcon)
                    } trailing: {
                        queueCount
                    }
                } header: {
                    Text("Library").accessibilityIdentifier(AccessibilityID.Sidebar.librarySection)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .tint(DS.Colors.accent)
            .accessibilityIdentifier(AccessibilityID.Sidebar.list)
        }
        .background(DS.Colors.background)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DS.Colors.border)
                .frame(width: 1)
                .ignoresSafeArea(edges: .top)
        }
    }

    // MARK: - Logo

    private var sidebarLogo: some View {
        HStack {
            Image("NeosLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 22)
            Spacer()
        }
        .padding(.top, DS.Spacing.xl)
    }

    // MARK: - Rows

    private func sourceRow(_ source: MusicSource) -> some View {
        row(.source(source.sid), title: source.name, identifier: AccessibilityID.Sidebar.source(source.sid)) {
            ServiceBranding.serviceIcon(for: source, size: DS.ImageSize.sidebarIcon)
        }
        .opacity(source.available ? 1 : 0.6)
    }

    private func row(
        _ item: SidebarItem,
        title: String,
        identifier: String,
        @ViewBuilder icon: () -> some View,
        @ViewBuilder trailing: () -> some View = { EmptyView() }
    ) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            icon()
            Text(title)
                .typography(.bodyPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
            trailing()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
        // Clicking the selected row changes no selection, so below a source's first page it goes back there itself.
        .simultaneousGesture(TapGesture().onEnded { open(item) }, including: leadsBackUp(item) ? .all : .subviews)
        .tag(item)
    }

    @ViewBuilder
    private var queueCount: some View {
        if !state.queue.isEmpty {
            Text("\(state.queue.count)")
                .typography(.badge)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(.quaternary, in: Capsule())
        }
    }

    // MARK: - Navigation

    private func leadsBackUp(_ item: SidebarItem) -> Bool {
        guard case .source = item, item == shownSelection else { return false }
        return browseVM.browseStack.count > 1
    }

    private func open(_ item: SidebarItem) {
        switch item {
        case .home:
            browseVM.navigateToHome()
        case .queue:
            browseVM.selectQueue()
        case .source(let sid):
            let sections = sections
            let sources = sections.services + sections.local + sections.library.map(\.source)
            guard let source = sources.first(where: { $0.sid == sid }) else { return }
            browseVM.selectSource(source)
        }
    }
}
