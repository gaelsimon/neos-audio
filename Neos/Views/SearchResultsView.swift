import SwiftUI
import NeosDomain

struct SearchResultsView: View {
    let state: AppState
    let searchVM: SearchViewModel
    let browseVM: BrowseViewModel
    let service: any AudioService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
                filterChipsSection
                resultsContent
            }
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.background)
        .accessibilityIdentifier(AccessibilityID.Search.resultsView)
    }

    // MARK: - Filter Chips

    @ViewBuilder
    private var filterChipsSection: some View {
        FadingHorizontalScroll {
            HStack(spacing: DS.Spacing.sm) {
                // Service chips
                FilterChip(
                    label: "All Services",
                    isSelected: searchVM.selectedServiceFilter == nil,
                    action: { searchVM.selectServiceFilter(nil) }
                )
                ForEach(searchVM.allSearchableServices) { source in
                    FilterChip(
                        label: source.name,
                        isSelected: searchVM.selectedServiceFilter == source.sid,
                        icon: ServiceBranding.iconAssetName(for: source.name).map { Image($0) },
                        action: { searchVM.selectServiceFilter(source.sid) }
                    )
                }

                // Divider between service and category chips
                Divider()
                    .frame(height: 28)
                    .padding(.horizontal, DS.Spacing.xs)

                // Category chips
                FilterChip(
                    label: "All",
                    isSelected: searchVM.selectedCategoryFilter == nil,
                    action: { searchVM.selectCategoryFilter(nil) }
                )
                ForEach(searchVM.allCriteriaNames, id: \.scid) { criterion in
                    FilterChip(
                        label: criterion.name,
                        isSelected: searchVM.selectedCategoryFilter == criterion.scid,
                        action: { searchVM.selectCategoryFilter(criterion.scid) }
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    // MARK: - Results Content

    @ViewBuilder
    private var resultsContent: some View {
        if searchVM.isSearching && searchVM.serviceResults.isEmpty {
            SearchShimmerView()
        } else if !searchVM.isSearching && searchVM.serviceResults.isEmpty && !searchVM.query.isEmpty {
            EmptyStateView(icon: DS.Icons.search, message: "No results found")
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

        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if let source {
                serviceHeader(for: source, isLoading: isLoading)
            }

            if results.isEmpty && isLoading {
                // No old results to template from; generic shimmer fallback
                ShimmerCardRow(cardCount: 3)
                VStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        ShimmerListRow()
                    }
                }
            } else {
                ForEach(results, id: \.criteria.scid) { entry in
                    categorySection(
                        criteriaName: entry.criteria.name,
                        items: entry.items,
                        sid: sid,
                        scid: entry.criteria.scid,
                        isServiceLoading: isLoading
                    )
                }
            }
        }
        .padding(.vertical, DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.large)
                .fill(DS.Colors.surfaceContainer)
        )
        .padding(.horizontal, DS.Spacing.md)
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
        .padding(.horizontal, DS.Spacing.xl)
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
        isServiceLoading: Bool
    ) -> some View {
        let cardLayout = isCardLayout(items)

        let key = ServiceCriteriaKey(sid: sid, scid: scid)
        let showSeeAll = !isServiceLoading
            && items.count >= searchVM.previewCount
            && !searchVM.expandedCategories.contains(key)

        VStack(alignment: .leading, spacing: cardLayout ? DS.Spacing.md : DS.Spacing.sm) {
            HStack {
                Text(criteriaName)
                    .typography(.sectionHeader)

                Spacer()

                if showSeeAll {
                    HoverButton(action: {
                        seeAll(criteriaName: criteriaName, sid: sid, scid: scid)
                    }) { hovered in
                        Text("See All")
                            .typography(.secondary)
                            .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)

            if isServiceLoading {
                if cardLayout {
                    ShimmerCardRow(cardCount: min(items.count, searchVM.previewCount))
                } else {
                    VStack(spacing: 0) {
                        ForEach(0..<min(items.count, searchVM.previewCount), id: \.self) { _ in
                            ShimmerListRow()
                        }
                    }
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
                        title: item.name,
                        subtitle: item.artist,
                        isCircular: circular,
                        onTap: { handleItemTap(item, sid: sid) }
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private func categoryListContent(items: [BrowseItem], sid: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { item in
                BrowseItemRow(
                    item: item,
                    isNowPlaying: isNowPlaying(item),
                    onTap: { handleItemTap(item, sid: sid) },
                    onAddToQueue: { handleAddToQueue(item, sid: sid) }
                )
                .padding(.horizontal, DS.Spacing.lg)
            }
        }
    }

    // MARK: - Actions

    private func seeAll(criteriaName: String, sid: Int, scid: Int) {
        guard let source = searchVM.musicSource(for: sid) else { return }
        searchVM.suspendForNavigation(originHistoryIndex: browseVM.currentHistoryIndex)
        browseVM.navigateToSearchResults(
            source: source,
            categoryName: criteriaName,
            query: searchVM.query,
            scid: scid
        )
    }

    private func handleItemTap(_ item: BrowseItem, sid: Int) {
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
        guard item.playable else { return }
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
        searchVM.suspendForNavigation(originHistoryIndex: browseVM.currentHistoryIndex)
        if let cid = item.cid {
            browseVM.navigateToContainer(source: source, containerName: item.name, cid: cid, imageURL: item.imageURL)
        } else {
            browseVM.selectSource(source)
        }
    }

    private func isNowPlaying(_ item: BrowseItem) -> Bool {
        guard !state.nowPlaying.mid.isEmpty, let mid = item.mid else { return false }
        return state.nowPlaying.mid == mid
    }

}
