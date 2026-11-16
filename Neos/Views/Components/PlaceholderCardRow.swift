import SwiftUI

/// A card row while it loads: real cards with placeholder text, redacted.
struct PlaceholderCardRow: View {
    var cardCount: Int = 4
    var inset: CGFloat?
    @Environment(\.pageMargin) private var pageMargin
    private static let inert: () -> Void = {
        // A placeholder takes no taps.
    }

    var body: some View {
        FadingHorizontalScroll {
            HStack(spacing: DS.Spacing.lg) {
                ForEach(0..<cardCount, id: \.self) { _ in
                    HomeCard(imageURL: "", title: "Loading title", subtitle: "Loading", onTap: Self.inert)
                }
            }
            .padding(.horizontal, inset ?? pageMargin)
        }
        .redacted(reason: .placeholder)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
