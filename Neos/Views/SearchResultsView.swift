import SwiftUI
import NeosDomain

struct SearchResultsView: View {
    let state: AppState
    let searchVM: SearchViewModel
    let browseVM: BrowseViewModel
    let service: any AudioService
    @Environment(\.groupInset) private var groupInset
    @Environment(\.groupListInset) private var groupListInset
    @Environment(\.groupSectionStyle) private var groupSectionStyle

    var body: some View {
        ScrollView {
            resultsContent
                .padding(.top, DS.Spacing.xl)
                .padding(.bottom, DS.Spacing.xxl)
        }
        .stickyHeader {
            filterMenus
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.background)
        .accessibilityIdentifier(AccessibilityID.Search.resultsView)
    }

    // MARK: - Filters

    /// Services ticked together, one kind at a time; the kinds are what the ticked services search for.
    private var filterMenus: some View {
        HStack(spacing: DS.Spacing.sm) {
            filterMenu(serviceTitle, icon: serviceIcon, isActive: !searchVM.activeServiceFilters.isEmpty) {
                Toggle("All Services", isOn: Binding(
                    get: { searchVM.activeServiceFilters.isEmpty },
                    set: { _ in searchVM.selectServiceFilter(nil) }
                ))
                Divider()
                ForEach(searchVM.allSearchableServices) { source in
                    Toggle(source.name, isOn: Binding(
                        get: { searchVM.activeServiceFilters.contains(source.sid) },
                        set: { _ in searchVM.selectServiceFilter(source.sid) }
                    ))
                    #if os(iOS)
                    // Open while several services are ticked; a Mac menu always closes.
                    .menuActionDismissBehavior(.disabled)
                    #endif
                }
            }

            filterMenu(categoryTitle, isActive: searchVM.selectedCategoryFilter != nil) {
                Picker("Kind", selection: Binding(
                    get: { searchVM.selectedCategoryFilter },
                    set: { searchVM.chooseCategoryFilter($0) }
                )) {
                    Text("All Kinds").tag(Int?.none)
                    ForEach(searchVM.categoryOptions, id: \.scid) { criterion in
                        Text(SearchCategoryName.plural(criterion.name)).tag(Int?.some(criterion.scid))
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .pageMargins()
    }

    /// The chosen services in the order of the menu.
    private var chosenServices: [MusicSource] {
        let chosen = searchVM.activeServiceFilters
        return searchVM.allSearchableServices.filter { chosen.contains($0.sid) }
    }

    private var serviceTitle: String {
        let chosen = chosenServices
        switch chosen.count {
        case 0: return "All Services"
        case 1, 2: return chosen.map(\.name).joined(separator: ", ")
        default: return "\(chosen.count) Services"
        }
    }

    private var serviceIcon: Image? {
        guard chosenServices.count == 1, let source = chosenServices.first else { return nil }
        return ServiceBranding.iconAssetName(for: source.name).map { Image($0) }
    }

    private var categoryTitle: String {
        guard let scid = searchVM.selectedCategoryFilter,
              let criterion = searchVM.categoryOptions.first(where: { $0.scid == scid }) else { return "All Kinds" }
        return SearchCategoryName.plural(criterion.name)
    }

    private func filterMenu(
        _ title: String, icon: Image? = nil, isActive: Bool, @ViewBuilder content: () -> some View
    ) -> some View {
        let menu = Menu {
            content()
        } label: {
            #if os(iOS)
            HStack(spacing: DS.Spacing.xs) {
                if let icon {
                    icon
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }
                Text(title)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            #else
            // A Mac menu draws its label's image at full size.
            Text(title)
            #endif
        }
        .buttonBorderShape(.capsule)
        .fixedSize()

        // A Mac menu button takes no tint; its title alone says which filter is in use.
        return menu
            .buttonStyle(.bordered)
            .tint(isActive ? DS.Colors.accent : nil)
    }

    // MARK: - Results Content

    @ViewBuilder
    private var resultsContent: some View {
        if searchVM.isSearching && searchVM.serviceResults.isEmpty {
            SearchPlaceholderView()
        } else if !searchVM.isSearching && searchVM.filteredServiceSIDs.isEmpty && !searchVM.query.isEmpty {
            ContentUnavailableView.search(text: searchVM.query)
                .padding(.top, DS.Spacing.xxxl)
        } else {
            ForEach(searchVM.filteredServiceSIDs, id: \.self) { sid in
                serviceSection(for: sid)
            }
        }
    }

    // MARK: - Service Section

    @ViewBuilder
    private func serviceSection(for sid: Int) -> some View {
        let source = searchVM.musicSource(for: sid)
        let isLoading = searchVM.loadingServiceSIDs.contains(sid)
        let results = searchVM.filteredResults(for: sid)

        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            if let source {
                serviceHeader(for: source, isLoading: isLoading)
            }

            if results.isEmpty && isLoading {
                // No old results to template from, so generic placeholders
                PlaceholderCardRow(cardCount: 3, inset: groupInset)
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        PlaceholderRow()
                    }
                }
                .padding(.horizontal, groupListInset)
            } else {
                ForEach(results, id: \.criteria.scid) { entry in
                    categorySection(
                        criteriaName: SearchCategoryName.plural(entry.criteria.name),
                        items: entry.items,
                        sid: sid,
                        scid: entry.criteria.scid,
                        isPending: searchVM.isPending(ServiceCriteriaKey(sid: sid, scid: entry.criteria.scid))
                    )
                }
            }
        }
        .serviceGroupSurface()
    }

    // MARK: - Service Header

    @ViewBuilder
    private func serviceHeader(for source: MusicSource, isLoading: Bool) -> some View {
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
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(AccessibilityID.Search.serviceHeader(source.sid))
    }

    // MARK: - Category Section

    private func isCardLayout(_ items: [BrowseItem]) -> Bool {
        guard let type = items.first?.type else { return false }
        return type == .artist || type == .album || type == .playlist
    }

    private func isArtistCategory(_ items: [BrowseItem]) -> Bool {
        items.first?.type == .artist
    }

    @ViewBuilder
    private func categorySection(
        criteriaName: String,
        items: [BrowseItem],
        sid: Int,
        scid: Int,
        isPending: Bool
    ) -> some View {
        let cardLayout = isCardLayout(items)

        let key = ServiceCriteriaKey(sid: sid, scid: scid)
        let showSeeAll = !isPending
            && items.count >= searchVM.previewCount
            && !searchVM.expandedCategories.contains(key)

        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(criteriaName)
                    .typography(groupSectionStyle)

                Spacer()

                if showSeeAll {
                    TextActionButton(title: "See All") {
                        seeAll(criteriaName: criteriaName, sid: sid, scid: scid)
                    }
                }
            }
            .padding(.horizontal, groupInset)

            if isPending {
                if cardLayout {
                    PlaceholderCardRow(cardCount: min(items.count, searchVM.previewCount), inset: groupInset)
                } else {
                    VStack(spacing: 0) {
                        ForEach(0..<min(items.count, searchVM.previewCount), id: \.self) { _ in
                            PlaceholderRow()
                        }
                    }
                    .padding(.horizontal, groupListInset)
                }
            } else if cardLayout {
                categoryCardContent(items: items, circular: isArtistCategory(items), sid: sid)
            } else {
                categoryListContent(items: items, sid: sid)
            }

            if searchVM.loadingMoreCategories.contains(key) {
                HStack {
                    Spacer()
                    Spinner(size: 16, lineWidth: 2)
                    Spacer()
                }
                .padding(.vertical, DS.Spacing.sm)
            }
        }
    }

