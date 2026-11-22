import SwiftUI
import NeosDomain

extension BrowseContentView {
    // MARK: - Compact Sticky Header

    #if os(macOS)
    func compactContainerHeader(_ target: BrowseTarget) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            containerArtwork(target, size: 40, cornerRadius: DS.Radius.small)

            compactTitle(target.name, pathIcon: serviceSource(for: target))

            Spacer()

            if hasPlayableItems {
                CircularIconButton(
                    icon: DS.Icons.playing,
                    size: .small,
                    style: .primary,
                    action: { browseVM.playContainer() }
                )
                .help("Play")

                CircularIconButton(
                    icon: DS.Icons.addedToQueue,
                    size: .small,
                    style: .secondary,
                    action: { browseVM.addContainerToQueue() }
                )
                .help("Add to Queue")
            }
        }
        .pageMargins()
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickyHeaderGlass()
    }
    #endif

    // MARK: - Container Artwork (patchwork or single image)

    @ViewBuilder
    private func containerArtwork(_ target: BrowseTarget, size: CGFloat, cornerRadius: CGFloat) -> some View {
        if !target.imageURL.isEmpty {
            CachedAsyncImage(
                url: URL(string: target.imageURL),
                highResURL: ImageURLUpscaler.highResURL(from: target.imageURL, pixels: 480).flatMap(URL.init(string:))
            ) {
                artworkPlaceholder(size: size, cornerRadius: cornerRadius)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            let itemImages = browseVM.items
                .map(\.imageURL)
                .filter { !$0.isEmpty }
            let albums = Set(browseVM.items.compactMap(\.album).filter { !$0.isEmpty })
            if albums.count == 1, let firstImage = itemImages.first {
                CachedAsyncImage(
                    url: URL(string: firstImage),
                    highResURL: ImageURLUpscaler.highResURL(from: firstImage, pixels: 480).flatMap(URL.init(string:))
                ) {
                    artworkPlaceholder(size: size, cornerRadius: cornerRadius)
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                PatchworkArtView(imageURLs: itemImages, size: size, cornerRadius: cornerRadius)
            }
        }
    }

    private func artworkPlaceholder(size: CGFloat, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DS.Colors.surfaceElevated)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: DS.Icons.musicNote)
                    .font(size > 60 ? DS.IconFont.xxxl : DS.IconFont.body)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
    }

    // MARK: - Container Header (album/playlist, scrolls)

    private var hasPlayableItems: Bool {
        browseVM.items.contains { $0.playable }
    }

    /// Primary artwork URL for blur background (container image or first item image).
    /// Uses the original (low-res) URL; high-res is wasteful for a radius-60 blur.
    /// Returns nil only if both container and items have no images.
    func headerBackgroundURL(_ target: BrowseTarget) -> URL? {
        let raw: String
        if !target.imageURL.isEmpty {
            raw = target.imageURL
        } else {
            let itemImages = browseVM.items.map(\.imageURL).filter { !$0.isEmpty }
            guard let first = itemImages.first else { return nil }
            raw = first
        }
        return URL(string: raw)
    }

    func containerHeader(_ target: BrowseTarget, backdropURL: URL?) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            if isCompactLayout {
                VStack(spacing: DS.Spacing.lg) {
                    containerHeaderArtwork(target)
                    containerHeaderMetadata(target, centered: true)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .top, spacing: DS.Spacing.xxl) {
                    containerHeaderArtwork(target)

                    containerHeaderMetadata(target)
                        .frame(maxHeight: DS.ImageSize.containerArt)
                }
            }
        }
        .pageMargins()
        .padding(.top, isCompactLayout ? DS.Spacing.lg : DS.Spacing.xl + DS.Spacing.lg)
        .padding(.bottom, backdropURL == nil ? DS.Spacing.xxl + DS.Spacing.lg : DS.Spacing.xxxl + DS.Spacing.lg)
        .padding(.top, backdropURL == nil ? 0 : DS.Layout.topOverlay)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let backdropURL {
                headerBackdrop(backdropURL)
                    #if os(iOS)
                    // The scroll view starts its content under the bars; reach back up behind them.
                    .padding(.top, -scrollTopInset)
                    #endif
            }
        }
    }

    private func containerHeaderArtwork(_ target: BrowseTarget) -> some View {
        containerArtwork(target, size: DS.ImageSize.containerArt, cornerRadius: DS.Radius.artworkLarge)
            .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 10)
            .accessibilityLabel("Artwork")
            .accessibilityIdentifier(AccessibilityID.Browse.containerArt)
    }

    // Oversized before the blur, or its edges fade to a dark vignette.
    private func headerBackdrop(_ url: URL) -> some View {
        Color.clear
            .overlay {
                CachedAsyncImage(url: url) { Color.clear }
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(1.3)
                    .blur(radius: 60)
                    .opacity(0.5)
            }
            .clipped()
            .accessibilityHidden(true)
            .overlay {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .clear, location: 0.4),
                        .init(color: DS.Colors.background.opacity(0.5), location: 0.75),
                        .init(color: DS.Colors.background, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            .allowsHitTesting(false)
    }

    // MARK: - Container Header Metadata

    /// Centred when it sits under the artwork.
    @ViewBuilder
    private func containerHeaderMetadata(_ target: BrowseTarget, centered: Bool = false) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: DS.Spacing.sm) {
            Text(target.name)
                .typography(.pageTitle)
                .lineLimit(2)
                .multilineTextAlignment(centered ? .center : .leading)
                .padding(.top, centered ? 0 : DS.Spacing.xl)
                #if os(iOS)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.headerSpace)).maxY } action: {
                    headerTitleBottom = $0
                }
                #endif
                .accessibilityIdentifier(AccessibilityID.Browse.containerTitle)

            if !browseVM.items.isEmpty || !target.serviceName.isEmpty {
                containerSubtitle(target, centered: centered)
            }

            if browseVM.isLoading {
                Spinner(size: 16, lineWidth: 2)
            }

            if !centered {
                Spacer(minLength: 0)
            }

            if hasPlayableItems {
                containerActionButtons
                    .padding(.top, centered ? DS.Spacing.sm : 0)
            }
        }
    }

    /// Subtitle: service branding first (available immediately), item count second (loads later).
    @ViewBuilder
    private func containerSubtitle(_ target: BrowseTarget, centered: Bool) -> some View {
        VStack(alignment: centered ? .center : .leading, spacing: DS.Spacing.sm) {
            if let artist = sharedArtist {
                CrossLink(artist, typography: .sectionHeader, action: trackRows.first.flatMap(artistViewHandler))
                    .accessibilityIdentifier(AccessibilityID.Browse.containerArtist)
            }

            if centered {
                // The back button walks the path there; a scrolling breadcrumb cannot centre.
                if let source = serviceSource(for: target) {
                    ServiceBranding.serviceLabel(for: source, iconSize: 20, style: .secondary)
                }
            } else {
                HStack(spacing: DS.Spacing.sm) {
                    if let source = serviceSource(for: target) {
                        ServiceBranding.serviceIcon(for: source, size: 20)
                    }
                    BreadcrumbBar(stack: browseVM.browseStack) { index in
                        browseVM.navigateToBreadcrumb(at: index)
                    }
                }
            }

            if !browseVM.items.isEmpty {
                Text("\(browseVM.items.count)\(browseVM.hasMore ? "+" : "") \(itemNoun)")
                    .typography(.bodyMedium, color: DS.Colors.textTertiary)
            }
        }
        .padding(.top, DS.Spacing.xs)
    }

    /// Resolve the MusicSource for the current browse context.
    private func serviceSource(for target: BrowseTarget) -> MusicSource? {
        guard let root = browseVM.browseStack.first else { return nil }
        let source = state.musicSources.first { $0.sid == root.sid }
        // Only show for streaming services, not local/built-in sources
        guard let source, ServiceBranding.hasBrandIdentity(for: source.name) else { return nil }
        return source
    }

    // MARK: - Container Action Buttons

    #if os(iOS)
    /// Play Next and Add to Queue go in the navigation bar's menu.
    private var containerActionButtons: some View {
        HStack(spacing: DS.Spacing.md) {
            Button { browseVM.playContainer() } label: {
                Label("Play", systemImage: DS.Icons.playing)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.Colors.accent)
            .foregroundStyle(.black)
            .accessibilityIdentifier(AccessibilityID.Browse.playContainer)

            Button { browseVM.shuffleContainer() } label: {
                Label("Shuffle", systemImage: DS.Icons.shuffle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier(AccessibilityID.Browse.shuffleContainer)
        }
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .fontWeight(.semibold)
        .frame(maxWidth: 360)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") {
                        browseVM.addContainerToQueue(criteria: .playNext)
                    }
                    .accessibilityIdentifier(AccessibilityID.Browse.playNext)
                    Button("Add to Queue", systemImage: DS.Icons.addedToQueue) { browseVM.addContainerToQueue() }
                        .accessibilityIdentifier(AccessibilityID.Browse.addToQueue)
                } label: {
                    Label("More", systemImage: "ellipsis")
                }
            }
        }
    }
    #else
    private var containerActionButtons: some View {
        HStack(spacing: DS.Spacing.md) {
            CircularIconButton(
                icon: DS.Icons.playing,
                size: .large,
                style: .primary,
                action: { browseVM.playContainer() }
            )
            .accessibilityIdentifier(AccessibilityID.Browse.playContainer)
            .help("Play")

            CircularIconButton(
                icon: DS.Icons.shuffle,
                size: .medium,
                style: .secondary,
                action: { browseVM.shuffleContainer() }
            )
            .accessibilityIdentifier(AccessibilityID.Browse.shuffleContainer)
            .help("Shuffle")

            CircularIconButton(
                icon: DS.Icons.addedToQueue,
                size: .medium,
                style: .secondary,
                action: { browseVM.addContainerToQueue() }
            )
            .accessibilityIdentifier(AccessibilityID.Browse.addToQueue)
            .help("Add to Queue")
        }
    }
    #endif

    // MARK: - Source Header (root level, scrolls)

    #if os(macOS)
    var sourceHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            if browseVM.browseStack.count > 1,
               let current = browseVM.browseStack.last,
               let root = browseVM.browseStack.first,
               let source = state.musicSources.first(where: { $0.sid == root.sid }) {
                // A folder, an amp input or a DLNA server: its own name, then the path back to its parents.
                ServiceBranding.serviceIcon(for: source, size: DS.ImageSize.serviceIcon)
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(current.name)
                        .typography(.pageTitle)
                        .lineLimit(1)
                    BreadcrumbBar(stack: browseVM.browseStack) { index in
                        browseVM.navigateToBreadcrumb(at: index)
                    }
                }
            } else if let target = browseVM.browseStack.first,
               let source = state.musicSources.first(where: { $0.sid == target.sid }) {
                ServiceBranding.serviceLabel(
                    for: source,
                    iconSize: DS.ImageSize.serviceIcon,
                    style: .pageTitle
                )
            } else {
                Text(browseVM.browseStack.last?.name ?? "Browse")
                    .typography(.pageTitle)
                    .lineLimit(1)
            }

            if browseVM.isLoading {
                Spinner(size: 16, lineWidth: 2)
            }

            Spacer()

            if browseVM.isFavoritesSource {
                HoverButton(
                    action: { showAddFavorite = true },
                    accessibilityID: AccessibilityID.Browse.addStation
                ) { hovered in
                    Image(systemName: "plus")
                        .font(DS.IconFont.lg)
                        .foregroundStyle(hovered ? .white : DS.Colors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(DS.Colors.surfaceElevated.opacity(hovered ? 1 : 0.6), in: Circle())
                }
                .help("Add Station")
            }
        }
        .pageMargins()
        .padding(.top, DS.Spacing.xxl)
        .padding(.bottom, DS.Spacing.xl)
    }

    // The big header in miniature: the title, then the path to its parents.
    private func compactTitle(_ title: String, pathIcon: MusicSource?) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            Text(title)
                .typography(.secondaryEmphasis)
                .lineLimit(1)
            if browseVM.browseStack.count > 1 {
                HStack(spacing: DS.Spacing.xs) {
                    if let pathIcon {
                        ServiceBranding.serviceIcon(for: pathIcon, size: 14)
                    }
                    BreadcrumbBar(stack: browseVM.browseStack) { index in
                        browseVM.navigateToBreadcrumb(at: index)
                    }
                }
            }
        }
    }

    var compactSourceHeader: some View {
        let stack = browseVM.browseStack
        let source = stack.first.flatMap { root in state.musicSources.first { $0.sid == root.sid } }
        let title = stack.count > 1 ? stack.last?.name : (source?.name ?? stack.last?.name)
        return HStack(spacing: DS.Spacing.sm) {
            if let source {
                ServiceBranding.serviceIcon(for: source, size: 40)
            }
            compactTitle(title ?? "Browse", pathIcon: nil)
            Spacer()
        }
        .frame(height: 40)
        .pageMargins()
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickyHeaderGlass()
    }
    #endif
}

// MARK: - Navigation Bar

extension BrowseContentView {
    static let headerSpace = "browse_header"

    #if os(iOS)
    @ToolbarContentBuilder
    var navigationBarItems: some ToolbarContent {
        if browseVM.opensOnArtwork, let current = browseVM.browseStack.last {
            // Appears once the header carrying the same title has scrolled away.
            ToolbarItem(placement: .principal) {
                Text(current.name)
                    .font(.headline)
                    .lineLimit(1)
                    .opacity(showCompactHeader ? 1 : 0)
                    .accessibilityHidden(!showCompactHeader)
                    .animation(.easeInOut(duration: 0.15), value: showCompactHeader)
            }
        } else if browseVM.isLoading {
            // The Mac shows this beside the page title, which the bar carries here.
            ToolbarItem(placement: .topBarTrailing) { ProgressView() }
        }
        if browseVM.isFavoritesSource {
            ToolbarItem(placement: .primaryAction) {
                Button("Add Station", systemImage: "plus") { showAddFavorite = true }
                    .accessibilityIdentifier(AccessibilityID.Browse.addStation)
            }
        }
    }
    #endif
}
