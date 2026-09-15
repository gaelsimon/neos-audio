import SwiftUI

struct FilterChip: View {
    enum Emphasis {
        case primary    // which service to search
        case secondary  // which kind of result to show
    }

    let label: String
    let isSelected: Bool
    var icon: Image?
    var emphasis: Emphasis = .primary
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
                    .foregroundStyle(labelColor)
            }
            .padding(.horizontal, icon != nil ? DS.Spacing.md : DS.Spacing.lg)
            .padding(.vertical, icon != nil ? DS.Spacing.xs : DS.Spacing.sm)
            .background(chipBackground, in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityIdentifier(accessibilityID ?? "filterChip.\(label)")
    }

    private var chipBackground: Color {
        if isSelected {
            return emphasis == .primary ? DS.Colors.accent : DS.Colors.surfaceElevated
        }
        if isHovered {
            return DS.Colors.surfaceElevated
        }
        return DS.Colors.surface
    }

    private var labelColor: Color {
        guard isSelected else { return DS.Colors.textSecondary }
        return emphasis == .primary ? Color.black : DS.Colors.accent
    }

    private var borderColor: Color {
        if isSelected {
            return emphasis == .primary ? .clear : DS.Colors.accent
        }
        return Color.white.opacity(0.15)
    }
}
