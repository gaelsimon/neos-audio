import SwiftUI
import NeosDomain

/// A row while its list loads: the real row with placeholder text, redacted.
struct PlaceholderRow: View {
    private static let item = BrowseItem(name: "Loading title", artist: "Loading artist")
    private static let inert: () -> Void = {
        // A placeholder takes no taps.
    }

    var body: some View {
        BrowseItemRow(item: Self.item, onTap: Self.inert, onAddToQueue: Self.inert)
            .redacted(reason: .placeholder)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
