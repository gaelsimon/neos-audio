import SwiftUI

/// Full-page shimmer skeleton mimicking search results layout.
/// Shows 2 service blocks each with a card category and a list category.
struct SearchShimmerView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            serviceBlock
            serviceBlock
        }
    }

    private var serviceBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Service header
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(.quaternary)
                    .frame(width: DS.ImageSize.serviceIconLarge, height: DS.ImageSize.serviceIconLarge)
                    .shimmer()

                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .fill(.quaternary)
                    .frame(width: 100, height: 16)
                    .shimmer()

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.xl)

            // Card category (artists/albums)
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .fill(.quaternary)
                    .frame(width: 80, height: 14)
                    .shimmer()
                    .padding(.horizontal, DS.Spacing.xl)

                ShimmerCardRow(cardCount: 3)
            }

            // List category (tracks)
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .fill(.quaternary)
                    .frame(width: 60, height: 14)
                    .shimmer()
                    .padding(.horizontal, DS.Spacing.xl)

                ForEach(0..<4, id: \.self) { _ in
                    ShimmerListRow()
                }
            }
        }
        .padding(.vertical, DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.large)
                .fill(DS.Colors.surfaceContainer)
        )
        .padding(.horizontal, DS.Spacing.md)
    }
}
