import SwiftUI

/// The results page while a search runs: two service blocks, each with a card row and a few rows.
struct SearchPlaceholderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxl) {
            serviceBlock
            serviceBlock
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var serviceBlock: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.md) {
                Circle()
                    .fill(.quaternary)
                    .frame(width: DS.ImageSize.serviceIconLarge, height: DS.ImageSize.serviceIconLarge)
                Text("Service")
                    .typography(.sectionHeader)
                Spacer()
            }
            .padding(.horizontal, DS.Layout.surfaceInset)

            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Albums")
                    .typography(.sectionHeader)
                    .padding(.horizontal, DS.Layout.surfaceInset)
                PlaceholderCardRow(cardCount: 3)
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("Tracks")
                    .typography(.sectionHeader)
                    .padding(.horizontal, DS.Layout.surfaceInset)
                ForEach(0..<4, id: \.self) { _ in
                    PlaceholderRow()
                }
            }
        }
        .padding(.vertical, DS.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.large)
                .fill(DS.Colors.surfaceContainer)
        )
        .padding(.horizontal, DS.Layout.pageMargin)
    }
}
