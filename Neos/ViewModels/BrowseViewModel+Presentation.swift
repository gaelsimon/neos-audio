extension BrowseViewModel {
    /// On iPhone and iPad, whether the page opens on the container's artwork instead of the bar's large title.
    var opensOnArtwork: Bool {
        guard isInContainer, let target = browseStack.last else { return false }
        return TrackListPresentation.opensOnArtwork(target: target, items: items)
    }
}
