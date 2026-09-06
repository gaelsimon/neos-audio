import SwiftUI
import NeosDomain

struct HomeCardRow: View {
    let items: [BrowseItem]
    let sid: Int
    var state: AppState?
    let onTap: (BrowseItem, Int) -> Void

    var body: some View {
        FadingHorizontalScroll {
            HStack(spacing: DS.Spacing.lg) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HomeCard(
                        imageURL: item.resolvedImageURL,
                        title: item.displayTitle,
                        subtitle: item.artist,
                        externalLink: ExternalLinkMenu.make(for: item, sid: sid, sources: state?.musicSources ?? []),
                        state: state
                    ) {
                        onTap(item, item.sid ?? sid)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }
}
