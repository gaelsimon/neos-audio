import AppKit

/// Hands an external link to the desktop, preferring a service's own app when it is installed.
@MainActor
enum ExternalLinkOpener {

    /// Which address the caller got, so the UI can tell a real link from a consolation search page.
    enum Outcome {
        case exact
        case search
        case failed
    }

    static func open(_ target: ExternalLink.Target, then report: ((Outcome) -> Void)? = nil) {
        switch target {
        case .direct(let app, let web):
            report?(openPreferringApp(app: app, web: web) ? .exact : .failed)
        case .soundCloudTrack(let id, let search):
            Task {
                let resolved = await resolvedSoundCloudURL(id: id, fallback: search)
                if let url = resolved.url, open(url) {
                    report?(resolved.outcome)
                } else {
                    report?(.failed)
                }
            }
        case .stream(let url):
            report?(open(url) ? .exact : .failed)
        }
    }

    /// `report` fires once the clipboard holds the link, which for SoundCloud is after a round trip.
    static func copyLink(_ target: ExternalLink.Target, then report: ((Outcome) -> Void)? = nil) {
        switch target {
        case .direct(_, let web):
            copy(web)
            report?(.exact)
        case .soundCloudTrack(let id, let search):
            Task {
                let resolved = await resolvedSoundCloudURL(id: id, fallback: search)
                if let url = resolved.url { copy(url) }
                report?(resolved.outcome)
            }
        case .stream(let url):
            copy(url)
            report?(.exact)
        }
    }

    // MARK: - Private

    /// The search page is the floor: it needs no endpoint to keep working. It is nil only for an
    /// item with neither artist nor title, where resolution is the only path.
    private static func resolvedSoundCloudURL(id: String, fallback: URL?) async -> (url: URL?, outcome: Outcome) {
        if let permalink = await SoundCloudLinkResolver.shared.permalink(trackID: id) {
            return (permalink, .exact)
        }
        guard let fallback else { return (nil, .failed) }
        return (fallback, .search)
    }

    /// Falls through to the web when the app is absent, and also when it refuses to launch.
    private static func openPreferringApp(app: URL?, web: URL) -> Bool {
        if let app, NSWorkspace.shared.urlForApplication(toOpen: app) != nil, open(app) { return true }
        return open(web)
    }

    private static func open(_ url: URL) -> Bool {
        NSWorkspace.shared.open(url)
    }

    private static func copy(_ url: URL) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }
}
