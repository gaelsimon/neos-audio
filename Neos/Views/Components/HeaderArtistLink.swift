import SwiftUI

struct HeaderArtistLink: View {
    let artist: String
    var onTap: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        Text(artist)
            .typography(.sectionHeader)
            .foregroundStyle(isHovered && onTap != nil ? DS.Colors.accent : DS.Colors.textSecondary)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture { onTap?() }
            .accessibilityIdentifier(AccessibilityID.Browse.containerArtist)
    }
}
