import NeosDomain

extension BrowseViewModel {
    /// Whether the page opens on the container's artwork, or names itself like a source.
    var opensOnArtwork: Bool {
        guard isInContainer, let target = browseStack.last else { return false }
        return TrackListPresentation.opensOnArtwork(target: target, items: items)
    }

    /// Nil on the album's own page, where the link would lead back to it.
    func albumToOpen(from item: BrowseItem) -> String? {
        guard let album = item.album, !album.isEmpty else { return nil }
        if let page = browseStack.last, page.mediaType == .album, page.name == album { return nil }
        return album
    }
}
