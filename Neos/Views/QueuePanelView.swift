import SwiftUI
import NeosDomain

struct QueuePanelView: View {

    private enum Tab: Hashable {
        case queue
        case recentlyPlayed
    }

    let state: AppState
    let viewModel: QueuePanelViewModel

    @State private var selectedTab: Tab = .queue

    /// Solid background color for canvas mode, derived from the most vibrant dominant artwork color.
    private var canvasPanelColor: Color {
        state.canvasDominantColors
            .max { lhs, rhs in
                let ls = NSColor(lhs).saturationComponent
                let rs = NSColor(rhs).saturationComponent
                return ls < rs
            } ?? Color(white: 0.06)
    }

    var body: some View {
        Group {
            if viewModel.isEmpty && !viewModel.isLoadingHistory {
                EmptyStateView(icon: DS.Icons.playlists, message: "Nothing playing")
                    .accessibilityIdentifier(AccessibilityID.QueuePanel.emptyState)
            } else {
                VStack(spacing: 0) {
                    SegmentedTab(selection: $selectedTab, tabs: [.queue, .recentlyPlayed]) { tab in
                        switch tab {
                        case .queue: "Queue"
                        case .recentlyPlayed: "Recently Played"
                        }
                    }
                    .accessibilityIdentifier(AccessibilityID.QueuePanel.tabBar)

                    if selectedTab == .queue {
                        queueTabContent
                    } else {
                        recentlyPlayedTabContent
                    }
                }
                .onChange(of: state.nowPlaying) { _, _ in
                    if state.isQueuePanelOpen {
                        viewModel.onTrackChanged()
                    }
                }
                .onChange(of: state.queue) { _, _ in
                    viewModel.refreshDisplayData()
                }
                .onChange(of: selectedTab) { _, tab in
                    if tab == .recentlyPlayed {
                        viewModel.loadHistoryIfNeeded()
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background {
            if state.isNowPlayingCanvasOpen {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(canvasPanelColor)
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(.black.opacity(0.5))
                }
            } else {
                UnevenRoundedRectangle(topLeadingRadius: DS.Radius.large, bottomLeadingRadius: DS.Radius.large)
                    .fill(DS.Colors.surfaceElevated)
            }
        }
        .clipShape(state.isNowPlayingCanvasOpen
            ? AnyShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
            : AnyShape(UnevenRoundedRectangle(topLeadingRadius: DS.Radius.large, bottomLeadingRadius: DS.Radius.large)))
        .padding(state.isNowPlayingCanvasOpen ? DS.Spacing.md : 0)
        .shadow(color: .black.opacity(0.3), radius: 8, x: -4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.QueuePanel.view)
        .accessibilityLabel("Queue and history panel")
        .task {
            viewModel.onPanelOpen()
        }
    }

    // MARK: - History Sections

    @ViewBuilder
    private var historySection: some View {
        let songs = viewModel.recentSongs
        let stations = viewModel.recentStations
        let hasContent = !songs.isEmpty || !stations.isEmpty || viewModel.isLoadingHistory

        if hasContent {
            if viewModel.isLoadingHistory && songs.isEmpty && stations.isEmpty {
                Spinner(size: 16, lineWidth: 2)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.lg)
            }

            // Recent Songs
            if !songs.isEmpty {
                Section(header: sectionHeader("Recent Songs")) {
                    ForEach(songs) { item in
                        QueuePanelRow(
                            name: item.name,
                            artist: item.artist,
                            imageURL: item.imageURL,
                            isStation: false,
                            isNowPlaying: false,
                            showRemoveButton: false,
                            onTap: { viewModel.playRecentItem(item) }
                        )
                    }
                }
                .accessibilityIdentifier(AccessibilityID.QueuePanel.historySection)
            }

            // Recent Stations
            if !stations.isEmpty {
                Section(header: sectionHeader("Recent Stations")) {
                    ForEach(Array(stations.enumerated()), id: \.offset) { index, item in
                        QueuePanelRow(
                            name: item.name,
                            artist: item.artist ?? "",
                            imageURL: item.imageURL,
                            isStation: true,
                            isNowPlaying: false,
                            showRemoveButton: false,
                            onTap: { viewModel.playHistoryStation(item) }
                        )
                        .accessibilityIdentifier(AccessibilityID.QueuePanel.historyRow(index))
                        .accessibilityLabel("\(item.name), played recently")
                    }
                }
            }
        }
    }

    // MARK: - Now Playing Section

    @ViewBuilder
    private var nowPlayingSection: some View {
        if !state.nowPlaying.mid.isEmpty {
            Section(header: sectionHeader("Now Playing")) {
                if let queueItem = viewModel.nowPlayingQueueItem {
                    QueuePanelRow(
                        name: queueItem.song,
                        artist: queueItem.artist,
                        imageURL: queueItem.imageURL,
                        isStation: false,
                        isNowPlaying: true,
                        showRemoveButton: false,
                        onTap: { }
                    )
                    .id("now-playing")
                } else {
                    // Standalone now playing (station or not in queue)
                    QueuePanelRow(
                        name: state.nowPlaying.song,
                        artist: state.nowPlaying.station ?? state.nowPlaying.artist,
                        imageURL: state.resolvedImageURL(forMID: state.nowPlaying.mid, originalURL: state.nowPlaying.imageURL),
                        isStation: state.nowPlaying.station != nil,
                        isNowPlaying: true,
                        showRemoveButton: false,
                        onTap: { }
                    )
                    .id("now-playing")
                }
            }
            .accessibilityIdentifier(AccessibilityID.QueuePanel.nowPlayingSection)
        }
    }

    // MARK: - Up Next Section

    @ViewBuilder
    private var upNextSection: some View {
        if !viewModel.upNextItems.isEmpty {
            Section(header: sectionHeader("Up Next")) {
                ForEach(viewModel.upNextItems) { item in
                    QueuePanelRow(
                        name: item.song,
                        artist: item.artist,
                        imageURL: item.imageURL,
                        isStation: false,
                        isNowPlaying: false,
                        showRemoveButton: true,
                        onTap: { viewModel.playQueueItem(item) },
                        onRemove: { viewModel.removeQueueItem(item) }
                    )
                    .accessibilityIdentifier(AccessibilityID.QueuePanel.upNextRow(item.qid))
                    .accessibilityLabel("\(item.song) by \(item.artist), up next")
                }
            }
            .accessibilityIdentifier(AccessibilityID.QueuePanel.upNextSection)
        } else if viewModel.nowPlayingQueueItem != nil || !state.nowPlaying.mid.isEmpty {
            // Show empty Up Next state when something is playing but queue is empty after it
            Section(header: sectionHeader("Up Next")) {
                Text("Queue is empty")
                    .typography(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.lg)
            }
        }
    }

    // MARK: - Tab Content

    private var queueTabContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                nowPlayingSection
                upNextSection
            }
        }
    }

    private var recentlyPlayedTabContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                historySection
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: DS.Spacing.xxl)
            HStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .typography(.bodyEmphasis)
                Spacer()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                if state.isNowPlayingCanvasOpen {
                    canvasPanelColor
                    Color.black.opacity(0.5)
                } else {
                    DS.Colors.surfaceElevated
                }
            }
        )
    }
}
