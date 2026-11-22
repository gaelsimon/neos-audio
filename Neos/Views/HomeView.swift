import SwiftUI
import NeosDomain

struct HomeView: View {
    let state: AppState
    let homeVM: HomeViewModel
    let browseVM: BrowseViewModel
    @Environment(\.groupInset) private var groupInset
    @Environment(\.groupSectionStyle) private var groupSectionStyle

    /// Maximum categories the VM may fetch (must match HomeViewModel).
    private let maxCategoriesPerService = 4
    /// How many category rows to show per service on the Home dashboard.
    private let displayedCategoriesPerService = 2

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                #if os(macOS)
                header
                #endif
                sections
            }
            .padding(.top, DS.Layout.pageTop)
            .padding(.bottom, DS.Spacing.xxl)
        }
        #if os(iOS)
        .refreshable { homeVM.refresh() }
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier(AccessibilityID.Home.view)
        .task {
            homeVM.loadHome()
        }
    }

    // MARK: - Header

    #if os(macOS)
    /// The navigation bar titles the page on iPhone and iPad, and pull to refresh reloads it.
    private var header: some View {
        HStack {
            Text("Home")
                .typography(.pageTitle)

            Spacer()

            HoverButton(action: { browseVM.navigateToSettings() }) { hovered in
                Image(systemName: DS.Icons.settings)
                    .typography(.bodyPrimary, color: hovered ? .white : DS.Colors.textSecondary)
            }
            .help("Configure Services")
            .accessibilityIdentifier(AccessibilityID.Home.configButton)

            HoverButton(action: { homeVM.refresh() }) { hovered in
                Image(systemName: DS.Icons.refresh)
                    .typography(.bodyPrimary, color: hovered ? .white : DS.Colors.textSecondary)
            }
            .help("Refresh")
            .accessibilityIdentifier(AccessibilityID.Home.refreshButton)
        }
        .pageMargins()
        .accessibilityIdentifier(AccessibilityID.Home.header)
    }
    #endif

    // MARK: - Sections

    @ViewBuilder
    private var sections: some View {
        recentlyPlayedSection
        favoritesSection
        serviceSections
        signInPrompt
        emptyState
    }

    // MARK: - History

    @ViewBuilder
    private var recentlyPlayedSection: some View {
        if !homeVM.recentlyPlayed.isEmpty {
            HomeSection(
                title: "History",
                isLoading: homeVM.isLoadingRecents,
                onSeeAll: { browseVM.selectSource(MusicSource(sid: 1026, name: "History")) }
            ) {
                HomeCardRow(items: homeVM.recentlyPlayed, sid: 1026, state: state) { item, sid in
                    homeVM.playItem(item, sid: sid)
                }
            }
            .accessibilityIdentifier(AccessibilityID.Home.recentlyPlayed)
        } else if homeVM.isLoadingRecents {
            HomeSection(title: "History") {
                PlaceholderCardRow()
            }
        }
    }

    // MARK: - Favorites

    @ViewBuilder
    private var favoritesSection: some View {
        if !homeVM.favorites.isEmpty {
            HomeSection(
                title: "Favorites",
                isLoading: homeVM.isLoadingFavorites,
                onSeeAll: { browseVM.selectSource(MusicSource(sid: 1028, name: "Favorites")) }
            ) {
                HomeCardRow(items: homeVM.favorites, sid: 1028, state: state) { item, sid in
                    homeVM.playItem(item, sid: sid)
                }
            }
            .accessibilityIdentifier(AccessibilityID.Home.favorites)
        } else if homeVM.isLoadingFavorites {
            HomeSection(title: "Favorites") {
                PlaceholderCardRow()
            }
        }
    }

    // MARK: - Service Sections

    @ViewBuilder
    private var serviceSections: some View {
        ForEach(homeVM.visibleStreamingSources) { source in
            serviceGroup(for: source)
        }
    }

    /// Renders one service as a group: branded container + logo + category sub-rows.
    @ViewBuilder
    private func serviceGroup(for source: MusicSource) -> some View {
        let isLoading = homeVM.loadingServiceSIDs.contains(source.sid)
        let categoryIndices = activeCategoryIndices(for: source.sid)
        let hasContent = !categoryIndices.isEmpty

        if hasContent || isLoading {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                HStack(spacing: DS.Spacing.md) {
                    ServiceBranding.serviceLabel(
                        for: source,
                        iconSize: DS.ImageSize.serviceIconLarge,
                        style: .sectionHeader
                    )

                    if isLoading {
                        Spinner(size: 12, lineWidth: 1.5)
                    }

                    Spacer()
                }
                .padding(.horizontal, groupInset)

                if hasContent {
                    ForEach(categoryIndices, id: \.self) { index in
                        serviceCategoryRow(source: source, categoryIndex: index)
                    }
                } else {
                    PlaceholderCardRow(inset: groupInset)
                }
            }
            .serviceGroupSurface()
        }
    }

    /// Returns category indices that have non-empty content for a given SID,
    /// capped to `displayedCategoriesPerService`.
    private func activeCategoryIndices(for sid: Int) -> [Int] {
        (0..<maxCategoriesPerService).filter { index in
            let key = ServiceCategoryKey(sid: sid, categoryIndex: index)
            if let items = homeVM.serviceCategories[key], !items.isEmpty {
                return true
            }
            return false
        }
        .prefix(displayedCategoriesPerService)
        .map { $0 }
    }

    @ViewBuilder
    private func serviceCategoryRow(source: MusicSource, categoryIndex: Int) -> some View {
        let key = ServiceCategoryKey(sid: source.sid, categoryIndex: categoryIndex)
        let items = homeVM.serviceCategories[key]
        let name = homeVM.serviceCategoryNames[key]
        let cid = homeVM.serviceCategoryCIDs[key]

        if let items, !items.isEmpty {
            HomeSection(
                title: name ?? "",
                titleStyle: groupSectionStyle,
                onSeeAll: {
                    if let cid {
                        browseVM.navigateToContainer(source: source, containerName: name ?? "", cid: cid)
                    } else {
                        browseVM.selectSource(source)
                    }
                },
                inset: groupInset
            ) {
                HomeCardRow(items: items, sid: source.sid, state: state, inset: groupInset) { item, sid in
                    handleServiceCardTap(item, sid: sid)
                }
            }
        }
    }

    private func handleServiceCardTap(_ item: BrowseItem, sid: Int) {
        if item.browsable, let cid = item.cid,
           let source = state.musicSources.first(where: { $0.sid == sid }) {
            browseVM.navigateToContainer(source: source, containerName: item.displayTitle, cid: cid, imageURL: item.imageURL)
        } else {
            homeVM.playItem(item, sid: sid)
        }
    }

    // MARK: - Sign In Prompt

    /// Shows when not signed into HEOS account and no streaming service content is visible.
    @ViewBuilder
    private var signInPrompt: some View {
        let hasServiceContent = homeVM.visibleStreamingSources.contains { source in
            !activeCategoryIndices(for: source.sid).isEmpty
        }
        let isLoadingServices = !homeVM.loadingServiceSIDs.isEmpty

        if state.signedInUser == nil && !hasServiceContent && !isLoadingServices {
            SignInPromptView(
                title: "Sign in to unlock your music",
                message: "Connect your HEOS account to see your streaming services like Tidal, Qobuz, and more.",
                style: .card,
                onSignIn: { browseVM.navigateToSettings() }
            )
        }
    }

    // MARK: - Empty State

    @ViewBuilder
    private var emptyState: some View {
        let hasNoContent = homeVM.recentlyPlayed.isEmpty
            && homeVM.favorites.isEmpty
            && homeVM.visibleStreamingSources.allSatisfy { source in
                activeCategoryIndices(for: source.sid).isEmpty
            }
        let isNotLoading = !homeVM.isLoadingRecents && !homeVM.isLoadingFavorites && homeVM.loadingServiceSIDs.isEmpty

        if hasNoContent && isNotLoading {
            ContentUnavailableView(
                "Nothing Here Yet",
                systemImage: DS.Icons.musicNoteHouse,
                description: Text("Select a source to start browsing.")
            )
                .padding(.top, DS.Spacing.xxxl)
                .accessibilityIdentifier(AccessibilityID.Home.emptyState)
        }
    }
}
