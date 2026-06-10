import SwiftUI

/// Placeholder shimmer row matching BrowseItemRow layout.
struct ShimmerListRow: View {
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            RoundedRectangle(cornerRadius: DS.Radius.small)
                .fill(.quaternary)
                .frame(width: DS.ImageSize.listRow, height: DS.ImageSize.listRow)
                .shimmer()

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .fill(.quaternary)
                    .frame(width: 140, height: 12)
                    .shimmer()

                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .fill(.quaternary)
                    .frame(width: 90, height: 10)
                    .shimmer()
            }

            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
    }
}
