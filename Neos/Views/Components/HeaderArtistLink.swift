import SwiftUI

struct HeaderArtistLink: View {
    let artist: String
    var onTap: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { label(isHovered ? DS.Colors.accent : DS.Colors.textSecondary) }
                    .buttonStyle(.plain)
                    .pointingHandCursor(isHovered: $isHovered)
                    .accessibilityAddTraits(.isLink)
            } else {
                label(DS.Colors.textSecondary)
            }
        }
        .accessibilityIdentifier(AccessibilityID.Browse.containerArtist)
    }

    private func label(_ color: Color) -> some View {
        Text(artist)
            .typography(.sectionHeader)
            .foregroundStyle(color)
    }
}