    // MARK: - Category Content

    private func categoryCardContent(items: [BrowseItem], circular: Bool, sid: Int) -> some View {
        FadingHorizontalScroll(gradientColor: DS.Colors.surfaceContainer) {
            HStack(spacing: DS.Spacing.lg) {
                ForEach(items) { item in
                    HomeCard(
                        imageURL: item.resolvedImageURL,
                        title: item.displayTitle,
                        subtitle: item.artist,
                        isCircular: circular,
                        externalLink: ExternalLinkMenu.make(for: item, sid: sid, sources: state.musicSources),
                        state: state,
                        onTap: { handleItemTap(item, sid: sid) }
                    )
                }
            }
            .padding(.horizontal, groupInset)
        }
    }

    private func categoryListContent(items: [BrowseItem], sid: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                BrowseItemRow(
                    item: item,
                    isNowPlaying: isNowPlaying(item),
                    externalLink: ExternalLinkMenu.make(for: item, sourceName: searchVM.musicSource(for: sid)?.name),
                    state: state,
                    onTap: { handleItemTap(item, sid: sid) },
                    onAddToQueue: { handleAddToQueue(item, sid: sid) }
                )
            }
        }
        .padding(.horizontal, groupListInset)
    }

    // MARK: - Actions

    private func seeAll(criteriaName: String, sid: Int, scid: Int) {
        guard let source = searchVM.musicSource(for: sid) else { return }
        searchVM.commitQueryToHistory()
        browseVM.navigateToSearchResults(
            source: source,
            categoryName: criteriaName,
            query: searchVM.query,
            scid: scid
        )
    }

    private func handleItemTap(_ item: BrowseItem, sid: Int) {
        searchVM.commitQueryToHistory()
        if item.browsable {
            browseInto(item, sid: sid)
        } else if item.playable {
            playItem(item, sid: sid)
        }
    }

    private func playItem(_ item: BrowseItem, sid: Int) {
        let effectiveSID = item.sid ?? sid
        let cid = item.cid ?? ""
        Task {
            do {
                try await PlaybackRouter.play(
                    item, sid: effectiveSID, cid: cid,
                    service: service, state: state
                )
            } catch {
                state.showToast(
                    error.localizedDescription,
                    icon: DS.Icons.warning,
                    style: .error
                )
            }
        }
    }

    private func handleAddToQueue(_ item: BrowseItem, sid: Int) {
        guard item.canJoinQueue else { return }
        searchVM.commitQueryToHistory()
        let effectiveSID = item.sid ?? sid
        let cid = item.cid ?? ""
        guard let pid = state.selectedPlayerID else {
            state.showNoPlayerToast()
            return
        }
        Task {
            do {
                try await service.addToQueue(
                    pid: pid, sid: effectiveSID, cid: cid,
                    mid: item.mid, criteria: .addToEnd
                )
                state.noteQueueEdit()
                state.showToast("Added to queue", icon: DS.Icons.addedToQueue, style: .success)
            } catch {
                state.showToast(
                    error.localizedDescription,
                    icon: DS.Icons.warning,
                    style: .error
                )
            }
        }
    }

    private func browseInto(_ item: BrowseItem, sid: Int) {
        let effectiveSID = item.sid ?? sid
        guard let source = searchVM.musicSource(for: effectiveSID) else { return }
        if let cid = item.cid {
            browseVM.navigateToContainer(source: source, containerName: item.displayTitle, cid: cid, imageURL: item.imageURL)
        } else {
            browseVM.selectSource(source)
        }
    }

    private func isNowPlaying(_ item: BrowseItem) -> Bool {
        state.isNowPlaying(item)
    }

}
