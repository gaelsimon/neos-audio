import SwiftUI

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    var icon: Image?
    var accessibilityID: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.sm) {
                if let icon {
                    icon
                        .resizable()
                        .renderingMode(.original)
                        .aspectRatio(contentMode: .fit)
                        .padding(DS.Spacing.xs)
                        .frame(width: 28, height: 28)
                        .background(DS.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DS.Radius.small))
                }
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.black : DS.Colors.textSecondary)
            }
            .padding(.horizontal, icon != nil ? DS.Spacing.md : DS.Spacing.lg)
            .padding(.vertical, icon != nil ? DS.Spacing.xs : DS.Spacing.sm)
            .background(chipBackground, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? Color.clear : Color.white.opacity(0.15),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityIdentifier(accessibilityID ?? "filterChip.\(label)")
    }

    private var chipBackground: Color {
        if isSelected {
            return DS.Colors.accent
        }
        if isHovered {
            return DS.Colors.surfaceElevated
        }
        return DS.Colors.surface
    }
}
