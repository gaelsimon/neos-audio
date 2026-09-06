import SwiftUI

/// The "Open in …" and "Copy Link" entries shared by every row context menu.
struct ExternalLinkMenuItems: View {
    let link: ExternalLinkMenu
    /// Only there to report the outcome, which for SoundCloud lands a moment after the click.
    var state: AppState?

    var body: some View {
        Group {
            if link.target.isOpenable {
                Button {
                    ExternalLinkOpener.open(link.target) { announce($0, copied: false) }
                } label: {
                    Label("Open in \(link.serviceName)", systemImage: "arrow.up.forward.app")
                }
            }
            Button {
                ExternalLinkOpener.copyLink(link.target) { announce($0, copied: true) }
            } label: {
                Label("Copy Link", systemImage: DS.Icons.clipboard)
            }
        }
    }

    /// Silent on an exact link that was opened: the browser coming forward is the confirmation.
    private func announce(_ outcome: ExternalLinkOpener.Outcome, copied: Bool) {
        switch outcome {
        case .exact:
            guard copied else { return }
            state?.showToast("Link copied", icon: DS.Icons.clipboard)
        case .search:
            state?.showToast(
                copied ? "Track link unavailable, copied a search" : "Track link unavailable, opened a search",
                icon: copied ? DS.Icons.clipboard : DS.Icons.search,
                style: .info
            )
        case .failed:
            state?.showToast("Couldn't resolve this link", icon: DS.Icons.warning, style: .error)
        }
    }
}
