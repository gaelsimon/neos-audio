import SwiftUI
import NeosDomain

struct HomeCardRow: View {
    let items: [BrowseItem]
    let sid: Int
    let onTap: (BrowseItem, Int) -> Void

    var body: some View {
        FadingHorizontalScroll {
            HStack(spacing: DS.Spacing.lg) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HomeCard(
                        imageURL: item.resolvedImageURL,
                        title: item.name,
                        subtitle: item.artist
                    ) {
                        onTap(item, item.sid ?? sid)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }
}
