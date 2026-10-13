import SwiftUI
import NeosDomain

extension BrowseContentView {
    // MARK: - Compact Sticky Header

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
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickyHeaderGlass()
    }

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
            HStack(alignment: .top, spacing: DS.Spacing.xxl) {
                containerArtwork(target, size: DS.ImageSize.containerArt, cornerRadius: DS.Radius.artworkLarge)
                    .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 10)
                    .accessibilityIdentifier(AccessibilityID.Browse.containerArt)

                containerHeaderMetadata(target)
                    .frame(maxHeight: DS.ImageSize.containerArt)
            }
        }
        .padding(.horizontal, DS.Layout.pageMargin)
        .padding(.top, DS.Spacing.xl + DS.Spacing.lg)
        .padding(.bottom, backdropURL == nil ? DS.Spacing.xxl + DS.Spacing.lg : DS.Spacing.xxxl + DS.Spacing.lg)
        .padding(.top, backdropURL == nil ? 0 : DS.TopBar.height)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if let backdropURL { headerBackdrop(backdropURL) }
        }
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

    @ViewBuilder
    private func containerHeaderMetadata(_ target: BrowseTarget) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(target.name)
                .typography(.pageTitle)
                .lineLimit(2)
                .padding(.top, DS.Spacing.xl)
                .accessibilityIdentifier(AccessibilityID.Browse.containerTitle)

            if !browseVM.items.isEmpty || !target.serviceName.isEmpty {
                containerSubtitle(target)
            }

            if browseVM.isLoading {
                Spinner(size: 16, lineWidth: 2)
            }

            Spacer(minLength: 0)

            if hasPlayableItems {
                containerActionButtons
            }
        }
    }

    /// Subtitle: service branding first (available immediately), item count second (loads later).
    @ViewBuilder
    private func containerSubtitle(_ target: BrowseTarget) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            if let artist = sharedArtist {
                HeaderArtistLink(artist: artist, onTap: trackRows.first.flatMap(artistViewHandler))
            }

            HStack(spacing: DS.Spacing.sm) {
                if let source = serviceSource(for: target) {
                    ServiceBranding.serviceIcon(for: source, size: 20)
                }
                BreadcrumbBar(stack: browseVM.browseStack) { index in
                    browseVM.navigateToBreadcrumb(at: index)
                }
            }

            if !browseVM.items.isEmpty {
                Text("\(browseVM.items.count)\(browseVM.hasMore ? "+" : "") \(itemNoun)")
                    .typography(.bodyMedium)
                    .foregroundStyle(DS.Colors.textTertiary)
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

    // MARK: - Source Header (root level, scrolls)

    var sourceHeader: some View {
        HStack(spacing: DS.Spacing.sm) {
            if browseVM.browseStack.count > 1,
               let current = browseVM.browseStack.last,
               let root = browseVM.browseStack.first,
               let source = state.musicSources.first(where: { $0.sid == root.sid }) {
                // A sub-level with no cid: an amp input or a DLNA server. Name it, not its source.
                ServiceBranding.serviceIcon(for: source, size: DS.ImageSize.serviceIcon)
                Text(current.name)
                    .typography(.pageTitle)
                    .lineLimit(1)
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
        .padding(.horizontal, DS.Spacing.xxl)
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
        .padding(.horizontal, DS.Spacing.xxl)
        .padding(.vertical, DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .stickyHeaderGlass()
    }
}
