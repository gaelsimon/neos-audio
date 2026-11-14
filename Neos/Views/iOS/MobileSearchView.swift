import SwiftUI

/// The search tab: the system search field, recent searches as suggestions, the results below.
struct MobileSearchView: View {
    let state: AppState
    let container: ViewModelContainer
    let model: BrowseViewModel
    @Environment(\.showsPadChrome) private var showsPadChrome

    private var searchVM: SearchViewModel { container.searchVM }

    var body: some View {
        SearchResultsView(state: state, searchVM: searchVM, browseVM: model, service: searchVM.service)
            .navigationTitle("Search")
            .searchable(
                text: Binding(get: { searchVM.query }, set: { searchVM.onQueryChanged($0) }),
                // iPad would otherwise fold the field into a toolbar button: a second tap after the tab.
                placement: showsPadChrome ? .navigationBarDrawer(displayMode: .always) : .automatic
            )
            .searchSuggestions {
                if searchVM.query.isEmpty {
                    ForEach(searchVM.recentQueries, id: \.self) { query in
                        Text(query).searchCompletion(query)
                    }
                }
            }
    }
}
