import SwiftUI
import NeosDomain

struct QueuePanelView: View {

    private enum Tab: Hashable {
        case queue
        case recentlyPlayed
    }

    let state: AppState
    let viewModel: QueuePanelViewModel
    /// The Mac's card closes itself; a sheet or an iPad column has its own way out.
    var onClose: (() -> Void)?
    var onClear: (() -> Void)?
    /// Up Next alone, over the player's own colours: the player shows what plays, the library keeps the history.
    var inPlayer = false

    @State private var selectedTab: Tab = .queue
    @State private var showClearConfirmation = false

    private var isEmptyState: Bool { viewModel.isEmpty && !viewModel.isLoadingHistory }

    var body: some View {
        VStack(spacing: 0) {
            if !inPlayer {
                header
            }

            if isEmptyState || (selectedTab == .queue && viewModel.isQueueTabEmpty) {
                ContentUnavailableView("Nothing Playing", systemImage: DS.Icons.playlists)
                    .frame(maxHeight: .infinity)
                    .accessibilityIdentifier(AccessibilityID.QueuePanel.emptyState)
            } else if selectedTab == .queue {
                queueTabContent
            } else {
                recentlyPlayedTabContent
            }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .recentlyPlayed {
                viewModel.loadHistoryIfNeeded()
            }
        }
        // On the panel, which outlives the Up Next header the button sits in.
        .modifier(ClearQueueConfirmation(isPresented: $showClearConfirmation) { onClear?() })
        .frame(maxHeight: .infinity)
        .background {
            if !inPlayer {
                QueuePanelFill(state: state)
                    .ignoresSafeArea()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.QueuePanel.view)
        .accessibilityLabel(inPlayer ? "Queue" : "Queue and history panel")
        .task {
            viewModel.onPanelOpen()
        }
        // An inspector builds this once, with its window and before the speaker answers: every refresh comes from the state.
        .onChange(of: state.isQueuePanelOpen) { _, isOpen in
            if isOpen {
                viewModel.onPanelOpen()
            }
        }
        .onChange(of: state.nowPlaying) { _, _ in
            viewModel.onTrackChanged()
        }
        .onChange(of: state.queue) { _, _ in
            viewModel.refreshDisplayData()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 0) {
            if isEmptyState {
                Spacer()
            } else {
                SegmentedTab(selection: $selectedTab, tabs: [.queue, .recentlyPlayed]) { tab in
                    switch tab {
                    case .queue: "Queue"
                    case .recentlyPlayed: "Recently Played"
                    }
                }
                .accessibilityIdentifier(AccessibilityID.QueuePanel.tabBar)
            }

            if let onClose {
                HoverButton(action: onClose, accessibilityID: AccessibilityID.QueuePanel.closeButton) { hovered in
                    Image(systemName: DS.Icons.close)
                        .font(DS.IconFont.smEmphasis)
                        .foregroundStyle(hovered ? .primary : DS.Colors.textTertiary)
                }
                .accessibilityLabel("Close")
                .padding(.trailing, DS.Spacing.lg)
            }
        }
    }

    @ViewBuilder
    private var clearButton: some View {
        if onClear != nil {
            TextActionButton(title: "Clear") { showClearConfirmation = true }
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
                            onTap: { viewModel.playRecentItem(item) },
                            externalLink: item.externalLink,
                            state: state
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
                            onTap: { viewModel.playHistoryItem(item) },
                            externalLink: ExternalLinkMenu.make(for: item, sourceName: nil),
                            state: state
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
                        onTap: nil,
                        externalLink: ExternalLinkMenu.make(for: queueItem, sourceName: nil),
                        state: state
                    )
                    .bareListRow()
                } else {
                    // Standalone now playing (station or not in queue)
                    QueuePanelRow(
                        name: state.nowPlaying.standaloneRowTitle,
                        artist: state.nowPlaying.standaloneRowSubtitle,
                        imageURL: state.resolvedImageURL(forMID: state.nowPlaying.mid, originalURL: state.nowPlaying.imageURL),
                        isStation: state.nowPlaying.station != nil,
                        isNowPlaying: true,
                        showRemoveButton: false,
                        onTap: nil,
                        externalLink: ExternalLinkMenu.make(for: state.nowPlaying, sources: state.musicSources),
                        state: state
                    )
                    .bareListRow()
                }
            }
            .accessibilityIdentifier(AccessibilityID.QueuePanel.nowPlayingSection)
        }
    }

    // MARK: - Up Next Section

    @ViewBuilder
    private var upNextSection: some View {
        if !viewModel.upNextItems.isEmpty {
            Section(header: sectionHeader("Up Next") { clearButton }) {
                upNextRows
            }
            .accessibilityIdentifier(AccessibilityID.QueuePanel.upNextSection)
        } else if showsUpNext {
            Section(header: sectionHeader("Up Next")) {
                upNextRows
            }
        }
    }

    /// Something plays, so an empty Up Next says so rather than vanishing.
    private var showsUpNext: Bool {
        !viewModel.upNextItems.isEmpty || viewModel.nowPlayingQueueItem != nil || !state.nowPlaying.mid.isEmpty
    }

    @ViewBuilder
    private var upNextRows: some View {
        if viewModel.upNextItems.isEmpty {
            Text("Queue is empty")
                .typography(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.lg)
                .bareListRow()
        } else {
            ForEach(viewModel.upNextItems) { item in
                QueuePanelRow(
                    name: item.song,
                    artist: item.artist,
                    imageURL: item.imageURL,
                    isStation: false,
                    isNowPlaying: false,
                    showRemoveButton: !DS.removesRowsBySwiping,
                    onTap: { viewModel.playQueueItem(item) },
                    onRemove: { viewModel.removeQueueItem(item) },
                    externalLink: ExternalLinkMenu.make(for: item, sourceName: nil),
                    state: state
                )
                .accessibilityIdentifier(AccessibilityID.QueuePanel.upNextRow(item.qid))
                .accessibilityLabel("\(item.song) by \(item.artist), up next")
                .bareListRow()
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) { viewModel.removeQueueItem(item) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
    }

    /// Fixed above the rows: a pinned header would need a fill, and the player's colours run behind the list.
    private var playerUpNextTitle: some View {
        HStack(spacing: DS.Spacing.sm) {
            Text("Up Next")
                .typography(.bodyEmphasis)
            Spacer()
            if !viewModel.upNextItems.isEmpty {
                clearButton
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var queueTabContent: some View {
        #if os(iOS)
        // A list, for the swipe that removes a track from Up Next on iPhone and iPad.
        if inPlayer {
            VStack(spacing: 0) {
                playerUpNextTitle
                List {
                    upNextRows
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .accessibilityIdentifier(AccessibilityID.QueuePanel.upNextSection)
            }
        } else {
            List {
                nowPlayingSection
                upNextSection
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        #else
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                nowPlayingSection
                upNextSection
            }
        }
        #endif
    }

    private var recentlyPlayedTabContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                historySection
            }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, @ViewBuilder accessory: () -> some View = { EmptyView() }) -> some View {
        VStack(spacing: 0) {
            Spacer().frame(height: DS.Spacing.xxl)
            HStack(spacing: DS.Spacing.sm) {
                Text(title)
                    .typography(.bodyEmphasis)
                Spacer()
                accessory()
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .listRowInsets(EdgeInsets())
        .background(QueuePanelFill(state: state))
    }
}

/// What the panel is painted with: the raised surface, or the artwork's most vibrant colour beside the full-screen player.
struct QueuePanelFill: View {
    let state: AppState

    var body: some View {
        if state.isNowPlayingCanvasOpen {
            ZStack {
                vibrantColor
                Color.black.opacity(0.5)
            }
        } else {
            DS.Colors.surfaceElevated
        }
    }

    private var vibrantColor: Color {
        state.canvasDominantColors
            .max { Self.saturation(of: $0) < Self.saturation(of: $1) } ?? Color(white: 0.06)
    }

    private static func saturation(of color: Color) -> Float {
        let rgb = color.resolve(in: EnvironmentValues())
        let brightest = max(rgb.red, rgb.green, rgb.blue)
        guard brightest > 0 else { return 0 }
        return (brightest - min(rgb.red, rgb.green, rgb.blue)) / brightest
    }
}
