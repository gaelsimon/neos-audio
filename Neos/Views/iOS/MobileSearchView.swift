import SwiftUI

/// The search tab: the system search field, recent searches until something is typed, the results below.
struct MobileSearchView: View {
    let state: AppState
    let container: ViewModelContainer
    let model: BrowseViewModel
    @Environment(\.showsPadChrome) private var showsPadChrome

    private var searchVM: SearchViewModel { container.searchVM }

    /// iPad would otherwise fold the field into a toolbar button, a second tap after the tab. iOS 27 puts the
    /// iPhone's field in the navigation bar too, where a list of recent searches would hide it until pulled down.
    private var keepsFieldUnderTitle: Bool {
        if showsPadChrome { return true }
        if #available(iOS 27, *) { return true }
        return false
    }

    var body: some View {
        Group {
            if searchVM.query.isEmpty {
                RecentSearchesView(searchVM: searchVM, serviceNames: searchVM.allSearchableServices.map(\.name))
            } else {
                SearchResultsView(state: state, searchVM: searchVM, browseVM: model, service: searchVM.service)
            }
        }
        .navigationTitle("Search")
        .searchable(
            text: Binding(get: { searchVM.query }, set: { searchVM.onQueryChanged($0) }),
            placement: keepsFieldUnderTitle ? .navigationBarDrawer(displayMode: .always) : .automatic
        )
        // iPad draws its tabs in the bar a search would hide, and iPadOS 26 offers no Cancel to bring them back.
        .searchPresentationToolbarBehavior(showsPadChrome ? .avoidHidingContent : .automatic)
    }
}

/// What the tab shows before a search: the last searches, or what can be searched.
private struct RecentSearchesView: View {
    let searchVM: SearchViewModel
    let serviceNames: [String]

    var body: some View {
        if searchVM.recentQueries.isEmpty {
            ContentUnavailableView(
                "Search Your Services",
                systemImage: "magnifyingglass",
                description: Text(serviceNames.isEmpty
                    ? "Find tracks, albums, artists and stations."
                    : "Find tracks, albums, artists and stations in \(serviceNames.formatted(.list(type: .and))).")
            )
        } else {
            List {
                Section {
                    ForEach(searchVM.recentQueries, id: \.self) { query in
                        Button { searchVM.onQueryChanged(query) } label: {
                            Label(query, systemImage: "clock.arrow.circlepath")
                        }
                    }
                } header: {
                    HStack {
                        Text("Recent Searches")
                        Spacer()
                        Button("Clear") { searchVM.clearHistory() }
                            .accessibilityLabel("Clear Recent Searches")
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
