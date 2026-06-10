import SwiftUI

struct ShimmerCardRow: View {
    var cardCount: Int = 4

    var body: some View {
        FadingHorizontalScroll {
            HStack(spacing: DS.Spacing.lg) {
                ForEach(0..<cardCount, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        RoundedRectangle(cornerRadius: DS.Radius.medium)
                            .fill(.quaternary)
                            .frame(width: DS.ImageSize.homeCard, height: DS.ImageSize.homeCard)
                            .shimmer()

                        RoundedRectangle(cornerRadius: DS.Radius.small)
                            .fill(.quaternary)
                            .frame(width: DS.ImageSize.homeCard * 0.8, height: 14)
                            .shimmer()

                        RoundedRectangle(cornerRadius: DS.Radius.small)
                            .fill(.quaternary)
                            .frame(width: DS.ImageSize.homeCard * 0.5, height: 12)
                            .shimmer()
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }
}
