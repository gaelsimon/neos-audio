import SwiftUI

/// The search tab: the system search field, recent searches until something is typed, the results below.
struct MobileSearchView: View {
    let state: AppState
    let container: ViewModelContainer
    let model: BrowseViewModel
    @Environment(\.showsPadChrome) private var showsPadChrome

    private var searchVM: SearchViewModel { container.searchVM }

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
            // iPad would otherwise fold the field into a toolbar button: a second tap after the tab.
            placement: showsPadChrome ? .navigationBarDrawer(displayMode: .always) : .automatic
        )
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
