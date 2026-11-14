extension BrowseViewModel {
    /// Whether the page opens on the container's artwork, or names itself like a source.
    var opensOnArtwork: Bool {
        guard isInContainer, let target = browseStack.last else { return false }
        return TrackListPresentation.opensOnArtwork(target: target, items: items)
    }
}
