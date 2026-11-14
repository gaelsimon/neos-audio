import SwiftUI
import NeosDomain

struct HomeCardRow: View {
    let items: [BrowseItem]
    let sid: Int
    var state: AppState?
    var inset: CGFloat?
    let onTap: (BrowseItem, Int) -> Void
    @Environment(\.pageMargin) private var pageMargin

    var body: some View {
        FadingHorizontalScroll {
            LazyHStack(alignment: .top, spacing: DS.Spacing.lg) {
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
        }
        #if os(iOS)
        // Edge to edge, so cards slide under the screen's edge; the first one still meets the margin.
        .contentMargins(.horizontal, inset ?? pageMargin, for: .scrollContent)
        #else
        .padding(.horizontal, inset ?? pageMargin)
        #endif
    }
}
