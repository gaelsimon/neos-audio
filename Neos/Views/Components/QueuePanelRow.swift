import SwiftUI
import NeosDomain

struct QueuePanelRow: View {
    let name: String
    let artist: String
    let imageURL: String
    let isStation: Bool
    let isNowPlaying: Bool
    let showRemoveButton: Bool
    let onTap: () -> Void
    var onRemove: (() -> Void)?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            artwork
            textContent
            Spacer()
            if showRemoveButton, let onRemove {
                removeButton(action: onRemove)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .frame(height: 54)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: DS.Radius.small))
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onHover { isHovered = $0 }
    }

    // MARK: - Artwork

    private var artwork: some View {
        CachedAsyncImage(
            url: URL(string: imageURL),
            highResURL: ImageURLUpscaler.highResURL(from: imageURL).flatMap(URL.init(string:))
        ) {
            RoundedRectangle(cornerRadius: DS.Radius.small)
                .fill(DS.Colors.surfaceElevated)
                .overlay {
                    Image(systemName: isStation
                          ? "antenna.radiowaves.left.and.right"
                          : "music.note")
                        .font(DS.IconFont.sm)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
        }
        .frame(
            width: DS.ImageSize.trackListRow,
            height: DS.ImageSize.trackListRow
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.small))
        .overlay {
            if isNowPlaying {
                RoundedRectangle(cornerRadius: DS.Radius.small)
                    .fill(.black.opacity(0.4))
                Image(systemName: DS.Icons.speakerActive)
                    .font(DS.IconFont.body)
                    .foregroundStyle(DS.Colors.accent)
            }
        }
    }

    // MARK: - Text Content

    private var textContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            Text(name)
                .typography(.bodyPrimary)
                .foregroundStyle(isNowPlaying ? DS.Colors.accent : .primary)
                .lineLimit(1)
            if !artist.isEmpty {
                Text(artist)
                    .typography(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Remove Button

    private func removeButton(action: @escaping () -> Void) -> some View {
        HoverButton(action: action) { hovered in
            Image(systemName: DS.Icons.close)
                .font(DS.IconFont.smEmphasis)
                .foregroundStyle(hovered ? .primary : DS.Colors.textTertiary)
        }
        .accessibilityLabel("Remove \(name)")
    }

    // MARK: - Row Background

    private var rowBackground: Color {
        if isHovered {
            return DS.Colors.surfaceElevated.opacity(0.5)
        }
        return .clear
    }
}
